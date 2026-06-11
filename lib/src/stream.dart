import 'monostate.dart';
import 'extract.dart';
import 'itags.dart';

class Stream {
  final Map<String, dynamic> streamData;
  final Monostate monostate;
  final String? poToken;
  final dynamic videoPlaybackUstreamerConfig;

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
    abr = itagProfile["abr"];
    
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
}
