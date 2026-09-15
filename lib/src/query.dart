import 'stream.dart';

class StreamQuery {
  final List<Stream> fmtStreams;
  late final Map<int, Stream> itagIndex;

  StreamQuery(this.fmtStreams) {
    itagIndex = {for (var s in fmtStreams) s.itag: s};
  }

  StreamQuery filter({
    int? fps,
    String? res,
    String? resolution,
    String? mimeType,
    String? type,
    String? subtype,
    String? fileExtension,
    String? abr,
    String? bitrate,
    String? videoCodec,
    String? audioCodec,
    bool? onlyAudio,
    bool? onlyVideo,
    bool? progressive,
    bool? adaptive,
    bool? isDash,
    bool? isDrc,
    bool? isSabr,
  }) {
    var streams = List<Stream>.from(fmtStreams);

    if (fps != null) {
      streams = streams.where((s) => s.fps == fps).toList();
    }

    final targetRes = resolution ?? res;
    if (targetRes != null) {
      streams = streams.where((s) => s.resolution == targetRes).toList();
    }

    if (mimeType != null) {
      streams = streams.where((s) => s.mimeType == mimeType).toList();
    }

    if (type != null) {
      streams = streams.where((s) => s.type == type).toList();
    }

    final targetSubtype = subtype ?? fileExtension;
    if (targetSubtype != null) {
      streams = streams.where((s) => s.subtype == targetSubtype).toList();
    }

    final targetAbr = abr ?? bitrate;
    if (targetAbr != null) {
      streams = streams.where((s) => s.abr == targetAbr).toList();
    }

    if (videoCodec != null) {
      streams = streams.where((s) => s.videoCodec == videoCodec).toList();
    }

    if (audioCodec != null) {
      streams = streams.where((s) => s.audioCodec == audioCodec).toList();
    }

    if (onlyAudio == true) {
      streams = streams.where((s) => s.includesAudioTrack && !s.includesVideoTrack).toList();
    }

    if (onlyVideo == true) {
      streams = streams.where((s) => s.includesVideoTrack && !s.includesAudioTrack).toList();
    }

    if (progressive == true) {
      streams = streams.where((s) => s.isProgressive).toList();
    }

    if (adaptive == true) {
      streams = streams.where((s) => s.isAdaptive).toList();
    }

    if (isDash != null) {
      streams = streams.where((s) => s.isDash == isDash).toList();
    }

    if (isDrc != null) {
      streams = streams.where((s) => s.isDrc == isDrc).toList();
    }

    if (isSabr != null) {
      streams = streams.where((s) => s.isSabr == isSabr).toList();
    }

    return StreamQuery(streams);
  }

  StreamQuery orderBy(String attributeName) {
    final hasAttribute = fmtStreams.where((s) {
      switch (attributeName) {
        case 'resolution': return s.resolution != null;
        case 'fps': return s.fps != null;
        case 'bitrate': return s.bitrate != null;
        case 'filesize': return s.filesize > 0;
        case 'abr': return s.abr != null || s.bitrate != null;
        default: return false;
      }
    }).toList();

    hasAttribute.sort((a, b) {
      dynamic valA;
      dynamic valB;
      switch (attributeName) {
        case 'resolution':
          valA = _parseNumberOnly(a.resolution ?? '');
          valB = _parseNumberOnly(b.resolution ?? '');
          break;
        case 'fps':
          valA = a.fps ?? 0;
          valB = b.fps ?? 0;
          break;
        case 'bitrate':
          valA = a.bitrate ?? 0;
          valB = b.bitrate ?? 0;
          break;
        case 'filesize':
          valA = a.filesize;
          valB = b.filesize;
          break;
        case 'abr':
          valA = a.bitrate ?? _parseNumberOnly(a.abr ?? '');
          valB = b.bitrate ?? _parseNumberOnly(b.abr ?? '');
          break;
        default:
          return 0;
      }
      return (valA as Comparable).compareTo(valB as Comparable);
    });

    return StreamQuery(hasAttribute);
  }

  int _parseNumberOnly(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return int.tryParse(digits) ?? 0;
  }

  StreamQuery desc() {
    return StreamQuery(fmtStreams.reversed.toList());
  }

  StreamQuery asc() {
    return this;
  }

  Stream? getByItag(dynamic itag) {
    if (itag is int) {
      return itagIndex[itag];
    }
    if (itag is String) {
      final parsed = int.tryParse(itag);
      if (parsed != null) {
        return itagIndex[parsed];
      }
    }
    return null;
  }

  StreamQuery get audioOnly => filter(onlyAudio: true, isSabr: false);
  StreamQuery get videoOnly => filter(onlyVideo: true, isSabr: false);
  StreamQuery get progressiveStreams => filter(progressive: true, isSabr: false);
  StreamQuery get videoStreams => StreamQuery(fmtStreams.where((s) => s.includesVideoTrack && !s.isSabr).toList());
  StreamQuery get allPlayable => StreamQuery(fmtStreams.where((s) => !s.isSabr).toList());

  Stream? get lowestResolution {
    final progressive = filter(progressive: true, subtype: "mp4").orderBy("resolution");
    return progressive.first;
  }

  Stream? get highestResolution {
    final progressive = filter(progressive: true).orderBy("resolution");
    return progressive.last;
  }

  Stream? get bestAudio {
    final mp4Audio = filter(onlyAudio: true, subtype: "mp4").orderBy("abr");
    if (mp4Audio.fmtStreams.isNotEmpty) {
      return mp4Audio.last;
    }
    final audioStreams = audioOnly.orderBy("abr");
    return audioStreams.fmtStreams.isNotEmpty ? audioStreams.last : null;
  }

  Stream? getAudioOnly({String? subtype = "mp4"}) {
    if (subtype != null && subtype.isNotEmpty) {
      final audioStreams = filter(onlyAudio: true, subtype: subtype).orderBy("abr");
      if (audioStreams.fmtStreams.isNotEmpty) {
        return audioStreams.last;
      }
    }
    return bestAudio;
  }

  Stream? get first {
    return fmtStreams.isNotEmpty ? fmtStreams.first : null;
  }

  Stream? get last {
    return fmtStreams.isNotEmpty ? fmtStreams.last : null;
  }

  int get length => fmtStreams.length;

  Stream operator [](int index) => fmtStreams[index];

  @override
  String toString() => fmtStreams.toString();
}
