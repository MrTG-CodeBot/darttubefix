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
      final yt = YouTube('https://www.youtube.com/watch?v=r8iPHiciQd0');
      final streams = await yt.streams;
      expect(streams.fmtStreams, isNotEmpty);
      expect(streams.highestResolution, isNotNull);
      expect(streams.highestResolution!.url, isNotEmpty);
    });
  });
}
