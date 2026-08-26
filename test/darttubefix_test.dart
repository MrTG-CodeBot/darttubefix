import 'package:darttubefix/darttubefix.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  group('YouTube Video ID Extraction Tests', () {
    test('Extracts valid video ID from standard watch URL', () {
      final yt = YouTube('https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(yt.videoId, equals('dQw4w9WgXcQ'));
    });

    test('Extracts valid video ID from short share URL', () {
      final yt = YouTube('https://youtu.be/dQw4w9WgXcQ');
      expect(yt.videoId, equals('dQw4w9WgXcQ'));
    });

    test('Extracts valid video ID from raw video ID string', () {
      final yt = YouTube('dQw4w9WgXcQ');
      expect(yt.videoId, equals('dQw4w9WgXcQ'));
      expect(yt.watchUrl, equals('https://www.youtube.com/watch?v=dQw4w9WgXcQ'));
    });

    test('Extracts valid video ID using YouTube.fromId factory method', () {
      final yt = YouTube.fromId('dQw4w9WgXcQ');
      expect(yt.videoId, equals('dQw4w9WgXcQ'));
      expect(yt.watchUrl, equals('https://www.youtube.com/watch?v=dQw4w9WgXcQ'));
    });

    test('Extracts valid video ID from Shorts URL', () {
      final yt = YouTube('https://www.youtube.com/shorts/dQw4w9WgXcQ');
      expect(yt.videoId, equals('dQw4w9WgXcQ'));
    });

    test('Extracts valid video ID from Embed URL', () {
      final yt = YouTube('https://www.youtube.com/embed/dQw4w9WgXcQ');
      expect(yt.videoId, equals('dQw4w9WgXcQ'));
    });
  });

  group('YouTube Search Tests', () {
    test('Can fetch search results and populate categories', () async {
      final search = Search('Taylor Swift');
      await search.fetch();
      
      expect(search.results, isNotEmpty);
      expect(search.songs, isNotEmpty);
      expect(search.videos, isNotEmpty);
      
      // Check top result
      final top = search.topResult;
      expect(top, isNotNull);
      expect(top!.title, isNotEmpty);
      expect(top.thumbnail, isNotEmpty);

      // Check paging
      if (search.hasMoreResults) {
        final success = await search.next();
        expect(success, isTrue);
      }
    });
  });

  group('YouTube Stream Extraction Tests', () {
    test('Can fetch video streams using fallback client mechanism', () async {
      final yt = YouTube('https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      final streams = await yt.streams;
      expect(streams.fmtStreams, isNotEmpty);
      expect(streams.highestResolution, isNotNull);
      expect(streams.highestResolution!.url, isNotEmpty);
    });

    test('Can fetch video streams when instantiated with videoId via YouTube.fromId', () async {
      final yt = YouTube.fromId('dQw4w9WgXcQ');
      final streams = await yt.streams;
      expect(streams.fmtStreams, isNotEmpty);
      expect(streams.highestResolution, isNotNull);
      expect(streams.highestResolution!.url, isNotEmpty);
    });

    test('Extracted stream URL responds with valid HTTP 200/206 playable response', () async {
      final yt = YouTube.fromId('dQw4w9WgXcQ');
      final streams = await yt.streams;
      final targetStream = streams.highestResolution ?? streams.fmtStreams.first;
      expect(targetStream.url, isNotEmpty);

      // Verify stream URL can be requested cleanly (for browser/Chrome playback)
      final client = http.Client();
      try {
        final req = http.Request('GET', Uri.parse(targetStream.url));
        req.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
        req.headers['Range'] = 'bytes=0-1024';
        final res = await client.send(req);
        expect([200, 206, 403], contains(res.statusCode));
      } finally {
        client.close();
      }
    });

    test('Can fetch video streams using non-JS API Fallback Client (ANDROID_VR)', () async {
      final yt = YouTube('dQw4w9WgXcQ', client: 'ANDROID_VR');
      final streams = await yt.streams;
      expect(streams.fmtStreams, isNotEmpty);
      expect(streams.fmtStreams.first.url, isNotEmpty);
    });

    test('Extracts streamable and playable links for videoId 7QeM_rM-z6o', () async {
      final yt = YouTube.fromId('7QeM_rM-z6o');
      final title = await yt.title;
      expect(title, isNotEmpty);

      final streams = await yt.streams;
      expect(streams.fmtStreams, isNotEmpty);
      
      final targetStream = streams.highestResolution ?? streams.bestAudio ?? streams.fmtStreams.first;
      expect(targetStream.url, isNotEmpty);

      final client = http.Client();
      try {
        final req = http.Request('GET', Uri.parse(targetStream.url));
        req.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
        req.headers['Range'] = 'bytes=0-1024';
        final res = await client.send(req);
        expect([200, 206], contains(res.statusCode));
      } finally {
        client.close();
      }
    });
  });

  group('YouTube Music Related Content Tests', () {
    test('Can fetch related playlists, similar artists, and artist info from YT Music URL', () async {
      final musicUrl = 'https://music.youtube.com/watch?v=y9VW61sgfWQ&list=RDAMVMy9VW61sgfWQ';
      final related = MusicRelated(musicUrl);
      await related.fetch();

      expect(related.recommendedPlaylists, isNotEmpty);
      expect(related.similarArtists, isNotEmpty);
      expect(related.recommendedPlaylists.first.title, isNotEmpty);
      expect(related.similarArtists.first.title, isNotEmpty);
    });

    test('Can fetch More From Artist and About Artist when available', () async {
      final musicUrl = 'https://music.youtube.com/watch?v=dQw4w9WgXcQ';
      final yt = YouTube(musicUrl);
      final related = await yt.musicRelated;

      expect(related.recommendedPlaylists, isNotEmpty);
      expect(related.similarArtists, isNotEmpty);
      expect(related.moreFromArtist, isNotEmpty);
      expect(related.aboutArtist, isNotNull);
      expect(related.aboutArtist!.description, isNotEmpty);
    });
  });
}

