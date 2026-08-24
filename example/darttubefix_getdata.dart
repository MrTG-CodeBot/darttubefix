import 'package:darttubefix/darttubefix.dart';

void main() async {
  final sampleUrl = 'https://music.youtube.com/watch?v=mpP5nkKolc';

  // Option 1: Direct MusicRelated instance
  final related = MusicRelated(sampleUrl);
  await related.fetch();

  // Recommended Playlists
  for (final playlist in related.recommendedPlaylists) {
    print('Playlist: ${playlist.title} (${playlist.playlistId})');
  }

  // Similar Artists
  for (final artist in related.similarArtists) {
    print('Artist: ${artist.title} (${artist.channelId})');
  }

  // More From Artist (if available)
  if (related.moreFromArtist.isNotEmpty) {
    print('Header: ${related.moreFromArtistTitle}');
    for (final item in related.moreFromArtist) {
      print('Item: ${item.title}');
    }
  }

  // About Artist (if available)
  if (related.aboutArtist != null) {
    print('Bio: ${related.aboutArtist!.description}');
  }

  // Option 2: Via YouTube class
  final yt = YouTube(sampleUrl);
  final musicRelatedData = await yt.musicRelated;
  print(musicRelatedData.recommendedPlaylists);
}
