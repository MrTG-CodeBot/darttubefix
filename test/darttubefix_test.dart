import 'package:darttubefix/darttubefix.dart';
import 'package:test/test.dart';

void main() {
  group('YouTube URL Video ID Extraction Tests', () {
    test('Extracts valid video ID from standard watch URL', () {
      final yt = YouTube('https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(yt.videoId, equals('dQw4w9WgXcQ'));
    });

    test('Extracts valid video ID from short share URL', () {
      final yt = YouTube('https://youtu.be/dQw4w9WgXcQ');
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

