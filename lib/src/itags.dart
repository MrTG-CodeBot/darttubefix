class ItagInfo {
  final String? resolution;
  final String? abr;
  
  const ItagInfo(this.resolution, this.abr);
}

const Map<int, ItagInfo> progressiveVideo = {
  5: ItagInfo("240p", "64kbps"),
  6: ItagInfo("270p", "64kbps"),
  13: ItagInfo("144p", null),
  17: ItagInfo("144p", "24kbps"),
  18: ItagInfo("360p", "96kbps"),
  22: ItagInfo("720p", "192kbps"),
  34: ItagInfo("360p", "128kbps"),
  35: ItagInfo("480p", "128kbps"),
  36: ItagInfo("240p", null),
  37: ItagInfo("1080p", "192kbps"),
  38: ItagInfo("3072p", "192kbps"),
  43: ItagInfo("360p", "128kbps"),
  44: ItagInfo("480p", "128kbps"),
  45: ItagInfo("720p", "192kbps"),
  46: ItagInfo("1080p", "192kbps"),
  59: ItagInfo("480p", "128kbps"),
  78: ItagInfo("480p", "128kbps"),
  82: ItagInfo("360p", "128kbps"),
  83: ItagInfo("480p", "128kbps"),
  84: ItagInfo("720p", "192kbps"),
  85: ItagInfo("1080p", "192kbps"),
  91: ItagInfo("144p", "48kbps"),
  92: ItagInfo("240p", "48kbps"),
  93: ItagInfo("360p", "128kbps"),
  94: ItagInfo("480p", "128kbps"),
  95: ItagInfo("720p", "256kbps"),
  96: ItagInfo("1080p", "256kbps"),
  100: ItagInfo("360p", "128kbps"),
  101: ItagInfo("480p", "192kbps"),
  102: ItagInfo("720p", "192kbps"),
  132: ItagInfo("240p", "48kbps"),
  151: ItagInfo("720p", "24kbps"),
  300: ItagInfo("720p", "128kbps"),
  301: ItagInfo("1080p", "128kbps"),
};

const Map<int, ItagInfo> dashVideo = {
  133: ItagInfo("240p", null), // MP4
  134: ItagInfo("360p", null), // MP4
  135: ItagInfo("480p", null), // MP4
  136: ItagInfo("720p", null), // MP4
  137: ItagInfo("1080p", null), // MP4
  138: ItagInfo("2160p", null), // MP4
  160: ItagInfo("144p", null), // MP4
  167: ItagInfo("360p", null), // WEBM
  168: ItagInfo("480p", null), // WEBM
  169: ItagInfo("720p", null), // WEBM
  170: ItagInfo("1080p", null), // WEBM
  212: ItagInfo("480p", null), // MP4
  218: ItagInfo("480p", null), // WEBM
  219: ItagInfo("480p", null), // WEBM
  242: ItagInfo("240p", null), // WEBM
  243: ItagInfo("360p", null), // WEBM
  244: ItagInfo("480p", null), // WEBM
  245: ItagInfo("480p", null), // WEBM
  246: ItagInfo("480p", null), // WEBM
  247: ItagInfo("720p", null), // WEBM
  248: ItagInfo("1080p", null), // WEBM
  264: ItagInfo("1440p", null), // MP4
  266: ItagInfo("2160p", null), // MP4
  271: ItagInfo("1440p", null), // WEBM
  272: ItagInfo("4320p", null), // WEBM
  278: ItagInfo("144p", null), // WEBM
  298: ItagInfo("720p", null), // MP4
  299: ItagInfo("1080p", null), // MP4
  302: ItagInfo("720p", null), // WEBM
  303: ItagInfo("1080p", null), // WEBM
  308: ItagInfo("1440p", null), // WEBM
  313: ItagInfo("2160p", null), // WEBM
  315: ItagInfo("2160p", null), // WEBM
  330: ItagInfo("144p", null), // WEBM
  331: ItagInfo("240p", null), // WEBM
  332: ItagInfo("360p", null), // WEBM
  333: ItagInfo("480p", null), // WEBM
  334: ItagInfo("720p", null), // WEBM
  335: ItagInfo("1080p", null), // WEBM
  336: ItagInfo("1440p", null), // WEBM
  337: ItagInfo("2160p", null), // WEBM
  394: ItagInfo("144p", null), // MP4
  395: ItagInfo("240p", null), // MP4
  396: ItagInfo("360p", null), // MP4
  397: ItagInfo("480p", null), // MP4
  398: ItagInfo("720p", null), // MP4
  399: ItagInfo("1080p", null), // MP4
  400: ItagInfo("1440p", null), // MP4
  401: ItagInfo("2160p", null), // MP4
  402: ItagInfo("4320p", null), // MP4
  571: ItagInfo("4320p", null), // MP4
  694: ItagInfo("144p", null), // MP4
  695: ItagInfo("240p", null), // MP4
  696: ItagInfo("360p", null), // MP4
  697: ItagInfo("480p", null), // MP4
  698: ItagInfo("720p", null), // MP4
  699: ItagInfo("1080p", null), // MP4
  700: ItagInfo("1440p", null), // MP4
  701: ItagInfo("2160p", null), // MP4
  702: ItagInfo("4320p", null), // MP4
};

const Map<int, ItagInfo> dashAudio = {
  139: ItagInfo(null, "48kbps"), // MP4
  140: ItagInfo(null, "128kbps"), // MP4
  141: ItagInfo(null, "256kbps"), // MP4
  171: ItagInfo(null, "128kbps"), // WEBM
  172: ItagInfo(null, "256kbps"), // WEBM
  249: ItagInfo(null, "50kbps"), // WEBM
  250: ItagInfo(null, "70kbps"), // WEBM
  251: ItagInfo(null, "160kbps"), // WEBM
  256: ItagInfo(null, "192kbps"), // MP4
  258: ItagInfo(null, "384kbps"), // MP4
  325: ItagInfo(null, null), // MP4
  328: ItagInfo(null, null), // MP4
};

final Map<int, ItagInfo> itags = {
  ...progressiveVideo,
  ...dashVideo,
  ...dashAudio,
};

const List<int> hdr = [330, 331, 332, 333, 334, 335, 336, 337];
const List<int> threeD = [82, 83, 84, 85, 100, 101, 102];
const List<int> live = [91, 92, 93, 94, 95, 96, 132, 151];

Map<String, dynamic> getFormatProfile(String itagStr) {
  final itag = int.tryParse(itagStr) ?? 0;
  final info = itags[itag];
  
  return {
    "resolution": info?.resolution,
    "abr": info?.abr,
    "is_live": live.contains(itag),
    "is_3d": threeD.contains(itag),
    "is_hdr": hdr.contains(itag),
    "is_dash": dashAudio.containsKey(itag) || dashVideo.containsKey(itag),
  };
}
