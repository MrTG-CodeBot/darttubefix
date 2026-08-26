import 'exceptions.dart';
import 'helpers.dart';
import 'parser.dart';
import 'cipher.dart';

DateTime? publishDate(String watchHtml) {
  try {
    final regex = RegExp(r'itemprop="datePublished" content="([^"]+)"');
    final match = regex.firstMatch(watchHtml);
    if (match != null) {
      final dateStr = match.group(1);
      if (dateStr != null) {
        return DateTime.tryParse(dateStr);
      }
    }
  } catch (_) {}
  return null;
}

bool recordingAvailable(String watchHtml) {
  final unavailableStrings = [
    'This live stream recording is not available.'
  ];
  for (final string in unavailableStrings) {
    if (watchHtml.contains(string)) {
      return false;
    }
  }
  return true;
}

bool isPrivate(String watchHtml) {
  final privateStrings = [
    "This is a private video. Please sign in to verify that you may see it.",
    '"simpleText":"Private video"',
    "This video is private."
  ];
  for (final string in privateStrings) {
    if (watchHtml.contains(string)) {
      return true;
    }
  }
  return false;
}

bool isAgeRestricted(String watchHtml) {
  return watchHtml.contains("og:restrictions:age");
}



List<dynamic> playabilityStatus(Map<String, dynamic> playerResponse) {
  final statusDict = playerResponse['playabilityStatus'] as Map<String, dynamic>? ?? {};
  
  if (playerResponse.containsKey('videoDetails')) {
    final videoDetails = playerResponse['videoDetails'] as Map<String, dynamic>? ?? {};
    if (videoDetails['isLive'] == true) {
      return ['LIVE_STREAM', ['Video is a live stream.']];
    }
  }

  if (statusDict.containsKey('status')) {
    final status = statusDict['status'] as String;
    if (statusDict.containsKey('reason')) {
      return [status, [statusDict['reason']]];
    }
    if (statusDict.containsKey('messages')) {
      return [status, List<String>.from(statusDict['messages'])];
    }
  }
  return [null, [null]];
}

String signatureTimestamp(String js) {
  final patterns = [
    r"signatureTimestamp:(\d+)",
    r"sts:(\d+)",
    r"signatureTimestamp\s*:\s*(\d+)",
    r"sts\s*:\s*(\d+)"
  ];
  for (final pattern in patterns) {
    try {
      final res = regexSearch(pattern, js, 1);
      if (res.isNotEmpty) return res;
    } catch (_) {}
  }
  throw RegexMatchError("signatureTimestamp", "patterns");
}

String visitorData(String responseContext) {
  return regexSearch(
    r'''visitor_data[',"\s]+value['"]:\s?['"]([a-zA-Z0-9_%-]+)['"]''',
    responseContext,
    1,
  );
}

String videoId(String url) {
  final trimmed = url.trim();
  if (RegExp(r'^[0-9A-Za-z_-]{11}$').hasMatch(trimmed)) {
    return trimmed;
  }
  return regexSearch(r"(?:v=|\/)([0-9A-Za-z_-]{11}).*", trimmed, 1);
}

String playlistId(String url) {
  final uri = Uri.parse(url);
  final listParam = uri.queryParameters['list'];
  if (listParam != null) {
    return listParam;
  }
  throw ArgumentError('No list query parameter in URL');
}

String channelName(String url) {
  final patterns = [
    r"(?:\/(c)\/([%\d\w_\-]+)(\/.*)?)",
    r"(?:\/(channel)\/([%\w\d_\-]+)(\/.*)?)",
    r"(?:\/(u)\/([%\d\w_\-]+)(\/.*)?)",
    r"(?:\/(user)\/([%\w\d_\-]+)(\/.*)?)",
    r"(?:\/(\@)([%\d\w_\-\.]+)(\/.*)?)"
  ];
  for (final pattern in patterns) {
    final regex = RegExp(pattern);
    final match = regex.firstMatch(url);
    if (match != null) {
      final uriStyle = match.group(1);
      final uriIdentifier = match.group(2);
      if (uriStyle != '@') {
        return '/$uriStyle/$uriIdentifier';
      } else {
        return '/$uriStyle$uriIdentifier';
      }
    }
  }
  throw RegexMatchError("channelName", "patterns");
}

String jsUrl(String html) {
  String baseJs;
  try {
    baseJs = getYtplayerConfig(html)['assets']['js'] as String;
  } catch (_) {
    baseJs = getYtplayerJs(html);
  }
  return "https://www.youtube.com$baseJs";
}

List<dynamic> mimeTypeCodec(String mimeTypeCodecStr) {
  final pattern = r'(\w+\/\w+)\;\scodecs="([a-zA-Z-0-9.,\s]*)"';
  final regex = RegExp(pattern);
  final match = regex.firstMatch(mimeTypeCodecStr);
  if (match == null) {
    throw RegexMatchError("mimeTypeCodec", pattern);
  }
  final mimeType = match.group(1)!;
  final codecsStr = match.group(2)!;
  final codecs = codecsStr.split(",").map((c) => c.trim()).toList();
  return [mimeType, codecs];
}

String getYtplayerJs(String html) {
  final jsUrlPatterns = [
    r'''(/s/player/[^'"\s]+/base\.js)''',
    r'''(/s/player/[\w\d]+/[\w\d_/.]+/base\.js)'''
  ];
  for (final pattern in jsUrlPatterns) {
    final regex = RegExp(pattern);
    final match = regex.firstMatch(html);
    if (match != null) {
      return match.group(1)!;
    }
  }
  throw RegexMatchError("getYtplayerJs", "jsUrlPatterns");
}

Map<String, dynamic> getYtplayerConfig(String html) {
  final configPatterns = [
    r"ytplayer\.config\s*=\s*",
    r"ytInitialPlayerResponse\s*=\s*"
  ];
  for (final pattern in configPatterns) {
    try {
      return parseForObject(html, pattern) as Map<String, dynamic>;
    } catch (_) {
      continue;
    }
  }

  final setconfigPatterns = [
    r'''yt\.setConfig\(.*['"]PLAYER_CONFIG['"]:\s*'''
  ];
  for (final pattern in setconfigPatterns) {
    try {
      return parseForObject(html, pattern) as Map<String, dynamic>;
    } catch (_) {
      continue;
    }
  }

  throw RegexMatchError("getYtplayerConfig", "configPatterns, setconfigPatterns");
}

Map<String, dynamic> getYtcfg(String html) {
  final Map<String, dynamic> ytcfg = {};
  final ytcfgPatterns = [
    r"ytcfg\s=\s",
    r"ytcfg\.set\("
  ];
  for (final pattern in ytcfgPatterns) {
    try {
      final foundObjects = parseForAllObjects(html, pattern);
      for (final obj in foundObjects) {
        if (obj is Map<String, dynamic>) {
          ytcfg.addAll(obj);
        }
      }
    } catch (_) {
      continue;
    }
  }

  if (ytcfg.isNotEmpty) {
    return ytcfg;
  }

  throw RegexMatchError("getYtcfg", "ytcfgPatterns");
}

void applyPoToken(List<Map<String, dynamic>> streamManifest, Map<String, dynamic> vidInfo, String poToken) {
  for (var i = 0; i < streamManifest.length; i++) {
    final stream = streamManifest[i];
    String? url = stream["url"];
    if (url == null) {
      final liveStream = vidInfo['playabilityStatus']?['liveStreamability'];
      if (liveStream != null) {
        throw LiveStreamError("UNKNOWN");
      }
      continue;
    }

    final uri = Uri.parse(url);
    final queryParams = Map<String, String>.from(uri.queryParameters);
    queryParams['pot'] = poToken;
    
    final newUri = uri.replace(queryParameters: queryParams);
    streamManifest[i]["url"] = newUri.toString();
  }
}

Future<void> applySignature(
  List<Map<String, dynamic>> streamManifest,
  Map<String, dynamic> vidInfo,
  String js,
  String urlJs,
) async {
  final cipher = Cipher(js: js, jsUrl: urlJs);
  try {
    final Map<String, String> discoveredN = {};
    for (var i = 0; i < streamManifest.length; i++) {
      final stream = streamManifest[i];
      String? url = stream["url"];
      if (url == null) {
        final liveStream = vidInfo['playabilityStatus']?['liveStreamability'];
        if (liveStream != null) {
          throw LiveStreamError("UNKNOWN");
        }
        continue;
      }

      final uri = Uri.parse(url);
      final queryParams = Map<String, String>.from(uri.queryParameters);

      // 403 Forbidden fix.
      if (url.contains("signature") || 
          (!stream.containsKey("s") && (url.contains("&sig=") || url.contains("&lsig=")))) {
        // Pre-signed
      } else {
        final s = stream["s"] as String;
        final signature = await cipher.getSig(s);
        final spKey = stream["sp"] as String? ?? "sig";
        queryParams[spKey] = signature;
      }

      final initialN = queryParams['n'] ?? stream['n'] as String?;
      if (initialN != null && initialN.isNotEmpty) {
        if (!discoveredN.containsKey(initialN)) {
          discoveredN[initialN] = await cipher.getNsig(initialN);
        }
        queryParams['n'] = discoveredN[initialN]!;
      }

      final newUri = uri.replace(queryParameters: queryParams);
      streamManifest[i]["url"] = newUri.toString();
    }
  } finally {
    cipher.close();
  }
}

List<Map<String, dynamic>>? applyDescrambler(Map<String, dynamic> streamData) {
  if (streamData.containsKey('url')) {
    return null;
  }

  final List<Map<String, dynamic>> formats = [];
  if (streamData.containsKey('formats')) {
    final list = streamData['formats'] as List;
    formats.addAll(list.map((e) => Map<String, dynamic>.from(e)));
  }
  if (streamData.containsKey('adaptiveFormats')) {
    final list = streamData['adaptiveFormats'] as List;
    formats.addAll(list.map((e) => Map<String, dynamic>.from(e)));
  }

  for (var i = 0; i < formats.length; i++) {
    final data = formats[i];
    if (!data.containsKey('url') && data.containsKey('signatureCipher')) {
      final cipherUrlStr = data['signatureCipher'] as String;
      final cipherUri = Uri.parse('http://dummy.com?$cipherUrlStr');
      final cipherUrl = cipherUri.queryParameters;
      
      data['url'] = cipherUrl['url'];
      data['s'] = cipherUrl['s'];
      data['sp'] = cipherUrl['sp'] ?? 'sig';
      if (cipherUrl.containsKey('n')) {
        data['n'] = cipherUrl['n'];
      }
      data['is_sabr'] = false;
    } else if (!data.containsKey('url') && !data.containsKey('signatureCipher')) {
      data['url'] = streamData['serverAbrStreamingUrl'];
      data['is_sabr'] = true;
    }
    data['is_otf'] = data['type'] == 'FORMAT_STREAM_TYPE_OTF';
  }

  return formats;
}

Map<String, dynamic> initialData(String watchHtml) {
  final patterns = [
    r'''window\[['"]ytInitialData['"]]\s*=\s*''',
    r"ytInitialData\s*=\s*"
  ];
  for (final pattern in patterns) {
    try {
      return parseForObject(watchHtml, pattern) as Map<String, dynamic>;
    } catch (_) {
      continue;
    }
  }
  throw RegexMatchError("initialData", "initial_data_pattern");
}

Map<String, dynamic> initialPlayerResponse(String watchHtml) {
  final patterns = [
    r'''window\[['"]ytInitialPlayerResponse['"]]\s*=\s*''',
    r"ytInitialPlayerResponse\s*=\s*"
  ];
  for (final pattern in patterns) {
    try {
      return parseForObject(watchHtml, pattern) as Map<String, dynamic>;
    } catch (_) {
      continue;
    }
  }
  throw RegexMatchError("initialPlayerResponse", "initial_player_response_pattern");
}
