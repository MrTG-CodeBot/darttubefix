import 'dart:async' as async;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'monostate.dart';
import 'extract.dart';
import 'itags.dart';

class Stream {
  final Map<String, dynamic> streamData;
  final Monostate monostate;
  final String? poToken;
  final dynamic videoPlaybackUstreamerConfig;
  final List<Stream>? parentStreams;

  late final String url;
  late final int itag;
  late final String? xtags;
  late final String mimeType;
  late final List<String> codecs;
  late final String type;
  late final String subtype;
  late final String? videoCodec;
  late final String? audioCodec;
  late final bool isOtf;
  late final int? bitrate;
  late final int filesize;
  late final bool isDash;
  late final String? abr;
  late final String? resolution;
  late final int? fps;
  late final int? width;
  late final int? height;
  late final bool is3d;
  late final bool isHdr;
  late final bool isLive;
  late final bool isDrc;
  late final bool isSabr;
  late final String approxDurationMs;
  late final String lastModified;

  Stream({
    required this.streamData,
    required this.monostate,
    this.poToken,
    this.videoPlaybackUstreamerConfig,
    this.parentStreams,
  }) {
    url = streamData["url"] ?? '';
    itag = int.tryParse(streamData["itag"]?.toString() ?? '0') ?? 0;
    xtags = streamData["xtags"];
    
    final mimeCodecResult = mimeTypeCodec(streamData["mimeType"] ?? '');
    mimeType = mimeCodecResult[0] as String;
    codecs = List<String>.from(mimeCodecResult[1] as List);
    
    final mimeSplit = mimeType.split("/");
    type = mimeSplit[0];
    subtype = mimeSplit.length > 1 ? mimeSplit[1] : '';
    
    isOtf = streamData["is_otf"] == true;
    bitrate = int.tryParse(streamData["bitrate"]?.toString() ?? '0');
    filesize = int.tryParse(streamData["contentLength"]?.toString() ?? '0') ?? 0;
    
    final itagProfile = getFormatProfile(itag.toString());
    isDash = itagProfile["is_dash"] == true;
    abr = itagProfile["abr"] ?? (bitrate != null && bitrate! > 0 ? '${(bitrate! ~/ 1000)}kbps' : null);
    
    if (streamData.containsKey('fps')) {
      fps = int.tryParse(streamData['fps']?.toString() ?? '0');
    } else {
      fps = null;
    }
    
    resolution = itagProfile["resolution"];
    width = int.tryParse(streamData["width"]?.toString() ?? '0');
    height = int.tryParse(streamData["height"]?.toString() ?? '0');
    
    is3d = itagProfile["is_3d"] == true;
    isHdr = itagProfile["is_hdr"] == true;
    isLive = itagProfile["is_live"] == true;
    isDrc = streamData["isDrc"] == true;
    isSabr = streamData["is_sabr"] == true;
    
    approxDurationMs = streamData['approxDurationMs']?.toString() ?? '';
    lastModified = streamData['lastModified']?.toString() ?? '';
    
    final parsed = parseCodecs();
    videoCodec = parsed[0];
    audioCodec = parsed[1];
  }

  /// Headers required by HTTP clients and audio/video players (e.g. just_audio, audioplayers, video_player) to stream cleanly without 403 Forbidden errors.
  Map<String, String> get httpHeaders => {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Range': 'bytes=0-1024',
    'Accept': '*/*',
  };

  bool get isAdaptive => codecs.length == 1; // if codecs length is 1, it only has video or only audio, hence adaptive
  bool get isProgressive => !isAdaptive;
  bool get includesAudioTrack => isProgressive || type == "audio";
  bool get includesVideoTrack => isProgressive || type == "video";

  List<String?> parseCodecs() {
    String? video;
    String? audio;
    if (!isAdaptive) {
      if (codecs.length > 1) {
        video = codecs[0];
        audio = codecs[1];
      } else if (codecs.isNotEmpty) {
        video = codecs[0];
      }
    } else if (includesVideoTrack) {
      if (codecs.isNotEmpty) video = codecs[0];
    } else if (includesAudioTrack) {
      if (codecs.isNotEmpty) audio = codecs[0];
    }
    return [video, audio];
  }

  @override
  String toString() {
    return "<Stream: itag=$itag mimeType=$mimeType resolution=$resolution progressive=$isProgressive type=$type url=$url>";
  }

  /// Downloads the stream content into a local file cleanly without 403 throttling errors.
  Future<File> download(String outputPath, {void Function(int downloadedBytes, int totalBytes)? onProgress}) async {
    final outputFile = File(outputPath);
    final sink = outputFile.openWrite();
    final client = http.Client();

    final chunkSize = 512 * 1024;
    final totalBytes = filesize;
    var start = 0;
    var downloadedBytes = 0;

    try {
      while (start < totalBytes || totalBytes == 0) {
        final end = totalBytes > 0 
            ? (start + chunkSize - 1 < totalBytes ? start + chunkSize - 1 : totalBytes - 1)
            : start + chunkSize - 1;

        final req = http.Request('GET', Uri.parse(url));
        req.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)';
        req.headers['Accept'] = '*/*';
        req.headers['Range'] = 'bytes=$start-$end';

        final res = await client.send(req);
        if (res.statusCode == 200 || res.statusCode == 206) {
          var bytesInChunk = 0;
          await for (final chunk in res.stream) {
            bytesInChunk += chunk.length;
            downloadedBytes += chunk.length;
            sink.add(chunk);
            onProgress?.call(downloadedBytes, totalBytes);
          }

          if (res.statusCode == 200 || bytesInChunk == 0 || (totalBytes > 0 && downloadedBytes >= totalBytes)) {
            break;
          }
          start = end + 1;
        } else {
          // Fallback to progressive stream if adaptive stream is throttled by YouTube CDN
          if (parentStreams != null && parentStreams!.isNotEmpty) {
            final progList = parentStreams!.where((s) => s.isProgressive && !s.isSabr).toList();
            if (progList.isNotEmpty) {
              final prog = progList.first;
              if (prog.itag != itag && prog.url.isNotEmpty) {
                await sink.close();
                client.close();
                return await prog.download(outputPath, onProgress: onProgress);
              }
            }
          }
          throw Exception('HTTP ${res.statusCode} on range bytes=$start-$end');
        }
      }
    } finally {
      await sink.close();
      client.close();
    }

    return outputFile;
  }

  /// Returns a stream of byte chunks for this media stream.
  async.Stream<List<int>> getByteStream() async* {
    final client = http.Client();
    final chunkSize = 512 * 1024;
    final totalBytes = filesize;
    var start = 0;

    try {
      while (start < totalBytes || totalBytes == 0) {
        final end = totalBytes > 0 
            ? (start + chunkSize - 1 < totalBytes ? start + chunkSize - 1 : totalBytes - 1)
            : start + chunkSize - 1;

        final req = http.Request('GET', Uri.parse(url));
        req.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)';
        req.headers['Accept'] = '*/*';
        req.headers['Range'] = 'bytes=$start-$end';

        final res = await client.send(req);
        if (res.statusCode == 200 || res.statusCode == 206) {
          var bytesInChunk = 0;
          await for (final chunk in res.stream) {
            bytesInChunk += chunk.length;
            yield chunk;
          }
          if (bytesInChunk == 0 || (totalBytes > 0 && start >= totalBytes)) {
            break;
          }
          start = end + 1;
        } else {
          throw Exception('HTTP ${res.statusCode} on range bytes=$start-$end');
        }
      }
    } finally {
      client.close();
    }
  }
}
