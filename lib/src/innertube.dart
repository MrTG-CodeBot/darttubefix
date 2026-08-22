import 'dart:convert';
import 'request.dart';

const String clientId = '861556708454-d6dlm3lh05idd8npek18k6be8ba3oc68.apps.googleusercontent.com';
const String clientSecret = 'SboVhoG9s0rNafixCSGGKXAT';

class ClientConfig {
  final Map<String, dynamic> innertubeContext;
  final Map<String, String> header;
  final String apiKey;
  final bool requireJsPlayer;
  final bool requirePoToken;

  const ClientConfig({
    required this.innertubeContext,
    required this.header,
    required this.apiKey,
    required this.requireJsPlayer,
    required this.requirePoToken,
  });
}

final Map<String, ClientConfig> defaultClients = {
  'WEB': ClientConfig(
    innertubeContext: {
      'context': {
        'client': {
          'clientName': 'WEB',
          'osName': 'Windows',
          'osVersion': '10.0',
          'clientVersion': '2.20251021.01.00',
          'platform': 'DESKTOP'
        }
      }
    },
    header: {
      'User-Agent': 'Mozilla/5.0',
      'X-Youtube-Client-Name': '1',
      'X-Youtube-Client-Version': '2.20251021.01.00'
    },
    apiKey: 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8',
    requireJsPlayer: true,
    requirePoToken: true,
  ),
  'WEB_EMBED': ClientConfig(
    innertubeContext: {
      'context': {
        'client': {
          'clientName': 'WEB_EMBEDDED_PLAYER',
          'osName': 'Windows',
          'osVersion': '10.0',
          'clientVersion': '2.20240530.02.00',
          'clientScreen': 'EMBED'
        }
      }
    },
    header: {
      'User-Agent': 'Mozilla/5.0',
      'X-Youtube-Client-Name': '56'
    },
    apiKey: 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8',
    requireJsPlayer: true,
    requirePoToken: true,
  ),
  'WEB_MUSIC': ClientConfig(
    innertubeContext: {
      'context': {
        'client': {
          'clientName': 'WEB_REMIX',
          'clientVersion': '1.20251013.03.00'
        }
      }
    },
    header: {
      'User-Agent': 'Mozilla/5.0',
      'X-Youtube-Client-Name': '67'
    },
    apiKey: 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8',
    requireJsPlayer: true,
    requirePoToken: true,
  ),
  'WEB_CREATOR': ClientConfig(
    innertubeContext: {
      'context': {
        'client': {
          'clientName': 'WEB_CREATOR',
          'clientVersion': '1.20220726.00.00'
        }
      }
    },
    header: {
      'User-Agent': 'Mozilla/5.0',
      'X-Youtube-Client-Name': '62'
    },
    apiKey: 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8',
    requireJsPlayer: true,
    requirePoToken: false,
  ),
  'WEB_SAFARI': ClientConfig(
    innertubeContext: {
      'context': {
        'client': {
          'clientName': 'WEB',
          'clientVersion': '2.20240726.00.00',
        }
      }
    },
    header: {
      'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.5 Safari/605.1.15,gzip(gfe)',
      'X-Youtube-Client-Name': '1'
    },
    apiKey: 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8',
    requireJsPlayer: true,
    requirePoToken: true,
  ),
  'MWEB': ClientConfig(
    innertubeContext: {
      'context': {
        'client': {
          'clientName': 'MWEB',
          'clientVersion': '2.20251014.06.00'
        }
      }
    },
    header: {
      'User-Agent': 'Mozilla/5.0 (iPad; CPU OS 16_7_10 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1,gzip(gfe)',
      'X-Youtube-Client-Name': '2'
    },
    apiKey: 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8',
    requireJsPlayer: true,
    requirePoToken: true,
  ),
  'WEB_KIDS': ClientConfig(
    innertubeContext: {
      'context': {
        'client': {
          'clientName': 'WEB_KIDS',
          'osName': 'Windows',
          'osVersion': '10.0',
          'clientVersion': '2.20241125.00.00',
          'platform': 'DESKTOP'
        }
      }
    },
    header: {
      'User-Agent': 'Mozilla/5.0',
      'X-Youtube-Client-Name': '76',
      'X-Youtube-Client-Version': '2.20241125.00.00'
    },
    apiKey: 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8',
    requireJsPlayer: true,
    requirePoToken: false,
  ),
  'ANDROID': ClientConfig(
    innertubeContext: {
      'context': {
        'client': {
          'clientName': 'ANDROID',
          'clientVersion': '19.44.38',
          'platform': 'MOBILE',
          'osName': 'Android',
          'osVersion': '14',
          'androidSdkVersion': '34'
        }
      }
    },
    header: {
      'User-Agent': 'com.google.android.youtube/',
      'X-Youtube-Client-Name': '3'
    },
    apiKey: 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8',
    requireJsPlayer: false,
    requirePoToken: true,
  ),
  'ANDROID_VR': ClientConfig(
    innertubeContext: {
      'context': {
        'client': {
          'clientName': 'ANDROID_VR',
          'clientVersion': '1.60.19',
          'deviceMake': 'Oculus',
          'deviceModel': 'Quest 3',
          'osName': 'Android',
          'osVersion': '12L',
          'androidSdkVersion': '32'
        }
      }
    },
    header: {
      'User-Agent': 'com.google.android.apps.youtube.vr.oculus/1.60.19 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip',
      'X-Youtube-Client-Name': '28'
    },
    apiKey: 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8',
    requireJsPlayer: false,
    requirePoToken: false,
  ),
  'ANDROID_MUSIC': ClientConfig(
    innertubeContext: {
      'context': {
        'client': {
          'clientName': 'ANDROID_MUSIC',
          'clientVersion': '7.27.52',
          'androidSdkVersion': '30',
          'osName': 'Android',
          'osVersion': '11'
        }
      }
    },
    header: {
      'User-Agent': 'com.google.android.apps.youtube.music/7.27.52 (Linux; U; Android 11) gzip',
      'X-Youtube-Client-Name': '21'
    },
    apiKey: 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8',
    requireJsPlayer: false,
    requirePoToken: false,
  ),
  'ANDROID_CREATOR': ClientConfig(
    innertubeContext: {
      'context': {
        'client': {
          'clientName': 'ANDROID_CREATOR',
          'clientVersion': '24.45.100',
          'androidSdkVersion': '30',
          'osName': 'Android',
          'osVersion': '11'
        }
      }
    },
    header: {
      'User-Agent': 'com.google.android.apps.youtube.creator/24.45.100 (Linux; U; Android 11) gzip',
      'X-Youtube-Client-Name': '14'
    },
    apiKey: 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8',
    requireJsPlayer: false,
    requirePoToken: false,
  ),
  'ANDROID_TESTSUITE': ClientConfig(
    innertubeContext: {
      'context': {
        'client': {
          'clientName': 'ANDROID_TESTSUITE',
          'clientVersion': '1.9',
          'platform': 'MOBILE',
          'osName': 'Android',
          'osVersion': '14',
          'androidSdkVersion': '34'
        }
      }
    },
    header: {
      'User-Agent': 'com.google.android.youtube/',
      'X-Youtube-Client-Name': '30',
      'X-Youtube-Client-Version': '1.9'
    },
    apiKey: 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8',
    requireJsPlayer: false,
    requirePoToken: false,
  ),
  'ANDROID_PRODUCER': ClientConfig(
    innertubeContext: {
      'context': {
        'client': {
          'clientName': 'ANDROID_PRODUCER',
          'clientVersion': '0.111.1',
          'androidSdkVersion': '30',
          'osName': 'Android',
          'osVersion': '11'
        }
      }
    },
    header: {
      'User-Agent': 'com.google.android.apps.youtube.producer/0.111.1 (Linux; U; Android 11) gzip',
      'X-Youtube-Client-Name': '91'
    },
    apiKey: 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8',
    requireJsPlayer: false,
    requirePoToken: false,
  ),
  'ANDROID_KIDS': ClientConfig(
    innertubeContext: {
      'context': {
        'client': {
          'clientName': 'ANDROID_KIDS',
          'clientVersion': '7.36.1',
          'androidSdkVersion': '30',
          'osName': 'Android',
          'osVersion': '11'
        }
      }
    },
    header: {
      'User-Agent': 'com.google.android.apps.youtube.music/7.27.52 (Linux; U; Android 11) gzip',
    },
    apiKey: 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8',
    requireJsPlayer: false,
    requirePoToken: false,
  ),
  'IOS': ClientConfig(
    innertubeContext: {
      'context': {
        'client': {
          'clientName': 'IOS',
          'clientVersion': '19.45.4',
          'deviceMake': 'Apple',
          'platform': 'MOBILE',
          'osName': 'iPhone',
          'osVersion': '18.1.0.22B83',
          'deviceModel': 'iPhone16,2'
        }
      }
    },
    header: {
      'User-Agent': 'com.google.ios.youtube/19.45.4 (iPhone16,2; U; CPU iOS 18_1_0 like Mac OS X;)',
      'X-Youtube-Client-Name': '5'
    },
    apiKey: 'AIzaSyB-63vPrdThhKuerbB2N_l7Kwwcxj6yUAc',
    requireJsPlayer: false,
    requirePoToken: false,
  ),
  'IOS_MUSIC': ClientConfig(
    innertubeContext: {
      'context': {
        'client': {
          'clientName': 'IOS_MUSIC',
          'clientVersion': '7.27.0',
          'deviceMake': 'Apple',
          'platform': 'MOBILE',
          'osName': 'iPhone',
          'osVersion': '18.1.0.22B83',
          'deviceModel': 'iPhone16,2'
        }
      }
    },
    header: {
      'User-Agent': 'com.google.ios.youtubemusic/7.27.0 (iPhone16,2; U; CPU iOS 18_1_0 like Mac OS X;)',
      'X-Youtube-Client-Name': '26'
    },
    apiKey: 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8',
    requireJsPlayer: false,
    requirePoToken: false,
  ),
  'IOS_CREATOR': ClientConfig(
    innertubeContext: {
      'context': {
        'client': {
          'clientName': 'IOS_CREATOR',
          'clientVersion': '24.45.100',
          'deviceMake': 'Apple',
          'deviceModel': 'iPhone16,2',
          'osName': 'iPhone',
          'osVersion': '18.1.0.22B83'
        }
      }
    },
    header: {
      'User-Agent': 'com.google.ios.ytcreator/24.45.100 (iPhone16,2; U; CPU iOS 18_1_0 like Mac OS X;)',
      'X-Youtube-Client-Name': '15'
    },
    apiKey: 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8',
    requireJsPlayer: false,
    requirePoToken: false,
  ),
  'IOS_KIDS': ClientConfig(
    innertubeContext: {
      'context': {
        'client': {
          'clientName': 'IOS_KIDS',
          'clientVersion': '7.36.1',
          'deviceMake': 'Apple',
          'platform': 'MOBILE',
          'osName': 'iPhone',
          'osVersion': '18.1.0.22B83',
          'deviceModel': 'iPhone16,2'
        }
      }
    },
    header: {
      'User-Agent': 'com.google.ios.youtube/19.45.4 (iPhone16,2; U; CPU iOS 18_1_0 like Mac OS X;)',
    },
    apiKey: 'AIzaSyB-63vPrdThhKuerbB2N_l7Kwwcxj6yUAc',
    requireJsPlayer: false,
    requirePoToken: false,
  ),
  'TV': ClientConfig(
    innertubeContext: {
      'context': {
        'client': {
          'clientName': 'TVHTML5',
          'clientVersion': '7.20240813.07.00',
          'platform': 'TV'
        }
      }
    },
    header: {
      'User-Agent': 'Mozilla/5.0',
      'X-Youtube-Client-Name': '7'
    },
    apiKey: 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8',
    requireJsPlayer: true,
    requirePoToken: false,
  ),
  'TV_EMBED': ClientConfig(
    innertubeContext: {
      'context': {
        'client': {
          'clientName': 'TVHTML5_SIMPLY_EMBEDDED_PLAYER',
          'clientVersion': '2.0',
          'clientScreen': 'EMBED',
          'platform': 'TV'
        }
      }
    },
    header: {
      'User-Agent': 'Mozilla/5.0',
      'X-Youtube-Client-Name': '85'
    },
    apiKey: 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8',
    requireJsPlayer: true,
    requirePoToken: false,
  ),
  'MEDIA_CONNECT': ClientConfig(
    innertubeContext: {
      'context': {
        'client': {
          'clientName': 'MEDIA_CONNECT_FRONTEND',
          'clientVersion': '0.1'
        }
      }
    },
    header: {
      'User-Agent': 'Mozilla/5.0',
      'X-Youtube-Client-Name': '95'
    },
    apiKey: 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8',
    requireJsPlayer: false,
    requirePoToken: false,
  )
};

class InnerTube {
  final String clientName;
  late final Map<String, dynamic> innertubeContext;
  late final Map<String, String> header;
  late final String apiKey;
  late final bool requireJsPlayer;
  late final bool requirePoToken;

  String? accessToken;
  String? refreshToken;
  int? expires;

  String? accessPoToken;
  String? accessVisitorData;

  final bool useOauth;
  final bool allowCache;
  final bool usePoToken;

  InnerTube({
    this.clientName = 'ANDROID_VR',
    this.useOauth = false,
    this.allowCache = true,
    this.usePoToken = false,
  }) {
    final clientKey = clientName == 'TVHTML5' ? 'TV' : (clientName == 'WEB_REMIX' ? 'WEB_MUSIC' : clientName);
    final config = defaultClients[clientKey];
    if (config == null) {
      throw ArgumentError('Unknown InnerTube client name: $clientName');
    }
    innertubeContext = json.decode(json.encode(config.innertubeContext));
    header = Map.from(config.header);
    apiKey = config.apiKey;
    requireJsPlayer = config.requireJsPlayer;
    requirePoToken = config.requirePoToken;
  }

  void insertVisitorData(String visitorData) {
    final client = innertubeContext['context']?['client'] as Map<String, dynamic>? ?? {};
    client['visitorData'] = visitorData;
    innertubeContext['context']?['client'] = client;
  }

  void insertPoToken(String visitorData, String poToken) {
    insertVisitorData(visitorData);
    innertubeContext['serviceIntegrityDimensions'] = {
      'poToken': poToken,
    };
  }

  String get baseUrl => 'https://www.youtube.com/youtubei/v1';

  Future<Map<String, dynamic>> _callApi(String endpoint, Map<String, dynamic> data) async {
    final url = '$baseUrl/$endpoint?key=$apiKey&prettyPrint=false';
    final responseStr = await postRequest(url, extraHeaders: header, data: data);
    return json.decode(responseStr);
  }

  Future<Map<String, dynamic>> player(String videoId) async {
    final data = Map<String, dynamic>.from(innertubeContext);
    data['videoId'] = videoId;
    // playbackContext is updated by YouTube.signatureTimestamp if needed in the caller
    return _callApi('player', data);
  }

  Future<Map<String, dynamic>> next(String videoId) async {
    final data = Map<String, dynamic>.from(innertubeContext);
    data['videoId'] = videoId;
    return _callApi('next', data);
  }

  Future<Map<String, dynamic>> browse(String browseId, {String? params}) async {
    final data = Map<String, dynamic>.from(innertubeContext);
    data['browseId'] = browseId;
    if (params != null) {
      data['params'] = params;
    }
    return _callApi('browse', data);
  }

  Future<Map<String, dynamic>> verifyAge(String videoId) async {
    final data = Map<String, dynamic>.from(innertubeContext);
    data['videoId'] = videoId;
    return _callApi('playability/verify_age', data);
  }

  Future<Map<String, dynamic>> search(String query, {String? continuation}) async {
    final data = Map<String, dynamic>.from(innertubeContext);
    if (continuation != null) {
      data['continuation'] = continuation;
    } else {
      data['query'] = query;
    }
    return _callApi('search', data);
  }
}
