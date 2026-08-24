# darttubefix

A lightweight and powerful YouTube and YouTube Music content extraction library for Dart and Flutter, translated and adapted from the popular Python package [`pytubefix`](https://github.com/JuanBindez/pytubefix).

`darttubefix` allows you to extract video metadata, stream URLs, perform YouTube searches, decipher signatures/n-signatures dynamically, and extract YouTube Music "Related" content (playlists, similar artists, artist bio) seamlessly in Dart.

---

## Features

- **Video Details & Streams**: Retrieve video title, author, length, thumbnails, and audio/video stream formats (progressive, adaptive, audio-only).
- **Signature & N-Signature Decryption**: Built-in dynamic JS runner to decipher YouTube signature and n-signature parameters for playability.
- **YouTube Search**: Search for videos, songs, artists/channels, playlists, and albums with support for pagination (`next()`).
- **YouTube Music Related Content**: Fetch "Recommended playlists", "Similar artists", "MORE FROM Artist", and "About the artist" details for any YouTube Music track or video.
- **Client Fallbacks**: Intelligent InnerTube client fallbacks (`WEB`, `WEB_MUSIC`, `ANDROID_VR`, `TV`, `IOS`, etc.) for maximum availability.
- **Cross-Platform**: Fully compatible with Dart VM, Flutter (Android, iOS, Desktop), and server-side Dart.

---

## Prerequisites

By default in a pure Dart VM environment, make sure you have **Node.js** installed on your system, as it is required by the JavaScript runner to execute signature decryption algorithms dynamically. Verify Node installation:

```bash
node --version
```

### Using `flutter_js` without Node.js

> **Q: If Node.js is not installed on the system, is it possible/okay to use `flutter_js`?**

Yes, it is completely fine and recommended to use `flutter_js` without installing Node.js on your system.

Instead of spawning an external CLI tool like Node.js, `flutter_js` bundles lightweight, native C-based JavaScript runtimes directly into your app binary via Dart FFI (using **QuickJS** on Android/Desktop and **JavaScriptCore** on iOS).

#### Key Trade-offs & Notes:
- **SDK Dependency**: Adding `flutter_js` requires the Flutter SDK (`darttubefix` becomes a Flutter package rather than a pure Dart VM package).
- **Platform Support**: Works seamlessly on Android, iOS, Windows, macOS, and Linux out of the box without requiring end-users or developers to install any background runtimes like Node.js.

If your primary focus is supporting Flutter mobile apps (Android & iOS), integrating `flutter_js` is the easiest path to eliminate the system Node.js requirement.

---

## Installation

Add `darttubefix` to your `pubspec.yaml`:

```yaml
dependencies:
  darttubefix: ^1.0.0
```

Or install it via terminal:

```bash
dart pub add darttubefix
```

---

## Code Examples

### 1. Fetching Video Details & Streams

```dart
import 'package:darttubefix/darttubefix.dart';

void main() async {
  final yt = YouTube('https://www.youtube.com/watch?v=dQw4w9WgXcQ');

  try {
    // Retrieve video metadata
    final title = await yt.title;
    final author = await yt.author;
    final duration = await yt.length; // Duration in seconds
    final thumbnail = await yt.thumbnailUrl;

    print('Title: $title');
    print('Author: $author');
    print('Duration: $duration seconds');
    print('Thumbnail: $thumbnail');

    // Retrieve stream query
    final streams = await yt.streams;

    // Filter audio-only or highest resolution streams
    final audioStream = streams.getAudioOnly();
    final highestRes = streams.highestResolution;

    print('Audio Stream URL: ${audioStream?.url}');
    print('Highest Res Stream (${highestRes?.resolution}): ${highestRes?.url}');
  } catch (e) {
    print('Error: $e');
  }
}
```

---

### 2. Searching YouTube (Videos, Artists, Playlists & Albums)

```dart
import 'package:darttubefix/darttubefix.dart';

void main() async {
  final search = Search('Taylor Swift');
  await search.fetch();

  // Search Results
  print('Total Results: ${search.results.length}');

  // Videos & Songs
  for (final video in search.videos.take(5)) {
    print('Video: ${video.title} (ID: ${video.videoId}, Author: ${video.author})');
  }

  // Channels / Artists
  for (final artist in search.artists) {
    print('Artist: ${artist.title} (ID: ${artist.channelId})');
  }

  // Playlists & Albums
  for (final playlist in search.playlists) {
    print('Playlist: ${playlist.title} (ID: ${playlist.playlistId})');
  }

  // Pagination - Load next page of search results
  if (search.hasMoreResults) {
    await search.next();
    print('Loaded next page. New total: ${search.results.length}');
  }
}
```

---

### 3. YouTube Music Related Content (Song Detail Page)

Extract "Recommended Playlists", "Similar Artists", "MORE FROM Artist", and "About the artist" section details from any YouTube Music watch page (`https://music.youtube.com/watch?v=...`):

```dart
import 'package:darttubefix/darttubefix.dart';

void main() async {
  final musicUrl = 'https://music.youtube.com/watch?v=y9VW61sgfWQ&list=RDAMVMy9VW61sgfWQ';

  // Option 1: Direct MusicRelated instance
  final related = MusicRelated(musicUrl);
  await related.fetch();

  // Recommended Playlists
  print('--- Recommended Playlists ---');
  for (final playlist in related.recommendedPlaylists) {
    print('Playlist: ${playlist.title} (ID: ${playlist.playlistId})');
  }

  // Similar Artists
  print('\n--- Similar Artists ---');
  for (final artist in related.similarArtists) {
    print('Artist: ${artist.title} (${artist.subscribers ?? ''})');
  }

  // More From Artist (if available)
  if (related.moreFromArtist.isNotEmpty) {
    print('\n--- ${related.moreFromArtistTitle} ---');
    for (final item in related.moreFromArtist) {
      print('Item: ${item.title}');
    }
  }

  // About Artist (if available)
  if (related.aboutArtist != null) {
    print('\n--- ${related.aboutArtist!.title} ---');
    print('Bio: ${related.aboutArtist!.description}');
  }

  // Option 2: Access via YouTube instance
  final yt = YouTube(musicUrl);
  final musicData = await yt.musicRelated;
  print('\nRecommended playlists count: ${musicData.recommendedPlaylists.length}');
}
```

---

### 4. Customizing InnerTube Clients

You can specify different InnerTube clients (`ANDROID_VR`, `WEB`, `WEB_MUSIC`, `TV`, `IOS`, `MWEB`) if needed:

```dart
import 'package:darttubefix/darttubefix.dart';

void main() async {
  // Use specific InnerTube client
  final yt = YouTube('https://www.youtube.com/watch?v=dQw4w9WgXcQ', client: 'TV');
  final title = await yt.title;
  print('Title: $title');
}
```

---

## License

Distributed under the [MIT License](LICENSE).
