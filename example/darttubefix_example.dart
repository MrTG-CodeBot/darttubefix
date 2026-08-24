import 'package:darttubefix/darttubefix.dart';

void main() async {
  final url = 'https://www.youtube.com/watch?v=-mpP5nkKolc';
  print('==================================================');
  print('       DARTTUBEFIX: STREAM & DOWNLOAD EXAMPLE     ');
  print('==================================================');
  print('Fetching playable stream links for: $url\n');

  final yt = YouTube(url);

  try {
    final StreamQuery streamQuery = await yt.streams;

    print('==================================================');
    print('          PLAYABLE AUDIO-ONLY STREAMS             ');
    print('==================================================');
    for (final s in streamQuery.audioOnly.fmtStreams) {
      final abr = s.abr != null ? ' ${s.abr}' : '';
      print('itag ${s.itag} (${s.mimeType},$abr) ✅ Playable');
      print('URL: ${s.url}\n');
    }

    print('==================================================');
    print(' PROGRESSIVE COMBINED STREAMS (VIDEO + AUDIO)     ');
    print('==================================================');
    for (final s in streamQuery.progressiveStreams.fmtStreams) {
      final res = s.resolution != null ? ' ${s.resolution}' : '';
      print('itag ${s.itag} (${s.mimeType},$res Progressive Video+Audio) ✅ Playable');
      print('URL: ${s.url}\n');
    }

    print('==================================================');
    print('       AUTO DOWNLOADING BEST AUDIO/MP4 STREAM     ');
    print('==================================================');
    final bestAudio = streamQuery.getAudioOnly(subtype: 'mp4') ?? streamQuery.bestAudio;
    if (bestAudio != null) {
      final filename = 'play_audio_example.${bestAudio.subtype}';
      print('Downloading Best Audio (itag ${bestAudio.itag}, ${bestAudio.mimeType}) to $filename...');
      print('URL: ${bestAudio.url}\n');

      final downloadedFile = await bestAudio.download(
        filename,
        onProgress: (downloadedBytes, totalBytes) {
          if (totalBytes > 0) {
            final percent = ((downloadedBytes / totalBytes) * 100).toStringAsFixed(1);
            print('Downloading... $downloadedBytes / $totalBytes bytes ($percent%)');
          }
        },
      );

      print('\n[SUCCESS] Audio file downloaded and saved successfully!');
      print('Path: ${downloadedFile.absolute.path}');
      print('Size: ${(downloadedFile.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB');
      print('This file can now be opened & played in VLC, Windows Media Player, or Flutter AudioPlayer!');
    }
  } catch (e, stack) {
    print('Failed to process video streams: $e');
    print(stack);
  }
}
