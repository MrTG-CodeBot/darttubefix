import 'package:darttubefix/darttubefix.dart';

void main() async {
  print('==================================================');
  print('   DARTTUBEFIX: DOWNLOAD AUDIO STREAM EXAMPLE     ');
  print('==================================================');

  final videoUrl = 'https://www.youtube.com/watch?v=-mpP5nkKolc';
  print('Fetching video details for: $videoUrl');

  final yt = YouTube(videoUrl);
  final streamQuery = await yt.streams;

  // Extract the best audio/mp4 stream (itag 140)
  final audioStream = streamQuery.getAudioOnly(subtype: 'mp4') ?? streamQuery.bestAudio;

  if (audioStream == null) {
    print('No audio streams found!');
    return;
  }

  print('\nAudio Stream Found:');
  print('  - itag: ${audioStream.itag}');
  print('  - mimeType: ${audioStream.mimeType}');
  print('  - Bitrate (abr): ${audioStream.abr}');
  print('  - Extension: ${audioStream.subtype}');
  print('  - Total Size: ${audioStream.filesize} bytes');

  final filename = 'song.${audioStream.subtype}';
  print('\nDownloading audio to: $filename...');

  final file = await audioStream.download(
    filename,
    onProgress: (downloadedBytes, totalBytes) {
      if (totalBytes > 0) {
        final percent = ((downloadedBytes / totalBytes) * 100).toStringAsFixed(1);
        print('Downloading... $downloadedBytes / $totalBytes bytes ($percent%)');
      }
    },
  );

  print('\n[SUCCESS] Audio downloaded successfully to: ${file.absolute.path}!');
  print('Saved File Size: ${(file.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB');
}
