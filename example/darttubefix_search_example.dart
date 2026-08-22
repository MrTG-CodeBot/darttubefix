import 'package:darttubefix/darttubefix.dart';

void main() async {
  final query = 'nyabagam';
  print('========================================');
  print('Initializing search for query: "$query"');
  print('========================================');

  final search = Search(query);

  try {
    // 1. Fetch initial results
    print('Fetching initial results...');
    await search.fetch();

    // 2. Display Top Result
    final top = search.topResult;
    print('\n--- TOP RESULT ---');
    if (top != null) {
      print('Type: ${top.runtimeType}');
      print('Title: ${top.title}');
      print('Thumbnail: ${top.thumbnail}');
      if (top is SearchVideo) {
        print('Video ID: ${top.videoId}');
      } else if (top is SearchChannel) {
        print('Channel ID: ${top.channelId}');
      } else if (top is SearchPlaylist) {
        print('Playlist ID: ${top.playlistId}');
      }
    } else {
      print('No top result found.');
    }

    // 3. Display Songs / Videos
    print('\n--- SONGS / VIDEOS (${search.songs.length} found) ---');
    for (final video in search.songs.take(3)) {
      print('- [Video] "${video.title}" by ${video.author} (duration: ${video.duration}, isLive: ${video.isLive})');
      print('  ID: ${video.videoId}');
      print('  Thumbnail: ${video.thumbnail}');
    }

    // 4. Display Artists / Channels
    print('\n--- ARTISTS / CHANNELS (${search.artists.length} found) ---');
    for (final artist in search.artists.take(3)) {
      print('- [Artist] "${artist.title}" (ID: ${artist.channelId})');
      print('  Thumbnail: ${artist.thumbnail}');
    }

    // 5. Display Albums
    print('\n--- ALBUMS (${search.albums.length} found) ---');
    for (final album in search.albums.take(3)) {
      print('- [Album] "${album.title}" (Playlist ID: ${album.playlistId})');
      print('  Thumbnail: ${album.thumbnail}');
    }

    // 6. Display Playlists
    print('\n--- PLAYLISTS (${search.playlists.length} found) ---');
    for (final playlist in search.playlists.take(3)) {
      print('- [Playlist] "${playlist.title}" (Playlist ID: ${playlist.playlistId})');
      print('  Thumbnail: ${playlist.thumbnail}');
    }

    // 7. Display Broadcasts (Live Streams)
    // To test this better, we'd normally search for a live query, but let's check if there's any in the current query.
    print('\n--- BROADCASTS / LIVE STREAMS (${search.broadcasts.length} found) ---');
    for (final live in search.broadcasts.take(3)) {
      print('- [Live] "${live.title}" by ${live.author}');
      print('  ID: ${live.videoId}');
    }

    // 8. Test Continuation / Paging
    print('\n========================================');
    if (search.hasMoreResults) {
      print('Has more results! Fetching next page...');
      final success = await search.next();
      if (success) {
        print('Successfully fetched next page!');
        print('New Total Results: ${search.results.length}');
        print('New Total Videos: ${search.videos.length}');
      } else {
        print('Failed to fetch next page.');
      }
    } else {
      print('No more pages of results available.');
    }
    print('========================================');

  } catch (e, stack) {
    print('An error occurred during search: $e');
    print(stack);
  }
}
