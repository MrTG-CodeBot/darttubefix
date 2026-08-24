import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_js/flutter_js.dart';
import 'package:path/path.dart' as p;

class NodeRunnerError implements Exception {
  final String message;
  NodeRunnerError(this.message);
  @override
  String toString() => "NodeRunnerError: $message";
}

class NodeRunnerEmptyResponseError extends NodeRunnerError {
  NodeRunnerEmptyResponseError(super.message);
}

class NodeRunnerUndefinedResponseError extends NodeRunnerError {
  NodeRunnerUndefinedResponseError(super.message);
}

class NodeRunnerInvalidResponseError extends NodeRunnerError {
  NodeRunnerInvalidResponseError(super.message);
}

class NodeRunner {
  final String code;
  String? functionName;
  Process? _process;
  StreamSubscription? _stdoutSub;
  final List<Completer<String>> _completerQueue = [];

  JavascriptRuntime? _flutterJsRuntime;
  bool _usingFlutterJs = false;

  NodeRunner(this.code);

  Future<void> init() async {
    await _startProcess();
  }

  bool get isRunning => _process != null || _flutterJsRuntime != null;

  Future<void> _startProcess() async {
    final runnerPath = _findRunnerJsPath();
    try {
      _process = await Process.start('node', [runnerPath]);
      _usingFlutterJs = false;
      _setupStdout();
    } catch (e) {
      // Node.js process failed to start (e.g. mobile environment or Node.js not installed)
      // Fallback to embedded native JS engine via flutter_js
      try {
        _flutterJsRuntime = getJavascriptRuntime();
        _usingFlutterJs = true;
      } catch (flutterJsError) {
        throw NodeRunnerError(
          "Failed to start Node.js process and flutter_js runtime is unavailable. Error: $e"
        );
      }
    }
  }

  void _setupStdout() {
    if (_process == null) return;
    final lines = _process!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    _stdoutSub = lines.listen((line) {
      if (_completerQueue.isNotEmpty) {
        final completer = _completerQueue.removeAt(0);
        completer.complete(line);
      }
    }, onError: (err) {
      if (_completerQueue.isNotEmpty) {
        final completer = _completerQueue.removeAt(0);
        completer.completeError(err);
      }
    }, onDone: () {
      if (_completerQueue.isNotEmpty) {
        final completer = _completerQueue.removeAt(0);
        completer.completeError(NodeRunnerEmptyResponseError("Node runner returned EOF"));
      }
    });
  }

  String _findRunnerJsPath() {
    // Try 1: Relative to Platform.script
    try {
      final scriptFile = File(Platform.script.toFilePath());
      var dir = scriptFile.parent;
      while (dir.path != dir.parent.path) {
        final possible = File(p.join(dir.path, 'lib', 'src', 'sig_nsig', 'vm', 'runner.js'));
        if (possible.existsSync()) {
          return possible.path;
        }
        final possibleDirect = File(p.join(dir.path, 'src', 'sig_nsig', 'vm', 'runner.js'));
        if (possibleDirect.existsSync()) {
          return possibleDirect.path;
        }
        dir = dir.parent;
      }
    } catch (_) {}

    // Try 2: Relative to Directory.current
    try {
      var dir = Directory.current;
      while (dir.path != dir.parent.path) {
        final possible = File(p.join(dir.path, 'lib', 'src', 'sig_nsig', 'vm', 'runner.js'));
        if (possible.existsSync()) {
          return possible.path;
        }
        final possibleDirect = File(p.join(dir.path, 'src', 'sig_nsig', 'vm', 'runner.js'));
        if (possibleDirect.existsSync()) {
          return possibleDirect.path;
        }
        dir = dir.parent;
      }
    } catch (_) {}

    // Fallback: expect it in the current directory structure
    return "lib/src/sig_nsig/vm/runner.js";
  }

  static String _exposed(String code, String funName) {
    final exposed = "_exposed['$funName']=$funName;})(_yt_player);";
    return code.replaceFirst("})(_yt_player);", exposed);
  }

  Future<void> restart() async {
    final name = functionName;
    close();
    await _startProcess();
    if (name != null) {
      await loadFunction(name);
    }
  }

  Future<dynamic> _send(Map<String, dynamic> data) async {
    if (_process == null && !_usingFlutterJs) {
      await _startProcess();
    }
    
    final completer = Completer<String>();
    _completerQueue.add(completer);
    
    _process!.stdin.write(json.encode(data) + "\n");
    await _process!.stdin.flush();
    
    final rawLine = await completer.future;
    final line = rawLine.trim();
    if (line.isEmpty) {
      throw NodeRunnerEmptyResponseError("Node runner returned a blank line");
    }
    if (line == "undefined") {
      throw NodeRunnerUndefinedResponseError("Node runner returned undefined");
    }
    
    try {
      return json.decode(line);
    } catch (e) {
      throw NodeRunnerInvalidResponseError("Node runner returned non-JSON output: $line");
    }
  }

  Future<dynamic> loadFunction(String funcName) async {
    functionName = funcName;
    if (_usingFlutterJs) {
      _flutterJsRuntime!.evaluate("var _exposed = _exposed || {}; var window = globalThis; var document = document || {};");
      final exposedCode = _exposed(code, funcName);
      final evalResult = _flutterJsRuntime!.evaluate(exposedCode);
      if (evalResult.isError) {
        _flutterJsRuntime!.evaluate(code);
      }
      return {"status": "ok"};
    }
    return _send({
      "type": "load",
      "code": _exposed(code, funcName)
    });
  }

  Future<dynamic> call(List<dynamic> args) async {
    if (_usingFlutterJs) {
      final formattedArgs = args.map((a) => json.encode(a)).join(',');
      final expr = "JSON.stringify((typeof _exposed !== 'undefined' && _exposed['$functionName']) ? _exposed['$functionName']($formattedArgs) : (typeof $functionName !== 'undefined' ? $functionName($formattedArgs) : undefined))";
      final result = _flutterJsRuntime!.evaluate(expr);
      if (result.isError) {
        throw NodeRunnerError("flutter_js evaluation error: ${result.stringResult}");
      }
      final raw = result.stringResult.trim();
      if (raw.isEmpty || raw == "undefined" || raw == "null") {
        throw NodeRunnerUndefinedResponseError("flutter_js returned undefined");
      }
      try {
        return json.decode(raw);
      } catch (e) {
        return raw;
      }
    }
    return _send({
      "type": "call",
      "fun": functionName,
      "args": args
    });
  }

  void close() {
    _stdoutSub?.cancel();
    _stdoutSub = null;
    _process?.kill();
    _process = null;
    _flutterJsRuntime?.dispose();
    _flutterJsRuntime = null;
    _usingFlutterJs = false;
    for (final completer in _completerQueue) {
      if (!completer.isCompleted) {
        completer.completeError(NodeRunnerError("Process closed"));
      }
    }
    _completerQueue.clear();
  }
}

