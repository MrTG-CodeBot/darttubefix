import 'dart:io';
import 'package:darttubefix/darttubefix.dart';

void main() async {
  final videoUrl = 'https://www.youtube.com/watch?v=mpP5nkKolc';
  print(
      '🧪 Testing stream extraction and HTTP playback response for: $videoUrl\n');

  try {
    final yt = YouTube(videoUrl);
    final streams = await yt.streams;
    final audioStream = streams.getByItag(140) ?? streams.getAudioOnly();

    if (audioStream == null) {
      print('❌ Audio stream not found!');
      return;
    }

    print('✅ Audio stream found!');
    print('   - itag: ${audioStream.itag}');
    print('   - mimeType: ${audioStream.mimeType}');
    print('   - bitrate: ${audioStream.bitrate}');
    print('   - stream URL: ${audioStream.url}\n');

    print('📡 Testing stream HTTP playback response from YouTube CDN...');

    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(audioStream.url));

    // Add standard headers required for media streaming
    request.headers.set('User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
    request.headers
        .set('Range', 'bytes=0-1023'); // Request first 1KB audio slice

    final response = await request.close();
    print(
        '   - HTTP Status Code: ${response.statusCode}'); // 200 or 206 (Partial Content)
    print('   - Content-Type: ${response.headers.value('content-type')}');
    print(
        '   - Content-Length: ${response.headers.value('content-length')} bytes');

    if (response.statusCode == 200 || response.statusCode == 206) {
      print('\n🎉 STREAM PLAYBACK TEST SUCCESSFUL!');
      print(
          'The stream link is active, valid, and serving audio data directly from YouTube CDN!');
    } else {
      print(
          '\n❌ Stream HTTP request failed with status: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Error testing stream playback: $e');
  }
}
