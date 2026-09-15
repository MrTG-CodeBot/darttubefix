# Complete Step-by-Step Guide: Scraping YouTube Music from Links

This guide provides a comprehensive, step-by-step walkthrough on how to scrape and extract metadata, playable audio URLs, artist biographies, recommended playlists, and similar artists from **YouTube Music links** using `darttubefix`.

---

## Table of Contents

1. [Understanding YouTube Music Links](#1-understanding-youtube-music-links)
2. [Environment Prerequisites & Setup](#2-environment-prerequisites--setup)
3. [Step 1: Extracting Track Metadata from a Song Link](#step-1-extracting-track-metadata-from-a-song-link)
4. [Step 2: Scraping Direct Playable Audio Stream URLs](#step-2-scraping-direct-playable-audio-stream-urls)
5. [Step 3: Downloading YouTube Music Audio Tracks to Disk](#step-3-downloading-youtube-music-audio-tracks-to-disk)
6. [Step 4: Scraping Related Content (Playlists, Similar Artists, Artist Bio)](#step-4-scraping-related-content-playlists-similar-artists-artist-bio)
7. [Step 5: Scraping Search & Playlist Links](#step-5-scraping-search--playlist-links)
8. [Step 6: Using Custom InnerTube Clients (`WEB_MUSIC`, `ANDROID_VR`)](#step-6-using-custom-innertube-clients-web_music-android_vr)
9. [Complete Ready-to-Run Dart Code Example](#complete-ready-to-run-dart-code-example)
10. [Data Field Reference Table](#data-field-reference-table)

---

## 1. Understanding YouTube Music Links

YouTube Music uses specific link formats for tracks, playlists, artists, and search queries:

- **Track / Song Link**:  
  `https://music.youtube.com/watch?v=y9VW61sgfWQ`  
  Or with playlist context:  
  `https://music.youtube.com/watch?v=y9VW61sgfWQ&list=RDAMVMy9VW61sgfWQ`

- **Playlist Link**:  
  `https://music.youtube.com/playlist?list=RDCLAK5uy_kL15mK-X...`

- **Artist / Channel Link**:  
  `https://music.youtube.com/channel/UCq3WubH...`

`darttubefix` automatically extracts the `videoId` or `playlistId` from any valid standard YouTube or YouTube Music URL.

---

## 2. Environment Prerequisites & Setup

### A. Add Dependency
Add `darttubefix` to your `pubspec.yaml` file:

```yaml
dependencies:
  darttubefix: ^1.0.0
```

Or run:

```bash
dart pub add darttubefix
# or in a Flutter project:
flutter pub add darttubefix
```

### B. JavaScript Engine Requirement (Signature Decryption)
YouTube encrypts playable media stream URLs using dynamic JavaScript cipher functions (`n` parameter and `sig` signature).

- **For Pure Dart (CLI / Backend / Server-side)**: Ensure **Node.js** is installed on your system. Test with `node --version`.
- **For Flutter Apps (Android / iOS / Desktop)**: Use `flutter_js` to run the JS cipher in native C runtimes (QuickJS/JavaScriptCore) without requiring system Node.js.

---

## Step 1: Extracting Track Metadata from a Song Link

To extract track metadata from a link (e.g. title, artist name, duration, thumbnail, view count):

### Code Example:
```dart
import 'package:darttubefix/darttubefix.dart';

void main() async {
  // Input YouTube Music Link
  final musicUrl = 'https://music.youtube.com/watch?v=y9VW61sgfWQ';

  // Create YouTube object from the URL
  final yt = YouTube(musicUrl);

  // Extract Metadata asynchronously
  final title = await yt.title;
  final author = await yt.author;
  final duration = await yt.length; // Duration in seconds
  final thumbnail = await yt.thumbnailUrl;
  final views = await yt.views;
  final videoId = yt.videoId;

  print('=== Track Metadata ===');
  print('Video ID   : $videoId');
  print('Title      : $title');
  print('Artist     : $author');
  print('Duration   : $duration seconds');
  print('Thumbnail  : $thumbnail');
  print('Views      : $views');
}
```

---

## Step 2: Scraping Direct Playable Audio Stream URLs

YouTube Music streams are available in formats like **M4A (AAC)** and **WebM (Opus)**. `darttubefix` deciphers the signatures dynamically to give you direct HTTP URLs that can be passed straight to audio players (e.g., `just_audio`, `audioplayers`, VLC).

### Code Example:
```dart
import 'package:darttubefix/darttubefix.dart';

void main() async {
  final musicUrl = 'https://music.youtube.com/watch?v=y9VW61sgfWQ';
  final yt = YouTube(musicUrl);

  // Fetch playable streams query
  final StreamQuery streams = await yt.streams;

  // 1. Get all audio-only streams
  final List<StreamData> audioStreams = streams.audioOnly.fmtStreams;
  print('Found ${audioStreams.length} audio streams.\n');

  for (final stream in audioStreams) {
    print('ITAG     : ${stream.itag}');
    print('Format   : ${stream.mimeType}');
    print('Bitrate  : ${stream.abr}');
    print('URL      : ${stream.url}\n');
  }

  // 2. Select the best audio stream or specific subtype (e.g., MP4/M4A)
  final StreamData? bestAudio = streams.getAudioOnly(subtype: 'mp4') ?? streams.bestAudio;

  if (bestAudio != null) {
    print('=== Selected Playable Stream ===');
    print('Bitrate  : ${bestAudio.abr}');
    print('MIME     : ${bestAudio.mimeType}');
    print('Direct Playable Link: ${bestAudio.url}');
  }
}
```

---

## Step 3: Downloading YouTube Music Audio Tracks to Disk

You can download the extracted audio stream directly to local storage with progress reporting:

### Code Example:
```dart
import 'dart:io';
import 'package:darttubefix/darttubefix.dart';

void main() async {
  final musicUrl = 'https://music.youtube.com/watch?v=y9VW61sgfWQ';
  final yt = YouTube(musicUrl);

  final streams = await yt.streams;
  final bestAudio = streams.getAudioOnly(subtype: 'mp4') ?? streams.bestAudio;

  if (bestAudio != null) {
    final savePath = 'downloaded_song.${bestAudio.subtype}';
    print('Downloading song to $savePath...');

    final File downloadedFile = await bestAudio.download(
      savePath,
      onProgress: (downloadedBytes, totalBytes) {
        if (totalBytes > 0) {
          final percent = ((downloadedBytes / totalBytes) * 100).toStringAsFixed(1);
          print('Download Progress: $percent% ($downloadedBytes / $totalBytes bytes)');
        }
      },
    );

    print('Download Complete!');
    print('File saved at: ${downloadedFile.absolute.path}');
  }
}
```

---

## Step 4: Scraping Related Content (Playlists, Similar Artists, Artist Bio)

YouTube Music watch pages contain a "Related" section with:
1. **Recommended Playlists**
2. **Similar Artists**
3. **More Releases / More From Artist**
4. **About the Artist (Biography & Description)**

Use `MusicRelated(musicUrl)` or `yt.musicRelated` to scrape this data directly from a song link:

### Code Example:
```dart
import 'package:darttubefix/darttubefix.dart';

void main() async {
  final musicUrl = 'https://music.youtube.com/watch?v=y9VW61sgfWQ';

  // Instantiate MusicRelated with the link
  final related = MusicRelated(musicUrl);

  // Fetch the related data from YouTube Music InnerTube API
  await related.fetch();

  // 1. Recommended Playlists
  print('=== Recommended Playlists ===');
  for (final playlist in related.recommendedPlaylists) {
    print('Playlist Title : ${playlist.title}');
    print('Playlist ID    : ${playlist.playlistId}');
    print('Thumbnail      : ${playlist.thumbnail}');
    print('Subtitle       : ${playlist.subtitle ?? "N/A"}\n');
  }

  // 2. Similar Artists
  print('=== Similar Artists ===');
  for (final artist in related.similarArtists) {
    print('Artist Name : ${artist.title}');
    print('Channel ID  : ${artist.channelId}');
    print('Subscribers : ${artist.subscribers ?? "N/A"}');
    print('Thumbnail   : ${artist.thumbnail}\n');
  }

  // 3. More From Artist
  if (related.moreFromArtist.isNotEmpty) {
    print('=== ${related.moreFromArtistTitle} ===');
    for (final item in related.moreFromArtist) {
      print('Item Title : ${item.title}');
      print('Video ID   : ${item.videoId ?? "N/A"}');
      print('Playlist ID: ${item.playlistId ?? "N/A"}\n');
    }
  }

  // 4. Artist Biography / About Section
  if (related.aboutArtist != null) {
    print('=== About the Artist ===');
    print('Header      : ${related.aboutArtist!.title}');
    print('Subheader   : ${related.aboutArtist!.subheader ?? ""}');
    print('Description : ${related.aboutArtist!.description}');
  }
}
```

---

## Step 5: Scraping Search & Playlist Links

### A. Searching YouTube Music
You can scrape search results (Videos, Songs, Artists, Channels, Playlists, Albums):

```dart
import 'package:darttubefix/darttubefix.dart';

void main() async {
  final search = Search('Coldplay Viva La Vida');
  await search.fetch();

  // Songs/Videos
  for (final track in search.videos.take(5)) {
    print('Track: ${track.title} (ID: ${track.videoId})');
  }

  // Artists
  for (final artist in search.artists) {
    print('Artist: ${artist.title} (Channel ID: ${artist.channelId})');
  }

  // Playlists
  for (final playlist in search.playlists) {
    print('Playlist: ${playlist.title} (Playlist ID: ${playlist.playlistId})');
  }

  // Load next page of search results
  if (search.hasMoreResults) {
    await search.next();
  }
}
```

---

## Step 6: Using Custom InnerTube Clients (`WEB_MUSIC`, `ANDROID_VR`)

`darttubefix` allows configuring specific InnerTube clients if needed (e.g. `WEB_MUSIC`, `ANDROID_VR`, `TV`, `IOS`, `WEB`):

```dart
import 'package:darttubefix/darttubefix.dart';

void main() async {
  // Pass YouTube Music client explicitly
  final yt = YouTube('https://music.youtube.com/watch?v=y9VW61sgfWQ', client: 'WEB_MUSIC');
  
  final title = await yt.title;
  print('Track Title: $title');
}
```

---

## Complete Ready-to-Run Dart Code Example

Here is a full Dart program that takes a YouTube Music URL and scrapes **everything**: metadata, playable stream links, recommended playlists, similar artists, and artist bio in one script:

```dart
import 'package:darttubefix/darttubefix.dart';

void main() async {
  final musicUrl = 'https://music.youtube.com/watch?v=y9VW61sgfWQ';
  print('Scraping YouTube Music link: $musicUrl\n');

  final yt = YouTube(musicUrl);

  try {
    // 1. Track Metadata
    print('--------------------------------------------------');
    print(' 1. TRACK METADATA');
    print('--------------------------------------------------');
    print('Title     : ${await yt.title}');
    print('Artist    : ${await yt.author}');
    print('Duration  : ${await yt.length} seconds');
    print('Thumbnail : ${await yt.thumbnailUrl}');
    print('Views     : ${await yt.views}\n');

    // 2. Audio Streams
    print('--------------------------------------------------');
    print(' 2. PLAYABLE AUDIO STREAMS');
    print('--------------------------------------------------');
    final streams = await yt.streams;
    final bestAudio = streams.getAudioOnly(subtype: 'mp4') ?? streams.bestAudio;

    if (bestAudio != null) {
      print('Playable Audio Bitrate : ${bestAudio.abr}');
      print('MIME Type              : ${bestAudio.mimeType}');
      print('Direct Playable Link   : ${bestAudio.url}\n');
    }

    // 3. Related YouTube Music Content
    print('--------------------------------------------------');
    print(' 3. YOUTUBE MUSIC RELATED DATA');
    print('--------------------------------------------------');
    final related = MusicRelated(musicUrl);
    await related.fetch();

    print('Recommended Playlists Count : ${related.recommendedPlaylists.length}');
    for (final p in related.recommendedPlaylists.take(3)) {
      print(' - Playlist: ${p.title} (${p.playlistId})');
    }

    print('\nSimilar Artists Count       : ${related.similarArtists.length}');
    for (final a in related.similarArtists.take(3)) {
      print(' - Artist: ${a.title} (${a.channelId})');
    }

    if (related.aboutArtist != null) {
      print('\nArtist Bio:');
      print(related.aboutArtist!.description);
    }

    print('\n[SUCCESS] Scraping completed successfully!');
  } catch (e, stack) {
    print('Scraping failed: $e');
    print(stack);
  }
}
```

---

## Data Field Reference Table

| Scraped Property | Object | Data Type | Description |
| :--- | :--- | :--- | :--- |
| `yt.title` | `YouTube` | `Future<String>` | Track/Song title |
| `yt.author` | `YouTube` | `Future<String>` | Artist name |
| `yt.length` | `YouTube` | `Future<int>` | Duration in seconds |
| `yt.thumbnailUrl` | `YouTube` | `Future<String>` | High-res cover image URL |
| `yt.views` | `YouTube` | `Future<int>` | Total view count |
| `audioStream.url` | `StreamData` | `String` | Direct deciphered playable media URL |
| `audioStream.abr` | `StreamData` | `String?` | Average Bitrate (e.g. `128kbps`) |
| `related.recommendedPlaylists` | `MusicRelated` | `List<RelatedPlaylist>` | Recommended playlists shelf |
| `related.similarArtists` | `MusicRelated` | `List<RelatedArtist>` | Similar artists shelf |
| `related.moreFromArtist` | `MusicRelated` | `List<RelatedItem>` | Releases shelf by the same artist |
| `related.aboutArtist` | `MusicRelated` | `AboutArtist?` | Artist description & bio details |
| `search.videos` | `Search` | `List<Video>` | Song / Video search results |
| `search.artists` | `Search` | `List<Artist>` | Artist search results |
| `search.playlists` | `Search` | `List<Playlist>` | Playlist search results |

---

*This guide was created for `darttubefix`. Distributed under the [MIT License](LICENSE).*
