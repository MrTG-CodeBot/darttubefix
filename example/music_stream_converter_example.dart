import 'dart:io';
import 'package:darttubefix/darttubefix.dart';

/// Complete Python-to-Dart converted script for YouTube Music stream links.
///
/// Python (pytubefix):
/// ```python
/// from pytubefix import YouTube
/// yt = YouTube('https://music.youtube.com/watch?v=y9VW61sgfWQ', client='WEB_MUSIC')
/// print(yt.title)
/// stream = yt.streams.get_audio_only()
/// stream.download('song.m4a')
/// ```
void main() async {
  // Input YouTube Music URL (Rick Astley - Never Gonna Give You Up)
  const String musicUrl = 'https://music.youtube.com/watch?v=GXK_cO2McxQ';
  print('Processing YouTube Music Link: $musicUrl\n');

  // Initialize YouTube object with 'WEB_MUSIC' client
  final yt = YouTube(musicUrl, client: 'WEB_MUSIC');

  try {
    // 1. Fetch Track Metadata (Converted from pytubefix sync properties to Dart Futures)
    final String title = await yt.title;
    final String author = await yt.author;
    final int duration = await yt.length;
    final String thumbnail = await yt.thumbnailUrl;
    final String videoId = yt.videoId;

    print('=== 1. TRACK METADATA ===');
    print('Video ID   : $videoId');
    print('Title      : $title');
    print('Artist     : $author');
    print('Duration   : $duration seconds');
    print('Thumbnail  : $thumbnail\n');

    // 2. Fetch Playable Audio Stream (Converted from yt.streams.get_audio_only())
    print('=== 2. AUDIO STREAMS ===');
    final StreamQuery streams = await yt.streams;
    final Stream? bestAudio =
        streams.getAudioOnly(subtype: 'mp4') ?? streams.bestAudio;

    if (bestAudio != null) {
      print('ITAG       : ${bestAudio.itag}');
      print('Bitrate    : ${bestAudio.abr}');
      print('MIME Type  : ${bestAudio.mimeType}');
      print('Playable URL: ${bestAudio.url}\n');

      // 3. Download Audio Track (Converted from stream.download())
      const String outputPath = 'downloaded_music_track.m4a';
      print('=== 3. DOWNLOADING AUDIO ===');
      print('Downloading to $outputPath...');

      final File file = await bestAudio.download(
        outputPath,
        onProgress: (downloadedBytes, totalBytes) {
          if (totalBytes > 0) {
            final percent =
                ((downloadedBytes / totalBytes) * 100).toStringAsFixed(1);
            print(
                'Download Progress: $percent% ($downloadedBytes / $totalBytes bytes)');
          }
        },
      );

      print('Download Complete! Saved at: ${file.absolute.path}\n');
    }

    // 4. YouTube Music Related Content (Playlists, Similar Artists, Artist Bio)
    print('=== 4. YOUTUBE MUSIC RELATED DATA ===');
    final related = MusicRelated(musicUrl);
    await related.fetch();

    print('Recommended Playlists (${related.recommendedPlaylists.length}):');
    for (final playlist in related.recommendedPlaylists.take(3)) {
      print(' - ${playlist.title} (ID: ${playlist.playlistId})');
    }

    print('\nSimilar Artists (${related.similarArtists.length}):');
    for (final artist in related.similarArtists.take(3)) {
      print(' - ${artist.title} (Channel ID: ${artist.channelId})');
    }

    if (related.aboutArtist != null) {
      print('\nArtist Bio:');
      print(related.aboutArtist!.description);
    }
  } catch (e, stack) {
    print('Error during music stream processing: $e');
    print(stack);
  }
}
