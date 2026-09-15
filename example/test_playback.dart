import 'package:darttubefix/darttubefix.dart';
import 'package:http/http.dart' as http;

void main() async {
  print('==================================================');
  print('    DARTTUBEFIX: STREAM PLAYBACK & VERIFICATION   ');
  print('==================================================\n');

  // Test YouTube Music / YouTube URL
  final videoUrl = 'https://music.youtube.com/watch?v=GXK_cO2McxQ';
  print('1. Extracting metadata for: $videoUrl');

  final yt = YouTube(videoUrl);
  print('   - Title: ${await yt.title}');
  print('   - Author: ${await yt.author}');
  print('   - Duration: ${await yt.length} seconds');
  print('   - Thumbnail: ${await yt.thumbnailUrl}');

  print('\n2. Extracting streams...');
  final streams = await yt.streams;
  print('   - Total streams found: ${streams.length}');

  // Extract best audio and highest resolution video streams
  final bestAudio = streams.bestAudio;
  final highestRes = streams.highestResolution;

  if (bestAudio != null) {
    print('\n3. Best Audio Stream Details:');
    print('   - itag: ${bestAudio.itag}');
    print('   - mimeType: ${bestAudio.mimeType}');
    print('   - Audio Bitrate: ${bestAudio.abr}');
    print('   - Direct URL: ${bestAudio.url}');
    print('   - HTTP Headers: ${bestAudio.httpHeaders}');

    print('\n4. Verifying Stream Playability (HTTP GET with headers)...');
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(bestAudio.url));
      // Apply stream.httpHeaders for HTTP GET verification
      bestAudio.httpHeaders.forEach((key, value) {
        req.headers[key] = value;
      });

      final res = await client.send(req);
      print('   - HTTP Status Code: ${res.statusCode}');
      if (res.statusCode == 200 || res.statusCode == 206) {
        print('   - [SUCCESS] Stream URL is 100% playable!');
      } else {
        print('   - [ERROR] Stream URL returned HTTP ${res.statusCode}');
      }
    } finally {
      client.close();
    }
  }

  if (highestRes != null) {
    print('\n5. Highest Resolution Video Stream Details:');
    print('   - itag: ${highestRes.itag}');
    print('   - Resolution: ${highestRes.resolution}');
    print('   - mimeType: ${highestRes.mimeType}');
    print('   - Direct URL: ${highestRes.url}');
  }

  print('\n==================================================');
  print('Flutter Audio Player Integration Examples:');
  print('==================================================');
  print('''
a) Using with `just_audio`:
   final player = AudioPlayer();
   await player.setUrl(
     bestAudio.url,
     headers: bestAudio.httpHeaders,
   );
   await player.play();

b) Using with `audioplayers`:
   final player = AudioPlayer();
   await player.play(
     UrlSource(bestAudio.url),
   );

c) Using with `video_player`:
   final controller = VideoPlayerController.networkUrl(
     Uri.parse(highestRes.url),
     httpHeaders: highestRes.httpHeaders,
   );
   await controller.initialize();
   controller.play();
''');
}
