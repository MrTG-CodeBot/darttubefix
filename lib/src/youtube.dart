import 'extract.dart' as extract;
import 'request.dart';
import 'exceptions.dart';
import 'innertube.dart';
import 'stream.dart';
import 'query.dart';
import 'monostate.dart';
import 'related.dart';

class YouTube {
  final String url;
  late final String videoId;
  late final String watchUrl;
  late final String embedUrl;

  String client;
  final List<String> fallbackClients = ['WEB_MUSIC', 'WEB', 'IOS', 'ANDROID_VR'];

  String? _watchHtml;
  String? _embedHtml;
  bool? _ageRestricted;
  String? _jsUrl;
  String? _js;

  Map<String, dynamic>? _vidInfo;
  Map<String, dynamic>? _vidDetails;
  List<Stream>? _fmtStreams;
  Map<String, dynamic>? _initialData;
  String? _visitorData;

  late final Monostate streamMonostate;
  String? poToken;

  YouTube(
    this.url, {
    this.client = 'MWEB',
    Function? onProgressCallback,
    Function? onCompleteCallback,
    this.poToken,
  }) {
    videoId = extract.videoId(url);
    watchUrl = "https://www.youtube.com/watch?v=$videoId";
    embedUrl = "https://www.youtube.com/embed/$videoId";

    streamMonostate = Monostate(
      onProgress: onProgressCallback,
      onComplete: onCompleteCallback,
    );
  }

  Future<String> get watchHtml async {
    if (_watchHtml != null) return _watchHtml!;
    _watchHtml = await getRequest(watchUrl);
    return _watchHtml!;
  }

  Future<String> get embedHtml async {
    if (_embedHtml != null) return _embedHtml!;
    _embedHtml = await getRequest(embedUrl);
    return _embedHtml!;
  }

  Future<bool> get ageRestricted async {
    if (_ageRestricted != null) return _ageRestricted!;
    try {
      final html = await watchHtml;
      if (html.contains("recaptcha")) {
        _ageRestricted = false;
      } else {
        _ageRestricted = extract.isAgeRestricted(html);
      }
    } catch (_) {
      _ageRestricted = false;
    }
    return _ageRestricted!;
  }

  Future<String> get jsUrl async {
    if (_jsUrl != null) return _jsUrl!;
    
    // Check if watchHtml is available and doesn't contain recaptcha
    if (!(await ageRestricted)) {
      try {
        final html = await watchHtml;
        if (!html.contains("recaptcha")) {
          _jsUrl = extract.jsUrl(html);
          if (_jsUrl != null && _jsUrl!.contains('player_embed_tce')) {
            _jsUrl = 'https://www.youtube.com/s/player/2574220e/player_embed.vflset/en_US/base.js';
          }
          return _jsUrl!;
        }
      } catch (_) {
        // ignore and fallback
      }
    }
    
    // Fallback: extract from embedHtml which is rarely blocked
    try {
      final html = await embedHtml;
      _jsUrl = extract.jsUrl(html);
      if (_jsUrl != null && _jsUrl!.contains('player_embed_tce')) {
        _jsUrl = 'https://www.youtube.com/s/player/2574220e/player_embed.vflset/en_US/base.js';
      }
    } catch (e) {
      throw ExtractError("Could not extract player js URL from watch or embed HTML: $e");
    }
    return _jsUrl!;
  }

  Future<String> get js async {
    if (_js != null) return _js!;
    _js = await getRequest(await jsUrl);
    return _js!;
  }

  Future<Map<String, dynamic>> get initialData async {
    if (_initialData != null) return _initialData!;
    final html = await watchHtml;
    _initialData = extract.initialData(html);
    return _initialData!;
  }

  Future<String> get visitorData async {
    if (_visitorData != null) return _visitorData!;

    final innerTube = InnerTube(clientName: client);
    if (innerTube.requirePoToken) {
      try {
        final initial = await initialData;
        final responseContext = initial['responseContext']?.toString() ?? '';
        _visitorData = extract.visitorData(responseContext);
        if (_visitorData != null && _visitorData!.isNotEmpty) {
          return _visitorData!;
        }
      } catch (_) {
        // ignore and fallback
      }
    }

    // fallback: request from WEB client
    try {
      final webInnertube = InnerTube(clientName: 'WEB');
      final response = await webInnertube.player(videoId);
      _visitorData = response['responseContext']?['visitorData'] as String?;
      if (_visitorData == null) {
        final pDicts = response['responseContext']?['serviceTrackingParams']?[0]?['params'] as List?;
        if (pDicts != null) {
          for (final p in pDicts) {
            if (p['key'] == 'visitor_data') {
              _visitorData = p['value'] as String?;
              break;
            }
          }
        }
      }
    } catch (_) {}

    return _visitorData ?? '';
  }

  Future<Map<String, dynamic>> get vidInfo async {
    if (_vidInfo != null) return _vidInfo!;
    _vidInfo = await vidInfoClient();
    return _vidInfo!;
  }

  Future<Map<String, dynamic>> get vidDetails async {
    if (_vidDetails != null) return _vidDetails!;
    final innertube = InnerTube(clientName: 'WEB');
    _vidDetails = await innertube.next(videoId);
    return _vidDetails!;
  }

  Future<Map<String, dynamic>> vidInfoClient({String? optionalClient}) async {
    final clientToUse = optionalClient ?? client;

    Future<Map<String, dynamic>> callInnertube(String clientName) async {
      final innertube = InnerTube(clientName: clientName);
      if (innertube.requireJsPlayer) {
        final jsContent = await js;
        final timestamp = extract.signatureTimestamp(jsContent);
        innertube.innertubeContext['playbackContext'] = {
          'contentPlaybackContext': {
            'signatureTimestamp': timestamp,
          }
        };
      }
      
      final vData = await visitorData;
      if (vData.isNotEmpty) {
        if (poToken != null && poToken!.isNotEmpty) {
          innertube.insertPoToken(vData, poToken!);
        } else {
          innertube.insertVisitorData(vData);
        }
      }
      return await innertube.player(videoId);
    }

    final clientCandidates = [clientToUse, ...fallbackClients.where((c) => c != clientToUse)];
    Map<String, dynamic> lastResponse = {};

    for (final candidate in clientCandidates) {
      try {
        final res = await callInnertube(candidate);
        if (res.containsKey('streamingData')) {
          client = candidate;
          return res;
        }
        lastResponse = res;
      } catch (_) {
        continue;
      }
    }

    // Fallback: extract from watch HTML ytInitialPlayerResponse
    try {
      final html = await watchHtml;
      final htmlPlayerResponse = extract.initialPlayerResponse(html);
      if (htmlPlayerResponse.containsKey('streamingData')) {
        client = 'WEB';
        return htmlPlayerResponse;
      }
    } catch (_) {}

    return lastResponse;
  }

  Future<Map<String, dynamic>> get streamingData async {
    final info = await vidInfo;
    const invalidIdList = ['aQvGIIdgFDM'];

    if (!info.containsKey('streamingData') || invalidIdList.contains(info['videoDetails']?['videoId'])) {
      final originalClient = client;

      for (final fallback in fallbackClients) {
        client = fallback;
        _vidInfo = null;
        try {
          final newInfo = await vidInfo;
          await checkAvailability();
          if (newInfo.containsKey('streamingData')) {
            break;
          }
        } catch (_) {
          continue;
        }
      }
      final finalInfo = await vidInfo;
      if (!finalInfo.containsKey('streamingData')) {
        throw UnknownVideoError(
          videoId,
          developerMessage: 'Streaming data is missing, original client: $originalClient, fallback clients: $fallbackClients',
        );
      }
    }

    return (await vidInfo)['streamingData'] as Map<String, dynamic>;
  }

  Future<List<Stream>> get fmtStreams async {
    await checkAvailability();
    if (_fmtStreams != null) {
      return _fmtStreams!;
    }

    _fmtStreams = [];
    final streamData = await streamingData;
    final streamManifest = extract.applyDescrambler(streamData) ?? [];

    final innerTube = InnerTube(clientName: client);

    if (poToken != null) {
      extract.applyPoToken(streamManifest, await vidInfo, poToken!);
    }

    bool signatureAppliedSuccessfully = false;

    if (innerTube.requireJsPlayer) {
      try {
        final jsCode = await js;
        final jsUrlStr = await jsUrl;
        await extract.applySignature(streamManifest, await vidInfo, jsCode, jsUrlStr);
        signatureAppliedSuccessfully = true;
      } catch (_) {
        try {
          const fallbackJsUrl = 'https://www.youtube.com/s/player/2574220e/player_embed.vflset/en_US/base.js';
          final fallbackJsCode = await getRequest(fallbackJsUrl);
          await extract.applySignature(streamManifest, await vidInfo, fallbackJsCode, fallbackJsUrl);
          signatureAppliedSuccessfully = true;
        } catch (_) {
          signatureAppliedSuccessfully = false;
        }
      }

      // Dual fallback: If JS deciphering failed or JS engine is absent, fallback to API Fallback Clients
      if (!signatureAppliedSuccessfully) {
        for (final fallbackClient in ['ANDROID_VR', 'TVHTML5_SIMPLY_EMBEDDED_PLAYER', 'IOS']) {
          try {
            final fallbackInfo = await vidInfoClient(optionalClient: fallbackClient);
            if (fallbackInfo.containsKey('streamingData')) {
              final fallbackManifest = extract.applyDescrambler(fallbackInfo['streamingData'] as Map<String, dynamic>) ?? [];
              if (fallbackManifest.isNotEmpty && fallbackManifest.any((s) => s.containsKey('url'))) {
                _fmtStreams = fallbackManifest.map((s) => Stream(
                  streamData: s,
                  monostate: streamMonostate,
                  poToken: poToken,
                  videoPlaybackUstreamerConfig: fallbackInfo['playerConfig']?['mediaCommonConfig']?['mediaUstreamerRequestConfig']?['videoPlaybackUstreamerConfig'],
                  parentStreams: _fmtStreams,
                )).toList();
                return _fmtStreams!;
              }
            }
          } catch (_) {}
        }
      }
    }

    for (final stream in streamManifest) {
      final video = Stream(
        streamData: stream,
        monostate: streamMonostate,
        poToken: poToken,
        videoPlaybackUstreamerConfig: (await vidInfo)['playerConfig']?['mediaCommonConfig']?['mediaUstreamerRequestConfig']?['videoPlaybackUstreamerConfig'],
        parentStreams: _fmtStreams,
      );
      _fmtStreams!.add(video);
    }

    streamMonostate.title = await title;
    streamMonostate.duration = await length;

    return _fmtStreams!;
  }

  Future<StreamQuery> get streams async {
    return StreamQuery(await fmtStreams);
  }

  Future<void> checkAvailability() async {
    final info = await vidInfo;
    final statusResult = extract.playabilityStatus(info);
    final status = statusResult[0] as String?;
    final messages = List<String?>.from(statusResult[1] as List);

    for (final reason in messages) {
      if (status == 'UNPLAYABLE') {
        if (reason == 'Join this channel to get access to members-only content like this video, and other exclusive perks.' ||
            reason == 'Join this channel to get access to members-only content and other exclusive perks.') {
          throw MembersOnly(videoId);
        } else if (reason == 'This live stream recording is not available.') {
          throw RecordingUnavailable(videoId);
        } else if (reason == 'Sorry, something is wrong. This video may be inappropriate for some users. Sign in to your primary account to confirm your age.') {
          throw AgeCheckRequiredAccountError(videoId);
        } else if (reason == 'The uploader has not made this video available in your country') {
          throw VideoRegionBlocked(videoId);
        } else if (reason != null && reason.contains("blocked it in your country on copyright grounds")) {
          throw VideoBlockedByCopyright(videoId, reason);
        } else {
          throw VideoUnavailable(videoId);
        }
      } else if (status == 'LOGIN_REQUIRED') {
        if (reason == 'Sign in to confirm your age') {
          throw AgeRestrictedError(videoId);
        } else if (reason == 'Sign in to confirm you’re not a bot') {
          throw BotDetection(videoId);
        } else {
          throw LoginRequired(videoId, reason ?? '');
        }
      } else if (status == 'AGE_CHECK_REQUIRED') {
        throw AgeCheckRequiredError(videoId);
      } else if (status == 'LIVE_STREAM_OFFLINE') {
        throw LiveStreamOffline(videoId, reason ?? '');
      } else if (status == 'ERROR') {
        if (reason == 'Video unavailable' || reason == 'This video is unavailable') {
          throw VideoUnavailable(videoId);
        } else if (reason == 'This video is private') {
          throw VideoPrivate(videoId);
        } else if (reason == 'This video has been removed by the uploader') {
          throw VideoRemovedByUploader(videoId, reason);
        } else if (reason == 'This video is no longer available because the YouTube account associated with this video has been terminated.') {
          throw AccountTerminated(videoId, reason);
        } else if (reason == "This video has been removed for violating YouTube's Community Guidelines") {
          throw VideoRemovedByYouTubeForViolatingTOS(videoId, reason);
        } else {
          throw UnknownVideoError(videoId, status: status, reason: reason, developerMessage: 'Unknown reason type for Error status');
        }
      } else if (status == 'LIVE_STREAM') {
        throw LiveStreamError(videoId);
      } else if (status == 'OK') {
        if (reason == 'This live event has ended.') {
          throw LiveStreamEnded(videoId, reason);
        } else {
          throw UnknownVideoError(videoId, status: status, reason: reason, developerMessage: 'Unknown video status');
        }
      } else if (status == null) {
        // Ok
      } else {
        throw UnknownVideoError(videoId, status: status, reason: reason, developerMessage: 'Unknown video status');
      }
    }
  }

  Future<String> get title async {
    final info = await vidInfo;
    final details = info['videoDetails'] as Map<String, dynamic>? ?? {};
    if (details.containsKey('title')) {
      return details['title'] as String;
    }
    
    // Fallback: search in vidDetails
    try {
      final nextDetails = await vidDetails;
      final contents = nextDetails['contents']?['twoColumnWatchNextResults']?['results']?['results']?['contents'] as List?;
      if (contents != null) {
        for (final item in contents) {
          if (item.containsKey('videoPrimaryInfoRenderer')) {
            final t = item['videoPrimaryInfoRenderer']?['title']?['runs']?[0]?['text'] as String?;
            if (t != null) return t;
          }
        }
      }
    } catch (_) {}

    return "Unknown YouTube Video Title";
  }

  Future<int> get length async {
    await checkAvailability();
    final info = await vidInfo;
    final lengthSecStr = info['videoDetails']?['lengthSeconds']?.toString();
    return int.tryParse(lengthSecStr ?? '0') ?? 0;
  }

  Future<String> get author async {
    final info = await vidInfo;
    return info['videoDetails']?['author'] as String? ?? 'unknown';
  }

  Future<String> get thumbnailUrl async {
    final info = await vidInfo;
    final thumbnails = info['videoDetails']?['thumbnail']?['thumbnails'] as List?;
    if (thumbnails != null && thumbnails.isNotEmpty) {
      return thumbnails.last['url'] as String;
    }
    return "https://img.youtube.com/vi/$videoId/maxresdefault.jpg";
  }

  Future<MusicRelated> get musicRelated async {
    final related = MusicRelated(watchUrl);
    await related.fetch();
    return related;
  }

  static YouTube fromId(String videoId) {
    return YouTube("https://www.youtube.com/watch?v=$videoId");
  }
}
