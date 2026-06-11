import 'exceptions.dart';

String regexSearch(String pattern, String string, int group) {
  final regex = RegExp(pattern, multiLine: true, dotAll: true);
  final match = regex.firstMatch(string);
  if (match == null) {
    throw RegexMatchError("regexSearch", pattern);
  }

  // If group is 0, return the full match.
  if (group == 0) {
    return match.group(0) ?? '';
  }

  if (group <= match.groupCount) {
    return match.group(group) ?? '';
  }

  throw RegexMatchError("regexSearch", "$pattern (group $group out of bounds)");
}

String safeFilename(String s, {int maxLength = 255}) {
  // NTFS invalid characters: ASCII 0-31 plus special chars
  final List<String> ntfsCharacters = List.generate(31, (i) => String.fromCharCode(i));
  final List<String> characters = [
    '"', '#', r'\$', '%', "'", r'\*', ',', r'\.', r'\/', r'\:', ';', r'\<', r'\>', r'\?', r'\\', r'\^', r'\|', r'\~'
  ];
  
  final pattern = [
    ...ntfsCharacters.map((c) => RegExp.escape(c)),
    ...characters
  ].join('|');

  final regex = RegExp(pattern, unicode: true);
  var filename = s.replaceAll(regex, "");
  if (filename.length > maxLength) {
    filename = filename.substring(0, maxLength);
  }
  return filename;
}

List<T> uniqueify<T>(List<T> dupedList) {
  final result = <T>[];
  for (final item in dupedList) {
    if (result.contains(item)) {
      continue;
    }
    result.add(item);
  }
  return result;
}
