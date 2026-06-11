import 'dart:convert';
import 'exceptions.dart';

List<dynamic> parseForAllObjects(String html, String precedingRegex) {
  final List<dynamic> result = [];
  final regex = RegExp(precedingRegex);
  final matches = regex.allMatches(html);
  
  for (final match in matches) {
    final startIndex = match.end;
    try {
      final obj = parseForObjectFromStartpoint(html, startIndex);
      result.add(obj);
    } catch (_) {
      // Skip failed parses, similar to pytubefix
      continue;
    }
  }

  if (result.isEmpty) {
    throw HTMLParseError('No matches for regex $precedingRegex');
  }

  return result;
}

dynamic parseForObject(String html, String precedingRegex) {
  final regex = RegExp(precedingRegex);
  final match = regex.firstMatch(html);
  if (match == null) {
    throw HTMLParseError('No matches for regex $precedingRegex');
  }

  final startIndex = match.end;
  return parseForObjectFromStartpoint(html, startIndex);
}

String findObjectFromStartpoint(String html, int startPoint) {
  final targetHtml = html.substring(startPoint);
  if (targetHtml.isEmpty || (targetHtml[0] != '{' && targetHtml[0] != '[')) {
    throw HTMLParseError('Invalid start point. Start of HTML:\n${targetHtml.take(20)}');
  }

  var lastChar = '{';
  String? currChar;
  final List<String> stack = [targetHtml[0]];
  var i = 1;

  final Map<String, String> contextClosers = {
    '{': '}',
    '[': ']',
    '"': '"',
    "'": "'",
    '/': '/' // JavaScript regex
  };

  while (i < targetHtml.length) {
    if (stack.isEmpty) {
      break;
    }
    if (currChar != ' ' && currChar != '\n') {
      lastChar = currChar ?? '{';
    }
    currChar = targetHtml[i];
    final currContext = stack.last;

    // If we've reached a context closer, remove an element from stack
    if (currChar == contextClosers[currContext]) {
      stack.removeLast();
      i += 1;
      continue;
    }

    // Strings and regex expressions require special context handling
    if (currContext == '"' || currContext == "'" || currContext == '/') {
      if (currChar == '\\') {
        i += 2;
        continue;
      }
    } else {
      // Non-string contexts are when we look for context openers
      if (contextClosers.containsKey(currChar)) {
        // Slash starts a regex depending on context
        if (!(currChar == '/' && !['(', ',', '=', ':', '[', '!', '&', '|', '?', '{', '}', ';'].contains(lastChar))) {
          stack.add(currChar);
        }
      }
    }

    i += 1;
  }

  return targetHtml.substring(0, i);
}

dynamic parseForObjectFromStartpoint(String html, int startPoint) {
  final fullObj = findObjectFromStartpoint(html, startPoint);
  try {
    return json.decode(fullObj);
  } catch (_) {
    try {
      final sanitized = sanitizeJsObject(fullObj);
      return json.decode(sanitized);
    } catch (e) {
      throw HTMLParseError('Could not parse object: $e');
    }
  }
}

String sanitizeJsObject(String jsObj) {
  // Protect and normalize string literals first
  final List<String> strings = [];
  final regexString = RegExp(r'"(?:[^"\\]|\\.)*"|' "'" r"(?:[^'\\]|\\.)*'" r"|`(?:[^`\\]|\\.)*`" );
  
  var s = jsObj.replaceAllMapped(regexString, (match) {
    final str = match.group(0)!;
    var normalized = str;
    if (str.startsWith("'") && str.endsWith("'")) {
      var content = str.substring(1, str.length - 1);
      content = content.replaceAll(r'\"', '"').replaceAll('"', r'\"');
      normalized = '"$content"';
    } else if (str.startsWith('`') && str.endsWith('`')) {
      var content = str.substring(1, str.length - 1);
      content = content.replaceAll(r'\"', '"').replaceAll('"', r'\"');
      normalized = '"$content"';
    }
    strings.add(normalized);
    return '___STR_PLACEHOLDER_${strings.length - 1}___';
  });

  // Remove comments
  s = s.replaceAll(RegExp(r'\/\*[\s\S]*?\*\/|\/\/[^\n]*'), '');

  // Quote unquoted keys
  s = s.replaceAllMapped(RegExp(r'\b([a-zA-Z_$][a-zA-Z0-9_$]*)\s*:'), (match) {
    final key = match.group(1)!;
    return '"$key":';
  });

  // Remove trailing commas in objects and arrays
  s = s.replaceAll(RegExp(r',\s*\}'), '}');
  s = s.replaceAll(RegExp(r',\s*\]'), ']');

  // Convert undefined to null
  s = s.replaceAll(RegExp(r'\bundefined\b|\bvoid\s+0\b'), 'null');

  // Restore string placeholders
  for (var i = 0; i < strings.length; i++) {
    s = s.replaceFirst('___STR_PLACEHOLDER_${i}___', strings[i]);
  }

  return s;
}

List<String> throttlingArraySplit(String jsArray) {
  final List<String> results = [];
  var currSubstring = jsArray.substring(1);

  final commaRegex = RegExp(r",");
  final funcRegex = RegExp(r"function\([^)]*\)");

  while (currSubstring.isNotEmpty) {
    if (currSubstring.startsWith('function')) {
      final match = funcRegex.firstMatch(currSubstring);
      if (match == null) break;
      final matchEnd = match.end;

      final functionText = findObjectFromStartpoint(currSubstring, matchEnd);
      final fullFunctionDef = currSubstring.substring(0, matchEnd + functionText.length);
      results.add(fullFunctionDef);
      currSubstring = currSubstring.substring(fullFunctionDef.length + (currSubstring.length > fullFunctionDef.length ? 1 : 0));
    } else {
      final match = commaRegex.firstMatch(currSubstring);
      int matchStart;
      int matchEnd;
      if (match != null) {
        matchStart = match.start;
        matchEnd = match.end;
      } else {
        matchStart = currSubstring.length - 1;
        matchEnd = matchStart + 1;
      }

      final currEl = currSubstring.substring(0, matchStart);
      results.add(currEl);
      currSubstring = currSubstring.substring(matchEnd);
    }
  }

  return results;
}

extension StringTake on String {
  String take(int n) {
    return length <= n ? this : substring(0, n);
  }
}
