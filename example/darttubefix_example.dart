import 'package:darttubefix/darttubefix.dart';

void main() async {
  final yt = YouTube('https://www.youtube.com/watch?v=r8iPHiciQd0');

  try {
    final StreamQuery streamQuery = await yt.streams;
    print('Total streams found: ${streamQuery.fmtStreams.length}');
    for (final s in streamQuery.fmtStreams) {
      print('Stream: itag=${s.itag}, resolution=${s.resolution}, mimeType=${s.mimeType}');
      print('  URL: ${s.url}');
    }

    final Stream? highest = streamQuery.highestResolution;
    if (highest != null) {
      print('\nHighest resolution progressive stream: ${highest.resolution}');
      print('URL: ${highest.url}');
    }

    final Stream? audio = streamQuery.getAudioOnly();
    if (audio != null) {
      print('\nBest audio-only stream: ${audio.abr}');
      print('URL: ${audio.url}');
    }
  } catch (e, stack) {
    print('Failed to get video stream URL: $e');
    print(stack);
  }
}
