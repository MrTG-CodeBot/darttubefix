import 'dart:async';
import 'dart:convert';
import 'exceptions.dart';
import 'helpers.dart';
import 'parser.dart';
import 'node_runner.dart';

const int maxRetries = 3;
const double retryDelay = 0.5;

class Cipher {
  final String js;
  final String jsUrl;

  List<dynamic>? _sigParamVal;
  List<dynamic>? _nsigParamVal;

  String? _sigFunctionName;
  String? _nsigFunctionName;

  NodeRunner? _runnerSig;
  NodeRunner? _runnerNsig;

  Cipher({required this.js, required this.jsUrl});

  Future<void> _initSigRunner() async {
    if (_runnerSig == null) {
      _sigFunctionName ??= getSigFunctionName(js, jsUrl);
      _runnerSig = NodeRunner(js);
      await _runnerSig!.init();
      await _runnerSig!.loadFunction(_sigFunctionName!);
    }
  }

  Future<void> _initNsigRunner() async {
    if (_runnerNsig == null) {
      _nsigFunctionName ??= await getNsigFunctionName(js, jsUrl);
      _runnerNsig = NodeRunner(js);
      await _runnerNsig!.init();
      await _runnerNsig!.loadFunction(_nsigFunctionName!);
    }
  }

  Future<dynamic> _callWithRetry(NodeRunner runner, List<dynamic> args, {String label = "call"}) async {
    dynamic lastExc;
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await runner.call(args);
      } catch (e) {
        if (e is NodeRunnerEmptyResponseError && attempt < maxRetries) {
          await Future.delayed(Duration(milliseconds: (retryDelay * attempt * 1000).toInt()));
          try {
            await runner.restart();
          } catch (_) {}
          lastExc = e;
          continue;
        }
        rethrow;
      }
    }
    throw lastExc;
  }

  List<dynamic> _normalizeNsigParams(dynamic params) {
    if (params == null) {
      return [];
    }
    if (params is List) {
      if (params.isNotEmpty && params.every((item) => item is int)) {
        return [params];
      }
      return List.from(params);
    }
    return [params];
  }

  bool _isValidNsigOutput(dynamic value) {
    final invalidLiterals = {
      "",
      "FORMAT_STREAM_TYPE_UNKNOWN",
      "STREAM_PROTECTION_STATUS_UNKNOWN",
      "UNKNOWN",
    };
    return value is String &&
        !invalidLiterals.contains(value) &&
        !value.contains('error') &&
        !value.contains('_w8_');
  }

  Future<Map<String, dynamic>> _runNsigCandidates(List<dynamic> params, String n) async {
    dynamic nsig;
    dynamic lastExc;
    dynamic workingParam;
    for (final param in params) {
      try {
        if (param is List) {
          nsig = await _callWithRetry(_runnerNsig!, [...param, n], label: "nsig");
        } else {
          nsig = await _callWithRetry(_runnerNsig!, [param, n], label: "nsig");
        }
      } catch (e) {
        lastExc = e;
        continue;
      }
      if (_isValidNsigOutput(nsig)) {
        workingParam = param;
        break;
      }
      lastExc = nsig;
    }
    return {"nsig": nsig, "lastExc": lastExc, "workingParam": workingParam};
  }

  Future<List<dynamic>> _searchNsigXorCandidates(String probeInput, List<dynamic> params) async {
    final List<List<int>> xorValues = [];
    final Set<String> testedPairs = {};
    for (final param in params) {
      if (param is List && param.length == 2 && param[0] is int && param[1] is int) {
        testedPairs.add("${param[0]},${param[1]}");
        xorValues.add([param[0] as int, param[1] as int]);
      }
    }

    if (xorValues.isEmpty) {
      return [];
    }

    final List<List<int>> transformed = [];
    final List<List<int>> plainStrings = [];
    final Set<String> seenFound = {};

    final uniqueXors = xorValues.map((pair) => pair[0] ^ pair[1]).toSet().toList();

    for (final xorValue in uniqueXors) {
      for (var firstArg = 0; firstArg < 256; firstArg++) {
        final pair = [firstArg, xorValue ^ firstArg];
        final pairKey = "${pair[0]},${pair[1]}";
        if (testedPairs.contains(pairKey) || seenFound.contains(pairKey)) {
          continue;
        }
        dynamic output;
        try {
          output = await _callWithRetry(
            _runnerNsig!,
            [pair[0], pair[1], probeInput],
            label: "nsig-probe",
          );
        } catch (_) {
          continue;
        }
        if (!_isValidNsigOutput(output)) {
          continue;
        }
        seenFound.add(pairKey);
        if (output != probeInput) {
          transformed.add([pair[0], pair[1]]);
          if (transformed.length >= 8) {
            return transformed;
          }
        } else {
          plainStrings.add([pair[0], pair[1]]);
        }
      }
    }

    return transformed.isNotEmpty ? transformed : plainStrings;
  }

  String? _findFunctionBody(String funcName) {
    final pattern = RegExp(
      r'(?<![A-Za-z0-9_$])(?:function\s+' + RegExp.escape(funcName) + r'(?![A-Za-z0-9_$])|' +
      r'(?:var\s+)?' + RegExp.escape(funcName) + r'(?![A-Za-z0-9_$])\s*=\s*function)\s*\('
    );
    final matches = pattern.allMatches(js).toList();
    if (matches.isEmpty) {
      return null;
    }

    final funcDef = matches.last;
    final funcStart = funcDef.start;
    var depth = 0;
    var funcEnd = funcStart;
    for (var index = funcStart; index < js.length; index++) {
      if (js[index] == '{') {
        depth += 1;
      } else if (js[index] == '}') {
        depth -= 1;
        if (depth == 0) {
          funcEnd = index + 1;
          break;
        }
      }
    }
    return js.substring(funcStart, funcEnd);
  }

  List<int> _deriveNsigInvariants(String funcName) {
    if (funcName.isEmpty) {
      return [];
    }

    List<dynamic>? globalArr;
    String? varname;
    final extracted = extractPlayerJsGlobalVar(js);
    final globalObjCode = extracted[0];
    final extractedVarname = extracted[1];
    final code = extracted[2];
    
    if (globalObjCode != null && extractedVarname != null && code != null) {
      try {
        globalArr = interpretSimpleJsExpression(code) as List<dynamic>?;
        varname = extractedVarname;
      } catch (_) {
        return [];
      }
    } else {
      final tceExtracted = _extractSplitPlayerJsGlobalVar(js);
      varname = tceExtracted.key;
      globalArr = tceExtracted.value;
      
      if (varname == null || globalArr == null) {
        final propExtracted = _extractPropertyArrayPlayerJsGlobalVar(js);
        varname = propExtracted.key;
        globalArr = propExtracted.value;
      }
      if (varname == null || globalArr == null) {
        return [];
      }
    }

    final arr = globalArr;
    if (arr == null) {
      return [];
    }

    int? w8Idx;
    for (var idx = 0; idx < arr.length; idx++) {
      final value = arr[idx];
      if (value is String && value.endsWith('_w8_')) {
        w8Idx = idx;
        break;
      }
    }
    if (w8Idx == null) {
      return [];
    }

    final body = _findFunctionBody(funcName);
    if (body == null) {
      return [];
    }

    final header = body.substring(0, body.length > 200 ? 200 : body.length);
    final xorVarMatch = RegExp(r'var\s+(?<xor>[A-Za-z0-9_$]+)\s*=\s*[A-Za-z0-9_$]+\s*\^\s*[A-Za-z0-9_$]+\b')
        .firstMatch(header);
    final preferredXor = xorVarMatch != null ? (xorVarMatch as RegExpMatch).namedGroup("xor") : null;

    final List<int> invariants = [];
    final catchPattern = RegExp(
      r'catch\s*\([^)]+\)\s*\{\s*[A-Za-z0-9_$]+\s*=\s*' +
      RegExp.escape(varname) +
      r'\[(?<xor>[A-Za-z0-9_$]+)\^(?<const>\d+)\]\s*\+\s*[A-Za-z0-9_$]+\s*;\s*break\s+[A-Za-z_$]+\s*\}'
    );
    
    for (final RegExpMatch match in catchPattern.allMatches(body)) {
      final xorVar = match.namedGroup("xor");
      if (preferredXor != null && xorVar != preferredXor) {
        continue;
      }
      final invariant = int.parse(match.namedGroup("const")!) ^ w8Idx;
      if (!invariants.contains(invariant)) {
        invariants.add(invariant);
      }
    }

    return invariants;
  }

  Future<List<dynamic>> _searchNsigInvariantCandidates(
    String probeInput,
    List<int> invariants,
  ) async {
    if (invariants.isEmpty) {
      return [];
    }

    final List<List<int>> transformed = [];
    final List<List<int>> plainStrings = [];
    final Set<String> seenPairs = {};

    for (final invariant in invariants) {
      for (var firstArg = 0; firstArg < 256; firstArg++) {
        final pair = [firstArg, invariant ^ firstArg];
        final pairKey = "${pair[0]},${pair[1]}";
        if (seenPairs.contains(pairKey)) {
          continue;
        }
        seenPairs.add(pairKey);
        dynamic first;
        dynamic second;
        try {
          first = await _callWithRetry(
            _runnerNsig!,
            [pair[0], pair[1], probeInput],
            label: "nsig-probe",
          );
          second = await _callWithRetry(
            _runnerNsig!,
            [pair[0], pair[1], probeInput],
            label: "nsig-probe",
          );
        } catch (_) {
          continue;
        }
        if (!_isValidNsigOutput(first) || !_isValidNsigOutput(second) || first != second) {
          continue;
        }
        if (first != probeInput) {
          transformed.add([pair[0], pair[1]]);
          if (transformed.length >= 8) {
            return transformed;
          }
        } else {
          plainStrings.add([pair[0], pair[1]]);
        }
      }
    }

    return transformed.isNotEmpty ? transformed : plainStrings;
  }

  Future<String> getNsig(String n) async {
    await _initNsigRunner();
    dynamic nsig;
    dynamic lastExc;
    try {
      final params = _normalizeNsigParams(_nsigParamVal);
      if (params.isNotEmpty) {
        final runResult = await _runNsigCandidates(params, n);
        nsig = runResult["nsig"];
        lastExc = runResult["lastExc"];
        var workingParam = runResult["workingParam"];

        if (workingParam == null) {
          var recoveredParams = await _searchNsigXorCandidates(n, params);
          if (recoveredParams.isEmpty) {
            recoveredParams = await _searchNsigInvariantCandidates(
              n,
              _deriveNsigInvariants(_nsigFunctionName!),
            );
          }
          if (recoveredParams.isNotEmpty) {
            _nsigParamVal = recoveredParams;
            final retryResult = await _runNsigCandidates(recoveredParams, n);
            nsig = retryResult["nsig"];
            lastExc = retryResult["lastExc"];
            workingParam = retryResult["workingParam"];
          }
        }
        if (workingParam != null && _nsigParamVal is List) {
          _nsigParamVal = workingParam is List ? [workingParam] : workingParam;
        }
      } else {
        nsig = await _callWithRetry(_runnerNsig!, [n], label: "nsig");
      }
    } catch (e) {
      throw InterpretationError(jsUrl, e);
    }

    if (!_isValidNsigOutput(nsig)) {
      throw InterpretationError(jsUrl, lastExc ?? nsig);
    }
    return nsig as String;
  }

  Future<String> getSig(String cipheredSignature) async {
    await _initSigRunner();
    dynamic sig;
    try {
      if (_sigParamVal != null) {
        if (_sigParamVal is List) {
          sig = await _callWithRetry(_runnerSig!, [..._sigParamVal!, cipheredSignature], label: "sig");
        } else {
          sig = await _callWithRetry(_runnerSig!, [_sigParamVal, cipheredSignature], label: "sig");
        }
      } else {
        sig = await _callWithRetry(_runnerSig!, [cipheredSignature], label: "sig");
      }
    } catch (e) {
      throw InterpretationError(jsUrl, e);
    }

    if (sig is! String || sig.contains('error')) {
      throw InterpretationError(jsUrl, sig);
    }
    return sig;
  }

  String getSigFunctionName(String js, String jsUrl) {
    final functionPatterns = [
      // Temp-variable chain
      r'([a-zA-Z0-9$_]+)\s*=\s*(?<sig>[a-zA-Z0-9$_]+)\((?<param>\d+),(?<param2>\d+),(?:[a-zA-Z0-9$_]+\(\d+,\d+,)*(?:decodeURIComponent\()?[a-zA-Z0-9$_.]+\.s\)+\s*;[^;]{0,160}\b[a-zA-Z0-9$_]+\(\d+,\d+,[a-zA-Z0-9$_]+\)',
      // New obfuscated patterns
      r'[a-zA-Z0-9$_]+\(\d+,\d+,(?<sig>[a-zA-Z0-9$_]+)\((?<param>\d+),(?<param2>\d+),[a-zA-Z0-9$_.]+\.s\)\)',
      r'(?<sig>[a-zA-Z0-9$_]+)\((?<param>\d+),(?<param2>\d+),(?:[a-zA-Z0-9$_]+\(\d+,\d+,|decodeURIComponent\()[a-zA-Z0-9$_.]+\.s\)\)',
      r'(?<sig>[a-zA-Z0-9$_]+)\((?<param>\d+),(?<param2>\d+),(?:[a-zA-Z0-9$_]+\(\d+,\d+,|decodeURIComponent\()[a-zA-Z0-9$_]+\)\),[a-zA-Z0-9$_]+\[',
      // Classic patterns
      r'(?<sig>[a-zA-Z0-9_$]+)\s*=\s*function\(\s*(?<arg>[a-zA-Z0-9_$]+)\s*\)\s*{\s*[a-zA-Z0-9_$]+\s*=\s*[a-zA-Z0-9_$]+\.split\(\s*[a-zA-Z0-9_\$\"\[\]]+\s*\)\s*;\s*[^}]+;\s*return\s+[a-zA-Z0-9_$]+\.join\(\s*[a-zA-Z0-9_\$\"\[\]]+\s*\)',
      r'(?:\b|[^a-zA-Z0-9_$])(?<sig>[a-zA-Z0-9_$]{2,})\s*=\s*function\(\s*a\s*\)\s*{\s*a\s*=\s*a\.split\(\s*""\s*\)(?:;[a-zA-Z0-9_$]{2}\.[a-zA-Z0-9_$]{2}\(a,\d+\))?',
      r'\b(?<var>[a-zA-Z0-9_$]+)&&\([a-zA-Z0-9_$]+=(?<sig>[a-zA-Z0-9_$]{2,})\((?:(?<param>\d+),decodeURIComponent|decodeURIComponent)\([a-zA-Z0-9_$]+\)\)',
      // Old patterns
      r'\b[cs]\s*&&\s*[adf]\.set\([^,]+\s*,\s*encodeURIComponent\s*\(\s*(?<sig>[a-zA-Z0-9$]+)\(',
      r'\b[a-zA-Z0-9]+\s*&&\s*[a-zA-Z0-9]+\.set\([^,]+\s*,\s*encodeURIComponent\s*\(\s*(?<sig>[a-zA-Z0-9$]+)\(',
      r'\bm=(?<sig>[a-zA-Z0-9$]{2,})\(decodeURIComponent\(h\.s\)\)',
      // Obsolete patterns
      r'''("|\')signature\1\s*,\s*(?<sig>[a-zA-Z0-9$]+)\(''',
      r'\.sig\|\|(?<sig>[a-zA-Z0-9$]+)\(',
      r'yt\.akamaized\.net/\)\s*\|\|\s*.*?\s*[cs]\s*&&\s*[adf]\.set\([^,]+\s*,\s*(?:encodeURIComponent\s*\()?\s*(?<sig>[a-zA-Z0-9$]+)\(',
      r'\b[cs]\s*&&\s*[adf]\.set\([^,]+\s*,\s*(?<sig>[a-zA-Z0-9$]+)\(',
      r'\bc\s*&&\s*[a-zA-Z0-9]+\.set\([^,]+\s*,\s*\([^)]*\)\s*\(\s*(?<sig>[a-zA-Z0-9$]+)\('
    ];

    for (final pattern in functionPatterns) {
      final regex = RegExp(pattern);
      final match = regex.firstMatch(js);
      if (match != null) {
        final rm = match as RegExpMatch;
        final sig = rm.namedGroup('sig')!;
        final param = rm.groupNames.contains('param') ? rm.namedGroup('param') : null;
        final param2 = rm.groupNames.contains('param2') ? rm.namedGroup('param2') : null;
        if (param2 != null && param2.isNotEmpty) {
          _sigParamVal = [int.parse(param!), int.parse(param2)];
        } else if (param != null && param.isNotEmpty) {
          _sigParamVal = [int.parse(param)];
        }
        return sig;
      }
    }

    throw RegexMatchError("getSigFunctionName", "multiple in $jsUrl");
  }

  Future<String> getNsigFunctionName(String js, String jsUrl) async {
    try {
      List<dynamic>? globalObj;
      String? varname;
      
      final extracted = extractPlayerJsGlobalVar(js);
      final globalObjCode = extracted[0];
      final extractedVarname = extracted[1];
      final code = extracted[2];
      
      if (globalObjCode != null && extractedVarname != null && code != null) {
        globalObj = interpretSimpleJsExpression(code) as List<dynamic>?;
        varname = extractedVarname;
      } else {
        final tce = _extractSplitPlayerJsGlobalVar(js);
        varname = tce.key;
        globalObj = tce.value;
        if (varname == null || globalObj == null) {
          final prop = _extractPropertyArrayPlayerJsGlobalVar(js);
          varname = prop.key;
          globalObj = prop.value;
        }
      }

      if (globalObj != null && varname != null) {
        int? w8Idx;
        for (var k = 0; k < globalObj.length; k++) {
          final val = globalObj[k];
          if (val is String && val.endsWith('_w8_')) {
            w8Idx = k;
            break;
          }
        }

        if (w8Idx != null) {
          // Strategy 1a: Find via catch block with XOR reference
          final xorCatch = RegExp(
            r'catch\s*\([^)]+\)\s*\{\s*'
            r'[A-Za-z0-9_$]+\s*=\s*'
            r'' + RegExp.escape(varname) +
            r'\[(?<xor>[A-Za-z0-9_$]+)\^(?<const>\d+)\]\s*\+\s*(?<arg>[A-Za-z0-9_$]+)\s*;\s*break\s+a\s*\}'
          );
          
          for (final Match m in xorCatch.allMatches(js)) {
            final cm = m as RegExpMatch;
            final xorVar = cm.namedGroup("xor")!;
            final w8Const = int.parse(cm.namedGroup("const")!);
            final argVar = cm.namedGroup("arg")!;

            final searchStart = cm.start - 5000 > 0 ? cm.start - 5000 : 0;
            final funcArea = js.substring(searchStart, cm.start);
            final fms = RegExp(r'(?:(?<func1>[a-zA-Z0-9_$]+)\s*=\s*function|function\s+(?<func2>[a-zA-Z0-9_$]+))\s*\(([^)]*)\)')
                .allMatches(funcArea).toList();
            if (fms.isEmpty) continue;

            final last = fms.last as RegExpMatch;
            final nFunc = last.namedGroup("func1") ?? last.namedGroup("func2")!;
            final actualStart = searchStart + last.start;

            final headerArea = js.substring(actualStart, actualStart + 200 > js.length ? js.length : actualStart + 200);
            if (!RegExp(r'var\s+' + RegExp.escape(xorVar) + r'\s*=\s*[A-Za-z0-9_$]+\s*\^\s*[A-Za-z0-9_$]+').hasMatch(headerArea)) {
              continue;
            }

            final branchStart = cm.start - 2000 > actualStart ? cm.start - 2000 : actualStart;
            final branchEnd = cm.end + 1200 < js.length ? cm.end + 1200 : js.length;
            final String body;
            if (branchStart <= actualStart + 200) {
              body = js.substring(actualStart, branchEnd);
            } else {
              body = js.substring(actualStart, actualStart + 200) + js.substring(branchStart, branchEnd);
            }

            final w8XorB = w8Const ^ w8Idx;
            final xorParams = _extractXorBranchNsigParams(
              js, nFunc, varname, globalObj,
              body: body,
              xorVar: xorVar,
              argVar: argVar,
              w8XorB: w8XorB,
            );
            if (xorParams != null) {
              _nsigParamVal = xorParams;
            } else {
              _nsigParamVal = _extractNsigParamVal(js, nFunc);
            }
            return nFunc;
          }

          // Strategy 1a-bis: Find via catch block with DIRECT (non-XOR) index reference
          final directCatch = RegExp(
            r'catch\s*\([^)]+\)\s*\{\s*'
            r'[A-Za-z0-9_$]+\s*=\s*'
            r'' + RegExp.escape(varname) +
            r'\[(?<idx>\d+)\]\s*\+\s*(?<arg>[A-Za-z0-9_$]+)\s*;\s*break\s+a\s*\}'
          );
          for (final Match m in directCatch.allMatches(js)) {
            final cm = m as RegExpMatch;
            if (int.parse(cm.namedGroup("idx")!) != w8Idx) {
              continue;
            }
            final argVar = cm.namedGroup("arg")!;

            final searchStart = cm.start - 5000 > 0 ? cm.start - 5000 : 0;
            final funcArea = js.substring(searchStart, cm.start);
            final fms = RegExp(r'(?:(?<func1>[a-zA-Z0-9_$]+)\s*=\s*function|function\s+(?<func2>[a-zA-Z0-9_$]+))\s*\(([^)]*)\)')
                .allMatches(funcArea).toList();
            if (fms.isEmpty) continue;

            final last = fms.last as RegExpMatch;
            final nFunc = last.namedGroup("func1") ?? last.namedGroup("func2")!;
            final actualStart = searchStart + last.start;

            final headerArea = js.substring(actualStart, actualStart + 200 > js.length ? js.length : actualStart + 200);
            final xorHeaderM = RegExp(r'var\s+([A-Za-z0-9_$]+)\s*=\s*[A-Za-z0-9_$]+\s*\^\s*[A-Za-z0-9_$]+').firstMatch(headerArea);
            if (xorHeaderM == null) {
              continue;
            }
            final xorVarFound = xorHeaderM.group(1)!;

            final branchStart = cm.start - 2000 > actualStart ? cm.start - 2000 : actualStart;
            final branchEnd = cm.end + 1200 < js.length ? cm.end + 1200 : js.length;
            final String body;
            if (branchStart <= actualStart + 200) {
              body = js.substring(actualStart, branchEnd);
            } else {
              body = js.substring(actualStart, actualStart + 200) + js.substring(branchStart, branchEnd);
            }

            final xorParams = _extractXorBranchNsigParams(
              js, nFunc, varname, globalObj,
              body: body,
              xorVar: xorVarFound,
              argVar: argVar,
              w8XorB: null,
            );
            if (xorParams != null) {
              _nsigParamVal = xorParams;
            } else {
              _nsigParamVal = _extractNsigParamVal(js, nFunc);
            }
            return nFunc;
          }

          // Strategy 1b: Find via catch block with direct index reference
          // Re-written to avoid Python's conditional groups and inline modifiers
          final List<String> nsigPatterns = [
            // Pattern starts with "function"
            r'[;\n]function\s+(?<funcname>[a-zA-Z0-9_$]+)\s*\(\s*(?:[a-zA-Z0-9_$]+\s*,\s*)?(?<argname>[a-zA-Z0-9_$]+)(?:\s*,\s*[a-zA-Z0-9_$]+)*\s*\)\s*\{[\s\S]*?\}\s*catch\(\s*[a-zA-Z0-9_$]+\s*\)\s*\{\s*(?:return\s+|[\w=]+)' + RegExp.escape(varname) + r'\[' + w8Idx.toString() + r'\]\s*\+\s*[a-zA-Z0-9_$]+\s*[\};][\s\S]*?return\s+[^}]+\}[;\n]',
            // Pattern starts with var assign
            r'[;\n](?:var\s+)?(?<funcname>[a-zA-Z0-9_$]+)\s*=\s*function\s*\(\s*(?:[a-zA-Z0-9_$]+\s*,\s*)?(?<argname>[a-zA-Z0-9_$]+)(?:\s*,\s*[a-zA-Z0-9_$]+)*\s*\)\s*\{[\s\S]*?\}\s*catch\(\s*[a-zA-Z0-9_$]+\s*\)\s*\{\s*(?:return\s+|[\w=]+)' + RegExp.escape(varname) + r'\[' + w8Idx.toString() + r'\]\s*\+\s*[a-zA-Z0-9_$]+\s*[\};][\s\S]*?return\s+[^}]+\}[;\n]',
            
            // Relaxed functions referencing varname[w8_idx]
            r'[;\n]function\s+(?<funcname>[a-zA-Z0-9_$]+)\s*\([^)]*\)\s*\{[\s\S]*?' + RegExp.escape(varname) + r'\[' + w8Idx.toString() + r'\][\s\S]*?\}[;\n]',
            r'[;\n](?:var\s+)?(?<funcname>[a-zA-Z0-9_$]+)\s*=\s*function\s*\([^)]*\)\s*\{[\s\S]*?' + RegExp.escape(varname) + r'\[' + w8Idx.toString() + r'\][\s\S]*?\}[;\n]',
          ];

          for (final np in nsigPatterns) {
            final match = RegExp(np).firstMatch(js);
            if (match != null) {
              final rm = match as RegExpMatch;
              final nFunc = rm.namedGroup("funcname")!;
              final xorParams = _extractXorBranchNsigParams(js, nFunc, varname, globalObj);
              if (xorParams != null) {
                _nsigParamVal = xorParams;
              } else {
                _nsigParamVal = _extractNsigParamVal(js, nFunc);
              }
              return nFunc;
            }
          }
        }
      }

      // Strategy 2: var XX = [YY]
      final strategy2Match = RegExp(r"var\s*[a-zA-Z0-9$_]{2,3}\s*=\s*\[(?<funcname>[a-zA-Z0-9$_]{2,})\]").firstMatch(js) as RegExpMatch?;
      if (strategy2Match != null) {
        final nFunc = strategy2Match.namedGroup("funcname")!;
        if (globalObj != null && varname != null) {
          final xorParams = _extractXorBranchNsigParams(js, nFunc, varname, globalObj);
          if (xorParams != null) {
            _nsigParamVal = xorParams;
          } else {
            _nsigParamVal = _extractNsigParamVal(js, nFunc);
          }
        }
        return nFunc;
      }

      // Strategy 2.5: Multi-branch XOR nsig function (2025+ obfuscation)
      final xorFuncPatternA = RegExp(
        r'([a-zA-Z0-9_$]+)\s*=\s*function\s*\(([a-zA-Z0-9_$]+)\s*,\s*([a-zA-Z0-9_$]+)\s*,\s*([a-zA-Z0-9_$]+)(?:\s*,\s*[a-zA-Z0-9_$]+)*\)\s*\{'
        r'var\s+([a-zA-Z0-9_$]+)\s*=\s*\3\s*\^\s*\2\b'
      );
      final xorFuncPatternB = RegExp(
        r'([a-zA-Z0-9_$]+)\s*=\s*function\s*\(([a-zA-Z0-9_$]+)\s*,\s*([a-zA-Z0-9_$]+)\s*,\s*([a-zA-Z0-9_$]+)(?:\s*,\s*[a-zA-Z0-9_$]+){2,}\)\s*\{'
        r'var\s+([a-zA-Z0-9_$]+)\s*=\s*\3\s*\^\s*\2\b'
      );

      for (final pattern in [xorFuncPatternA, xorFuncPatternB]) {
        for (final xfm in pattern.allMatches(js)) {
          final candidate = xfm.group(1)!;
          final param1 = xfm.group(2)!;
          final param2 = xfm.group(3)!;
          final param3 = xfm.group(4)!;
          final xorVar = xfm.group(5)!;
          final funcStart = xfm.start;

          final chunk = js.substring(funcStart, funcStart + 1000 < js.length ? funcStart + 1000 : js.length);
          final recursive = RegExp(RegExp.escape(candidate) + r'\(([a-zA-Z0-9_$]+)\^(?<c1>\d+)\s*,\s*\1\^(?<c2>\d+)\s*,')
              .firstMatch(chunk) as RegExpMatch?;
          if (recursive == null) {
            continue;
          }

          var depth = 0;
          var funcEnd = funcStart;
          for (var i = funcStart; i < (funcStart + 50000 < js.length ? funcStart + 50000 : js.length); i++) {
            if (js[i] == '{') {
              depth++;
            } else if (js[i] == '}') {
              depth--;
              if (depth == 0) {
                funcEnd = i + 1;
                break;
              }
            }
          }
          final funcBody = js.substring(funcStart, funcEnd);

          final hasTry = funcBody.contains('try{') || funcBody.contains('try {');
          final hasNull = 'null'.allMatches(funcBody).length >= 2;
          final xorRefs = RegExp(r'\w\[' + RegExp.escape(xorVar) + r'\^').allMatches(funcBody).length;

          if (hasTry && hasNull && xorRefs > 20) {
            final c1 = int.parse(recursive.namedGroup("c1")!);
            final c2 = int.parse(recursive.namedGroup("c2")!);
            final aVal = c1 ^ c2;

            _nsigParamVal = [];
            for (final rVal in [73, 74, 75, 77, 78, 79, 13, 14, 15, 12, 29, 30, 31, 28, 1, 0]) {
              _nsigParamVal!.add([rVal, aVal ^ rVal]);
            }
            return candidate;
          }
        }
      }

      // Strategy 3: Broader var=[func], validate it's nsig (has try/catch)
      for (final Match match in RegExp(r"var\s*[a-zA-Z0-9$_]+\s*=\s*\[(?<funcname>[a-zA-Z0-9$_]+)\]").allMatches(js)) {
        final rm = match as RegExpMatch;
        final candidate = rm.namedGroup("funcname")!;
        final funcDef = RegExp(
          r'(?:function\s+' + RegExp.escape(candidate) +
          r'|(?:var\s+)?' + RegExp.escape(candidate) + r'\s*=\s*function)\s*\('
        ).firstMatch(js);
        if (funcDef == null) {
          continue;
        }
        final funcStart = funcDef.start;

        var depth = 0;
        var funcEnd = funcStart;
        for (var i = funcStart; i < (funcStart + 10000 < js.length ? funcStart + 10000 : js.length); i++) {
          if (js[i] == '{') {
            depth++;
          } else if (js[i] == '}') {
            depth--;
            if (depth == 0) {
              funcEnd = i + 1;
              break;
            }
          }
        }
        final funcBody = js.substring(funcStart, funcEnd);

        if (funcBody.length < 200) {
          continue;
        }

        if (funcBody.contains('try{') || funcBody.contains('try {') || funcBody.contains('catch(')) {
          if (globalObj != null && varname != null) {
            final xorParams = _extractXorBranchNsigParams(js, candidate, varname, globalObj, body: funcBody);
            if (xorParams != null) {
              _nsigParamVal = xorParams;
            } else {
              _nsigParamVal = _extractNsigParamVal(js, candidate);
            }
          } else {
            _nsigParamVal = _extractNsigParamVal(js, candidate);
          }
          return candidate;
        }
      }

      throw RegexMatchError("getNsigFunctionName", "multiple in $jsUrl");
    } catch (e) {
      rethrow;
    }
  }

  List<dynamic>? _extractXorBranchNsigParams(
    String jsCode, String funcName, String globalVarName, List<dynamic> globalArr, {
    String? body,
    String? xorVar,
    String? argVar,
    int? w8XorB,
  }) {
    if (body == null) {
      final funcDefs = RegExp(
        r'(?<![A-Za-z0-9_$.])(?:function\s+' + RegExp.escape(funcName) + r'(?![A-Za-z0-9_$])|'
        r'(?:var\s+)?' + RegExp.escape(funcName) + r'(?![A-Za-z0-9_$])\s*=\s*function)\s*\('
      ).allMatches(jsCode).toList();
      if (funcDefs.isEmpty) return null;

      final funcDef = funcDefs.last;
      final funcStart = funcDef.start;
      var depth = 0;
      var funcEnd = funcStart;
      for (var i = funcStart; i < (funcStart + 50000 < jsCode.length ? funcStart + 50000 : jsCode.length); i++) {
        if (jsCode[i] == '{') {
          depth++;
        } else if (jsCode[i] == '}') {
          depth--;
          if (depth == 0) {
            funcEnd = i + 1;
            break;
          }
        }
      }
      body = jsCode.substring(funcStart, funcEnd);
    }

    final xorM = RegExp(r'var\s+([A-Za-z0-9_$]+)\s*=\s*([A-Za-z0-9_$]+)\s*\^\s*([A-Za-z0-9_$]+)').firstMatch(body);
    if (xorM == null) return null;

    xorVar ??= xorM.group(1)!;

    if (!globalArr.contains('split') || !globalArr.contains('')) {
      return null;
    }
    final splitIdx = globalArr.indexOf('split');
    final emptyIdx = globalArr.indexOf('');

    final argPat = argVar != null ? RegExp.escape(argVar) : r'[A-Za-z0-9_$]+';
    final gv = RegExp.escape(globalVarName);
    final xv = RegExp.escape(xorVar);

    final List<RegExp> splitPatterns = [
      RegExp(argPat + r'\[' + gv + r'\[' + xv + r'\^\s*(\d+)\]\]\(' + gv + r'\[' + xv + r'\^\s*(\d+)\]\)'),
      RegExp(argPat + r'\[' + gv + r'\[' + xv + r'\^\s*(\d+)\]\]\(' + gv + r'\[(\d+)\]\)'),
      RegExp(argPat + r'\[' + gv + r'\[(\d+)\]\]\(' + gv + r'\[' + xv + r'\^\s*(\d+)\]\)'),
      RegExp(argPat + r'\[' + gv + r'\[(\d+)\]\]\(' + gv + r'\[(\d+)\]\)'),
    ];

    int? resolvedI;
    Match? splitOp;
    var matchedPatternIdx = -1;

    for (var patIdx = 0; patIdx < splitPatterns.length; patIdx++) {
      final pattern = splitPatterns[patIdx];
      for (final Match match in pattern.allMatches(body)) {
        final k1 = int.parse(match.group(1)!);
        final k2Raw = int.parse(match.group(2)!);

        int candidateI;
        int checkIdx;

        if (patIdx == 0) {
          candidateI = splitIdx ^ k1;
          checkIdx = candidateI ^ k2Raw;
        } else if (patIdx == 1) {
          candidateI = splitIdx ^ k1;
          checkIdx = k2Raw;
        } else if (patIdx == 2) {
          if (k1 != splitIdx) continue;
          candidateI = emptyIdx ^ k2Raw;
          checkIdx = emptyIdx;
        } else {
          if (k1 != splitIdx || k2Raw != emptyIdx) continue;
          candidateI = w8XorB ?? 0;
          checkIdx = k2Raw;
        }

        if (checkIdx >= 0 && checkIdx < globalArr.length && globalArr[checkIdx] == '') {
          if (w8XorB != null && candidateI != w8XorB) {
            continue;
          }
          resolvedI = candidateI;
          splitOp = match;
          matchedPatternIdx = patIdx;
          break;
        }
      }
      if (resolvedI != null) break;
    }

    if (resolvedI == null || splitOp == null) {
      return null;
    }

    final paramNames = [xorM.group(2)!, xorM.group(3)!];
    final splitPos = splitOp.start;
    final preSplit = body.substring(0, splitPos);

    int? X;
    int? F;

    Map<String, dynamic>? maskBranchMeta;
    Map<String, dynamic>? orBranchMeta;

    // Pattern 1: !(P-C>>S) — older style, e.g. !(X-9>>3)
    for (final pname in paramNames) {
      final branchM = RegExp(
        r'!\s*\(' + RegExp.escape(pname) + r'\s*-\s*(\d+)\s*>>\s*(\d+)\)'
      ).firstMatch(preSplit);
      if (branchM != null) {
        final center = int.parse(branchM.group(1)!);
        final shift = int.parse(branchM.group(2)!);
        for (var xCandidate = 0; xCandidate < 256; xCandidate++) {
          if (((xCandidate - center) >> shift) == 0) {
            X = xCandidate;
            break;
          }
        }
        if (X != null) {
          F = resolvedI ^ X!;
          break;
        }
      }
    }

    // Pattern 2: (P+C>>S)==V — e.g. (O+4>>3)==3 or O+4>>3==3
    if (X == null) {
      for (final pname in paramNames) {
        final branchM = RegExp(
          r'if\s*\(\s*\(?' + RegExp.escape(pname) + r'\s*\+\s*(\d+)\s*>>\s*(\d+)\)?\s*==\s*(\d+)\s*\)\s*[a-zA-Z_$]:\{'
        ).firstMatch(body);
        if (branchM != null) {
          final offset = int.parse(branchM.group(1)!);
          final shift = int.parse(branchM.group(2)!);
          final target = int.parse(branchM.group(3)!);
          final minVal = target * (1 << shift) - offset;
          X = minVal;
          if (X! >= 0 && X! < 256) {
            F = resolvedI ^ X!;
            break;
          }
          X = null;
        }
      }
    }

    // Pattern 3: Compound conditions with && — e.g. (p-7|46)<p&&(p+4&56)>=p
    if (X == null) {
      for (final pname in paramNames) {
        final branchM = RegExp(
          r'if\s*\(\s*\(' + RegExp.escape(pname) + r'-(\d+)\|(\d+)\)<' + RegExp.escape(pname) +
          r'&&\(' + RegExp.escape(pname) + r'\+(\d+)&(\d+)\)>=' + RegExp.escape(pname) + r'\s*\)\s*[a-zA-Z_$]:\{'
        ).firstMatch(body);
        if (branchM != null) {
          final c1 = int.parse(branchM.group(1)!);
          final c2 = int.parse(branchM.group(2)!);
          final c3 = int.parse(branchM.group(3)!);
          final c4 = int.parse(branchM.group(4)!);
          for (var xCandidate = 1; xCandidate < 256; xCandidate++) {
            final cond1 = ((xCandidate - c1) | c2) < xCandidate;
            final cond2 = ((xCandidate + c3) & c4) >= xCandidate;
            final avoidBranch1 = (xCandidate | 24) == xCandidate;
            final avoidBranch3 = (xCandidate << 1) & 7 == 0;
            if (cond1 && cond2 && !avoidBranch1 && !avoidBranch3) {
              X = xCandidate;
              F = resolvedI ^ X!;
              break;
            }
          }
          if (X != null) break;
        }
      }
    }

    // Pattern 4: Simple arithmetic range-check — e.g. P+3<38&&P+4>=26
    if (X == null) {
      for (final pname in paramNames) {
        final branchM = RegExp(
          r'if\s*\(\s*' + RegExp.escape(pname) + r'\+(\d+)<(\d+)&&' +
          RegExp.escape(pname) + r'\+(\d+)>=(\d+)\s*\)\s*[a-zA-Z_$]:\{'
        ).firstMatch(body);
        if (branchM != null) {
          final off1 = int.parse(branchM.group(1)!);
          final limit1 = int.parse(branchM.group(2)!);
          final off2 = int.parse(branchM.group(3)!);
          final limit2 = int.parse(branchM.group(4)!);
          final lo = limit2 - off2;
          final hi = limit1 - off1;
          final allBranchConds = RegExp(r'if\s*\((.+?)\)\s*[a-zA-Z_$]:\{').allMatches(body).toList();
          
          for (var xCandidate = hi - 1; xCandidate >= lo; xCandidate--) {
            if (xCandidate < 0) continue;
            var triggersOther = false;
            for (final otherCond in allBranchConds) {
              final condStr = otherCond.group(1)!;
              final fullMatchStr = branchM.group(0)!;
              final ownCondStr = fullMatchStr.substring(fullMatchStr.indexOf('(') + 1, fullMatchStr.lastIndexOf(')'));
              if (condStr == ownCondStr) continue;
              if (!condStr.contains(pname)) continue;
              try {
                if (evalJsCondition(condStr, pname, xCandidate)) {
                  triggersOther = true;
                  break;
                }
              } catch (_) {}
            }
            if (!triggersOther) {
              X = xCandidate;
              F = resolvedI ^ X!;
              break;
            }
          }
          if (X != null) break;
        }
      }
    }

    // Pattern 5: Bitmask-equality branch — e.g. (U&115)==U
    if (X == null) {
      for (final pname in paramNames) {
        final branchM = RegExp(
          r'if\s*\(\s*\(' + RegExp.escape(pname) + r'\s*&\s*(\d+)\)\s*==\s*' +
          RegExp.escape(pname) + r'\s*\)\s*[a-zA-Z_$]:\{'
        ).firstMatch(body);
        if (branchM != null) {
          final mask = int.parse(branchM.group(1)!);
          final targetNorm = _normalizeJsCond('(${pname}&${mask})==${pname}');
          final List<String> extraConds = [];
          final extraPatterns = [
            RegExp(r'\(\(\s*' + RegExp.escape(pname) + r'\s*\|\s*\d+\)\s*&\s*\d+\)\s*<\s*\d+\s*&&\s*\(\s*' + RegExp.escape(pname) + r'\s*\^\s*\d+\)\s*>>\s*\d+\s*>=?\s*0'),
            RegExp(r'\b' + RegExp.escape(pname) + r'\s*-\s*\d+\s*>>\s*\d+\s*>=?\s*0\s*&&\s*\(\s*' + RegExp.escape(pname) + r'\s*-\s*\d+\s*&\s*\d+\)\s*<\s*\d+'),
            RegExp(r'\(\s*' + RegExp.escape(pname) + r'\s*\|\s*\d+\)\s*==\s*' + RegExp.escape(pname)),
            RegExp(r'\(\s*' + RegExp.escape(pname) + r'\s*&\s*\d+\)\s*==\s*' + RegExp.escape(pname)),
          ];
          for (final ep in extraPatterns) {
            for (final Match match in ep.allMatches(body)) {
              final cond = match.group(0)!;
              if (_normalizeJsCond(cond) != targetNorm && !extraConds.contains(cond)) {
                extraConds.add(cond);
              }
            }
          }
          for (var xCandidate = 0; xCandidate < 256; xCandidate++) {
            if ((xCandidate & mask) != xCandidate) continue;
            var anyTriggered = false;
            for (final cond in extraConds) {
              try {
                if (evalJsCondition(cond, pname, xCandidate)) {
                  anyTriggered = true;
                  break;
                }
              } catch (_) {}
            }
            if (anyTriggered) continue;
            X = xCandidate;
            F = resolvedI ^ X!;
            maskBranchMeta = {
              'pname': pname,
              'mask': mask,
              'extraConds': extraConds,
            };
            break;
          }
          if (X != null) break;
        }
      }
    }

    // Pattern 6: Or-equality branch - e.g. (n|8)==n or (I|40)==I
    if (X == null) {
      final allIfConds = _extractIfConditions(body);
      for (final pname in paramNames) {
        final branchMatches = RegExp(
          r'if\s*\(\s*(?<cond>\(\s*' + RegExp.escape(pname) + r'\s*\|\s*(?<mask>\d+)\)\s*==\s*' + RegExp.escape(pname) + r')\s*\)\s*[a-zA-Z_$]:\{'
        ).allMatches(preSplit).toList();
        if (branchMatches.isEmpty) continue;
        final branchM = branchMatches.last;
        final mask = int.parse(branchM.namedGroup('mask')!);
        final targetNorm = _normalizeJsCond(branchM.namedGroup('cond')!);
        final List<String> extraConds = [];
        for (final cond in allIfConds) {
          if (!cond.contains(pname)) continue;
          if (_normalizeJsCond(cond) == targetNorm) continue;
          extraConds.add(cond);
        }
        final extraPatterns = [
          RegExp(r'\(\s*' + RegExp.escape(pname) + r'\s*[+-]\s*\d+\s*\^\s*\d+\)\s*[<>]=?\s*' + RegExp.escape(pname) + r'\s*&&\s*\(\s*' + RegExp.escape(pname) + r'\s*[+-]\s*\d+\s*\^\s*\d+\)\s*[<>]=?\s*' + RegExp.escape(pname)),
          RegExp(r'\b' + RegExp.escape(pname) + r'\s*-\s*\d+\s*<<\s*\d+\s*<\s*' + RegExp.escape(pname) + r'\s*&&\s*\(\s*' + RegExp.escape(pname) + r'\s*\+\s*\d+\s*&\s*\d+\)\s*>=?\s*' + RegExp.escape(pname)),
          RegExp(r'\(\s*' + RegExp.escape(pname) + r'\s*\+\s*\d+\s*\^\s*\d+\)\s*>=?\s*' + RegExp.escape(pname) + r'\s*&&\s*' + RegExp.escape(pname) + r'\s*\+\s*\d+\s*>>\s*\d+\s*<\s*' + RegExp.escape(pname)),
          RegExp(r'\(\(\s*' + RegExp.escape(pname) + r'\s*\|\s*\d+\)\s*&\s*\d+\)\s*<\s*\d+\s*&&\s*\(\s*' + RegExp.escape(pname) + r'\s*\^\s*\d+\)\s*>>\s*\d+\s*>=?\s*0'),
          RegExp(r'\(\s*' + RegExp.escape(pname) + r'\s*\|\s*\d+\)\s*==\s*' + RegExp.escape(pname)),
        ];
        for (final ep in extraPatterns) {
          for (final Match match in ep.allMatches(body)) {
            final cond = match.group(0)!;
            if (_normalizeJsCond(cond) != targetNorm && !extraConds.contains(cond)) {
              extraConds.add(cond);
            }
          }
        }
        final picked = _pickBranchCandidate(
          pname,
          (xCandidate) => (xCandidate | mask) == xCandidate,
          extraConds,
        );
        if (picked != null) {
          X = picked.x;
          F = resolvedI ^ X!;
          orBranchMeta = {
            'pname': pname,
            'mask': mask,
            'extraConds': extraConds,
          };
          break;
        }
      }
    }

    // Pattern 7: Plain if-block guard before split - e.g. if((e-1&11)>=5&&e+7>>4<2){...}
    if (X == null) {
      final List<MapEntry<int, String>> allConds = [];
      final allIfConds = _extractIfConditions(body);
      final regex = RegExp(r'if\s*\(');
      for (final Match match in regex.allMatches(preSplit)) {
        final openIdx = match.end - 1;
        var depth = 1;
        int? condEnd;
        for (var i = openIdx + 1; i < preSplit.length; i++) {
          if (preSplit[i] == '(') {
            depth++;
          } else if (preSplit[i] == ')') {
            depth--;
            if (depth == 0) {
              condEnd = i;
              break;
            }
          }
        }
        if (condEnd == null) continue;
        allConds.add(MapEntry(match.start, preSplit.substring(openIdx + 1, condEnd)));
      }

      for (final entry in allConds.reversed) {
        final nsigCond = entry.value;
        for (final pname in paramNames) {
          if (!nsigCond.contains(pname)) continue;
          final targetNorm = _normalizeJsCond(nsigCond);
          final List<String> extraConds = [];
          for (final otherCond in allIfConds) {
            if (!otherCond.contains(pname)) continue;
            if (_normalizeJsCond(otherCond) == targetNorm) continue;
            extraConds.add(otherCond);
          }
          final picked = _pickBranchCandidate(
            pname,
            (xCandidate) {
              try {
                return evalJsCondition(nsigCond, pname, xCandidate);
              } catch (_) {
                return false;
              }
            },
            extraConds,
          );
          if (picked != null) {
            X = picked.x;
            F = resolvedI ^ X!;
            break;
          }
        }
        if (X != null) break;
      }
    }

    // Pattern 8: Collect all if(COND)label:{ conditions before the split
    if (X == null) {
      final List<MapEntry<int, String>> allConds = [];
      final allIfConds = _extractIfConditions(preSplit);
      final regex = RegExp(r'if\s*\(');
      for (final Match match in regex.allMatches(preSplit)) {
        final ifStart = match.end - 1;
        var depth = 0;
        int? condEnd;
        for (var i = ifStart; i < preSplit.length; i++) {
          if (preSplit[i] == '(') {
            depth++;
          } else if (preSplit[i] == ')') {
            depth--;
            if (depth == 0) {
              condEnd = i;
              break;
            }
          }
        }
        if (condEnd == null) continue;
        
        final checkSubStr = preSplit.substring(condEnd + 1);
        final labelMatch = RegExp(r'^\s*([a-zA-Z_$]+)\s*:\s*\{').firstMatch(checkSubStr);
        if (labelMatch != null) {
          final condition = preSplit.substring(ifStart + 1, condEnd);
          allConds.add(MapEntry(match.start, condition));
        }
      }

      for (final entry in allConds.reversed) {
        final nsigCond = entry.value;
        for (final pname in paramNames) {
          if (!nsigCond.contains(pname)) continue;
          final targetNorm = _normalizeJsCond(nsigCond);
          final List<String> extraConds = [];
          for (final otherCond in allIfConds) {
            if (!otherCond.contains(pname)) continue;
            if (_normalizeJsCond(otherCond) == targetNorm) continue;
            extraConds.add(otherCond);
          }
          final picked = _pickBranchCandidate(
            pname,
            (xCandidate) {
              try {
                return evalJsCondition(nsigCond, pname, xCandidate);
              } catch (_) {
                return false;
              }
            },
            extraConds,
          );
          if (picked != null) {
            X = picked.x;
            F = resolvedI ^ X!;
            break;
          }
        }
        if (X != null) break;
      }
    }

    if (X == null) {
      return null;
    }

    final List<dynamic> candidates = [[X, resolvedI ^ X!]];

    if (maskBranchMeta != null) {
      final String pname = maskBranchMeta['pname'] as String;
      final int mask = maskBranchMeta['mask'] as int;
      final List<String> extraConds = List<String>.from(maskBranchMeta['extraConds'] as List);
      for (var altX = X! + 1; altX < 256; altX++) {
        if ((altX & mask) != altX) continue;
        var anyTriggered = false;
        for (final cond in extraConds) {
          try {
            if (evalJsCondition(cond, pname, altX)) {
              anyTriggered = true;
              break;
            }
          } catch (_) {}
        }
        if (anyTriggered) continue;
        candidates.add([altX, resolvedI ^ altX]);
        if (candidates.length >= 8) break;
      }
    }

    if (orBranchMeta != null) {
      final String pname = orBranchMeta['pname'] as String;
      final int mask = orBranchMeta['mask'] as int;
      final List<String> extraConds = List<String>.from(orBranchMeta['extraConds'] as List);
      for (var altX = X! + 1; altX < 256; altX++) {
        if ((altX | mask) != altX) continue;
        var anyTriggered = false;
        for (final cond in extraConds) {
          try {
            if (evalJsCondition(cond, pname, altX)) {
              anyTriggered = true;
              break;
            }
          } catch (_) {}
        }
        if (anyTriggered) continue;
        candidates.add([altX, resolvedI ^ altX]);
        if (candidates.length >= 8) break;
      }
    }

    if ((X! | 72) == X) {
      for (final altX in [73, 74, 75, 77, 78, 79, 104, 105, 106, 107, 108, 109, 110, 111]) {
        if ((altX | 72) == altX && (altX & 92) != altX) {
          candidates.add([altX, resolvedI ^ altX]);
        }
      }
    }

    if (X! < 16) {
      for (final altX in [1, 2, 3, 5, 6, 7, 9, 10, 11, 13, 14, 15]) {
        if (altX < 16 && (altX << 1 & 6) >= 1) {
          candidates.add([altX, resolvedI ^ altX]);
        }
      }
    }

    return candidates;
  }

  // Helpers for XOR-branch nsig selector
  String _normalizeJsCond(String condStr) {
    return condStr.replaceAll(RegExp(r'\s+'), '');
  }

  List<String> _extractIfConditions(String src) {
    final List<String> conds = [];
    final regex = RegExp(r'if\s*\(');
    for (final Match match in regex.allMatches(src)) {
      final openIdx = match.end - 1;
      var depth = 1;
      int? condEnd;
      for (var i = openIdx + 1; i < src.length; i++) {
        if (src[i] == '(') {
          depth++;
        } else if (src[i] == ')') {
          depth--;
          if (depth == 0) {
            condEnd = i;
            break;
          }
        }
      }
      if (condEnd == null) continue;
      conds.add(src.substring(openIdx + 1, condEnd));
    }
    return conds;
  }

  PickResult? _pickBranchCandidate(
    String pname,
    bool Function(int) predicate,
    List<String> extraConds,
  ) {
    int? bestX;
    List<String>? bestHits;

    for (var xCandidate = 0; xCandidate < 256; xCandidate++) {
      if (!predicate(xCandidate)) continue;
      final List<String> hits = [];
      for (final cond in extraConds) {
        if (!cond.contains(pname)) continue;
        try {
          if (evalJsCondition(cond, pname, xCandidate)) {
            hits.add(cond);
          }
        } catch (_) {}
      }
      if (bestHits == null || hits.length < bestHits.length) {
        bestX = xCandidate;
        bestHits = hits;
        if (hits.isEmpty) break;
      }
    }

    if (bestX == null) return null;
    return PickResult(bestX, bestHits ?? []);
  }

  List<dynamic> _extractNsigParamVal(String code, String funcName) {
    final pattern = RegExp(
      r'(?<![A-Za-z0-9_$\.])' +
      RegExp.escape(funcName) +
      r'\[\w\[\d+\]\]\(\s*(?<arg1>[A-Za-z0-9_$]+)(?:\s*,\s*(?<arg2>[A-Za-z0-9_$]+))?(?:\s*,\s*[^)]*)?\s*\)'
    );

    final results = [];
    for (final Match m in pattern.allMatches(code)) {
      final rm = m as RegExpMatch;
      final arg1 = rm.namedGroup('arg1');
      final arg2 = rm.namedGroup('arg2');
      final chosen = (arg1 == 'this' && arg2 != null && arg2.isNotEmpty) ? arg2 : arg1;
      if (chosen != null) {
        results.add(chosen);
      }
    }
    return results;
  }

  void close() {
    _runnerSig?.close();
    _runnerSig = null;
    _runnerNsig?.close();
    _runnerNsig = null;
  }
}

class PickResult {
  final int x;
  final List<String> hits;
  PickResult(this.x, this.hits);
}

// Global JS object extraction helpers
List<String?> extractPlayerJsGlobalVar(String jscode) {
  final pattern = RegExp(
    r'''(?:["'])use\s+strict(?:["']);\s*'''
    r'''(var\s+(?<name>[a-zA-Z0-9_$]+)\s*=\s*(?<value>'''
    r'''(?:["'])(?:[^'"\\]|\\.)*(?:["'])\.split\((?:["'])(?:[^'"\\])+(?:["'])\)'''
    r'''|\[\s*(?:(?:["'])(?:[^'"\\]|\\.)*(?:["'])\s*,?\s*)+\]'''
    r'''))[;,]'''
  );
  
  final match = pattern.firstMatch(jscode);
  if (match != null) {
    final rm = match as RegExpMatch;
    return [rm.group(1), rm.namedGroup('name'), rm.namedGroup('value')];
  }
  return [null, null, null];
}

class KeyValuePair<K, V> {
  final K key;
  final V value;
  KeyValuePair(this.key, this.value);
}

KeyValuePair<String?, List<dynamic>?> _extractSplitPlayerJsGlobalVar(String js) {
  final splitPatterns = [
    RegExp(r'''([A-Za-z0-9_$]+(?:\.[A-Za-z0-9_$]+)?)\s*=\s*'((?:\\'|[^'])*)'\.split\(['"]([^'"]*)['"]\)'''),
    RegExp(r'''([A-Za-z0-9_$]+(?:\.[A-Za-z0-9_$]+)?)\s*=\s*"((?:\\"|[^"])*)"\.split\(['"]([^'"]*)['"]\)'''),
  ];

  RegExpMatch? splitMatch;
  for (final pattern in splitPatterns) {
    final m = pattern.firstMatch(js);
    if (m != null) {
      splitMatch = m as RegExpMatch;
      break;
    }
  }

  if (splitMatch == null) {
    return KeyValuePair(null, null);
  }

  final body = splitMatch.group(2)!.replaceAll(r"\'", "'").replaceAll(r'\"', '"');
  final sep = splitMatch.group(3)!;
  final List<dynamic> globalObj = sep.isNotEmpty ? body.split(sep) : body.split('');
  
  if (globalObj.any((val) => val is String && val.endsWith('_w8_'))) {
    return KeyValuePair(splitMatch.group(1)!, globalObj);
  }
  return KeyValuePair(null, null);
}

KeyValuePair<String?, List<dynamic>?> _extractPropertyArrayPlayerJsGlobalVar(String js) {
  for (final Match match in RegExp(r"([A-Za-z0-9_$]+(?:\.[A-Za-z0-9_$]+)+)\s*=\s*\[").allMatches(js)) {
    final arrayStart = match.end - 1;
    var depth = 0;
    var arrayEnd = -1;
    for (var index = arrayStart; index < js.length; index++) {
      if (js[index] == '[') {
        depth++;
      } else if (js[index] == ']') {
        depth--;
        if (depth == 0) {
          arrayEnd = index + 1;
          break;
        }
      }
    }
    if (arrayEnd == -1) continue;

    final arrayCode = js.substring(arrayStart, arrayEnd);
    if (!arrayCode.contains('_w8_')) continue;

    try {
      final globalObj = interpretSimpleJsExpression(arrayCode);
      if (globalObj is List && globalObj.any((val) => val is String && val.endsWith('_w8_'))) {
        return KeyValuePair(match.group(1)!, globalObj);
      }
    } catch (_) {}
  }
  return KeyValuePair(null, null);
}

dynamic interpretSimpleJsExpression(String code) {
  code = code.trim();
  if (code.startsWith('[') && code.endsWith(']')) {
    return json.decode(sanitizeJsObject(code));
  }
  
  final splitRegExp = RegExp(
    r'''^'((?:\\'|[^'])*)'\.split\(['"]([^'"]*)['"]\)$'''
    r'''|^"((?:\\"|[^"])*)"\.split\(['"]([^'"]*)['"]\)$'''
  );
  
  final match = splitRegExp.firstMatch(code);
  if (match != null) {
    final rm = match as RegExpMatch;
    final body = (rm.group(1) ?? rm.group(3) ?? '')
        .replaceAll(r"\'", "'")
        .replaceAll(r'\"', '"');
    final sep = rm.group(2) ?? rm.group(4) ?? '';
    return sep.isNotEmpty ? body.split(sep) : body.split('');
  }
  
  throw ArgumentError('Unsupported simple JS expression: $code');
}

// Lightweight Recursive Descent Evaluator for JS arithmetic/logical/bitwise expressions
class ExpressionParser {
  final String input;
  int pos = 0;

  ExpressionParser(this.input);

  String peek() {
    if (pos >= input.length) return '';
    return input[pos];
  }

  void skipWhitespace() {
    while (pos < input.length && (input[pos] == ' ' || input[pos] == '\t' || input[pos] == '\r' || input[pos] == '\n')) {
      pos++;
    }
  }

  int parseOr(Map<String, int> vars) {
    var val = parseAnd(vars);
    while (true) {
      skipWhitespace();
      if (peek() == '|' && pos + 1 < input.length && input[pos + 1] == '|') {
        pos += 2;
        final right = parseAnd(vars);
        val = (val != 0 || right != 0) ? 1 : 0;
      } else {
        break;
      }
    }
    return val;
  }

  int parseAnd(Map<String, int> vars) {
    var val = parseRelational(vars);
    while (true) {
      skipWhitespace();
      if (peek() == '&' && pos + 1 < input.length && input[pos + 1] == '&') {
        pos += 2;
        final right = parseRelational(vars);
        val = (val != 0 && right != 0) ? 1 : 0;
      } else {
        break;
      }
    }
    return val;
  }

  int parseRelational(Map<String, int> vars) {
    final left = parseBitwiseOr(vars);
    skipWhitespace();
    final op = _parseRelationalOp();
    if (op.isEmpty) {
      return left;
    }
    final right = parseBitwiseOr(vars);
    switch (op) {
      case '==': return left == right ? 1 : 0;
      case '===': return left == right ? 1 : 0;
      case '!=': return left != right ? 1 : 0;
      case '!==': return left != right ? 1 : 0;
      case '<': return left < right ? 1 : 0;
      case '<=': return left <= right ? 1 : 0;
      case '>': return left > right ? 1 : 0;
      case '>=': return left >= right ? 1 : 0;
      default: return 0;
    }
  }

  String _parseRelationalOp() {
    if (peek() == '=') {
      pos++;
      if (peek() == '=') {
        pos++;
        if (peek() == '=') {
          pos++;
          return '===';
        }
        return '==';
      }
      pos--;
    } else if (peek() == '!') {
      pos++;
      if (peek() == '=') {
        pos++;
        if (peek() == '=') {
          pos++;
          return '!==';
        }
        return '!=';
      }
      pos--;
    } else if (peek() == '<') {
      pos++;
      if (peek() == '=') {
        pos++;
        return '<=';
      }
      return '<';
    } else if (peek() == '>') {
      pos++;
      if (peek() == '=') {
        pos++;
        return '>=';
      }
      return '>';
    }
    return '';
  }

  int parseBitwiseOr(Map<String, int> vars) {
    var val = parseBitwiseXor(vars);
    while (true) {
      skipWhitespace();
      if (peek() == '|' && (pos + 1 >= input.length || input[pos + 1] != '|')) {
        pos++;
        final right = parseBitwiseXor(vars);
        val = val | right;
      } else {
        break;
      }
    }
    return val;
  }

  int parseBitwiseXor(Map<String, int> vars) {
    var val = parseBitwiseAnd(vars);
    while (true) {
      skipWhitespace();
      if (peek() == '^') {
        pos++;
        final right = parseBitwiseAnd(vars);
        val = val ^ right;
      } else {
        break;
      }
    }
    return val;
  }

  int parseBitwiseAnd(Map<String, int> vars) {
    var val = parseShift(vars);
    while (true) {
      skipWhitespace();
      if (peek() == '&' && (pos + 1 >= input.length || input[pos + 1] != '&')) {
        pos++;
        final right = parseShift(vars);
        val = val & right;
      } else {
        break;
      }
    }
    return val;
  }

  int parseShift(Map<String, int> vars) {
    var val = parseAdditive(vars);
    while (true) {
      skipWhitespace();
      if (peek() == '<' && pos + 1 < input.length && input[pos + 1] == '<') {
        pos += 2;
        final right = parseAdditive(vars);
        val = val << right;
      } else if (peek() == '>' && pos + 1 < input.length && input[pos + 1] == '>') {
        pos += 2;
        final right = parseAdditive(vars);
        val = val >> right;
      } else {
        break;
      }
    }
    return val;
  }

  int parseAdditive(Map<String, int> vars) {
    var val = parseMultiplicative(vars);
    while (true) {
      skipWhitespace();
      if (peek() == '+') {
        pos++;
        final right = parseMultiplicative(vars);
        val = val + right;
      } else if (peek() == '-') {
        pos++;
        final right = parseMultiplicative(vars);
        val = val - right;
      } else {
        break;
      }
    }
    return val;
  }

  int parseMultiplicative(Map<String, int> vars) {
    var val = parseUnary(vars);
    while (true) {
      skipWhitespace();
      if (peek() == '*') {
        pos++;
        final right = parseUnary(vars);
        val = val * right;
      } else if (peek() == '/') {
        pos++;
        final right = parseUnary(vars);
        val = val ~/ right;
      } else if (peek() == '%') {
        pos++;
        final right = parseUnary(vars);
        val = val % right;
      } else {
        break;
      }
    }
    return val;
  }

  int parseUnary(Map<String, int> vars) {
    skipWhitespace();
    if (peek() == '!') {
      pos++;
      return parseUnary(vars) == 0 ? 1 : 0;
    }
    if (peek() == '-') {
      pos++;
      return -parseUnary(vars);
    }
    if (peek() == '+') {
      pos++;
      return parseUnary(vars);
    }
    return parsePrimary(vars);
  }

  int parsePrimary(Map<String, int> vars) {
    skipWhitespace();
    if (peek() == '(') {
      pos++;
      final val = parseOr(vars);
      skipWhitespace();
      if (peek() == ')') {
        pos++;
      }
      return val;
    }

    if (pos < input.length && RegExp(r'[0-9]').hasMatch(input[pos])) {
      var numStr = '';
      while (pos < input.length && RegExp(r'[0-9]').hasMatch(input[pos])) {
        numStr += input[pos++];
      }
      return int.parse(numStr);
    }

    if (pos < input.length && RegExp(r'[a-zA-Z_$]').hasMatch(input[pos])) {
      var varStr = '';
      while (pos < input.length && RegExp(r'[a-zA-Z0-9_$]').hasMatch(input[pos])) {
        varStr += input[pos++];
      }
      return vars[varStr] ?? 0;
    }

    return 0;
  }
}

bool evalJsCondition(String cond, String varName, int varVal) {
  final parser = ExpressionParser(cond);
  return parser.parseOr({varName: varVal}) != 0;
}
