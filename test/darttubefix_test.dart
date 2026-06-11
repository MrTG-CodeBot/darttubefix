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
}
