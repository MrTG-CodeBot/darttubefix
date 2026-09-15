import 'dart:io';
import 'package:darttubefix/darttubefix.dart';

void main() async {
  const videoUrl = 'https://www.youtube.com/watch?v=-mpP5nkKolc';
  print('================================================================');
  print('🧪 EXTRACTING ALL STREAMS & PLAYABLE LINKS FOR:');
  print('   $videoUrl');
  print('================================================================\n');

  try {
    final yt = YouTube(videoUrl, client: 'VISION_OS');
    final title = await yt.title;
    final author = await yt.author;
    print('🎵 Title : $title');
    print('👤 Artist: $author\n');

    final StreamQuery streams = await yt.streams;

    // 1. PROGRESSIVE STREAMS (100% Direct Playable in Browser / VLC / Any Player)
    print('================================================================');
    print(' 1. DIRECT PLAYABLE PROGRESSIVE STREAM (${streams.progressiveStreams.length} found)');
    print('    (Contains Audio + Video combined. 100% playable anywhere without headers)');
    print('================================================================');
    for (final s in streams.progressiveStreams.fmtStreams) {
      print('🎬 ITAG: ${s.itag.toString().padRight(4)} | Res: ${(s.resolution ?? "360p").padRight(6)} | Format: ${s.mimeType.padRight(12)} | Size: ${(s.filesize / 1024 / 1024).toStringAsFixed(2)} MB');
      print('   🔗 Playable URL: ${s.url}\n');
    }

    // 2. AUDIO-ONLY STREAMS (DASH Adaptive)
    print('================================================================');
    print(' 2. AUDIO-ONLY STREAMS (${streams.audioOnly.length} found)');
    print('    (Separate audio track. Playable with Range headers or via stream.download())');
    print('================================================================');
    for (final s in streams.audioOnly.fmtStreams) {
      print('🔊 ITAG: ${s.itag.toString().padRight(4)} | Format: ${s.mimeType.padRight(12)} | Bitrate: ${(s.abr ?? "${(s.bitrate ?? 0) ~/ 1000}kbps").padRight(8)} | Size: ${(s.filesize / 1024 / 1024).toStringAsFixed(2)} MB');
      print('   🔗 Stream URL: ${s.url}\n');
    }

    // 3. VIDEO-ONLY STREAMS (DASH Adaptive)
    print('================================================================');
    print(' 3. VIDEO-ONLY STREAMS (${streams.videoOnly.length} found)');
    print('================================================================');
    for (final s in streams.videoOnly.fmtStreams) {
      print('📹 ITAG: ${s.itag.toString().padRight(4)} | Res: ${(s.resolution ?? "").padRight(6)} | FPS: ${s.fps ?? 0} | Format: ${s.mimeType}');
      print('   🔗 Stream URL: ${s.url}\n');
    }

    // 4. TEST DIRECT PLAYBACK ON BOTH PROGRESSIVE AND AUDIO STREAMS
    print('================================================================');
    print(' 4. TESTING PLAYBACK');
    print('================================================================');

    // Test Progressive Stream (Direct click test)
    final progStream = streams.progressiveStreams.fmtStreams.isNotEmpty ? streams.progressiveStreams.fmtStreams.first : null;
    if (progStream != null) {
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(progStream.url));
      final res = await req.close();
      print('🎬 Progressive Stream Test (ITAG ${progStream.itag}):');
      print('   - HTTP Status Code : ${res.statusCode}');
      print('   - Content-Type     : ${res.headers.value('content-type')}');
      if (res.statusCode == 200 || res.statusCode == 206) {
        print('   ✅ 100% DIRECT PLAYABLE LINK! (Paste into any browser/player to play)\n');
      }
    }

    // Test Audio-Only Stream (With player headers)
    final audioStream = streams.getAudioOnly(subtype: 'mp4') ?? streams.bestAudio;
    if (audioStream != null) {
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(audioStream.url));
      req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      req.headers.set('Accept', '*/*');
      req.headers.set('Range', 'bytes=0-1023');
      final res = await req.close();
      print('🔊 Audio-Only Stream Test (ITAG ${audioStream.itag}):');
      print('   - HTTP Status Code : ${res.statusCode}');
      print('   - Content-Type     : ${res.headers.value('content-type')}');
      if (res.statusCode == 200 || res.statusCode == 206) {
        print('   ✅ Audio stream active and streaming audio data directly from YouTube CDN!\n');
      }
    }

  } catch (e, stack) {
    print('❌ Error: $e');
    print(stack);
  }
}
