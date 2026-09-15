# darttubefix

A lightweight, high-performance YouTube and YouTube Music content scraping & extraction library for Dart and Flutter, translated and adapted from the popular Python package [`pytubefix`](https://github.com/JuanBindez/pytubefix).

`darttubefix` allows you to extract video & music metadata, fetch direct playable audio/video stream URLs, perform YouTube & YouTube Music searches, decipher signatures/n-signatures dynamically, download audio/video files, and scrape YouTube Music "Related" content (playlists, similar artists, artist bio) seamlessly in Dart.

> 📖 **Looking for a dedicated guide?** Check out [YOUTUBE_MUSIC_SCRAPING.md](YOUTUBE_MUSIC_SCRAPING.md) for a step-by-step tutorial on scraping YouTube Music directly from links.

---

## Features

- **YouTube Music Scraping**: Scrape song details, artist information, similar artists, recommended playlists, and artist bio.
- **Audio & Video Streams**: Extract direct playable audio stream URLs (M4A/AAC, WebM) and progressive video streams without throttling.
- **Dynamic Signature & N-Sig Decryption**: Built-in dynamic JS runner to decipher YouTube signature and n-signature parameters for 100% playability.
- **Search Engine**: Search for songs, videos, artists/channels, playlists, and albums with built-in pagination support (`next()`).
- **Audio Downloader**: Download high-quality audio files directly to disk with live progress callbacks.
- **Client Fallbacks**: Flexible InnerTube client configurations (`WEB_MUSIC`, `WEB`, `ANDROID_VR`, `TV`, `IOS`, etc.) for maximum uptime.
- **Cross-Platform Support**: Fully compatible with Dart VM, Flutter (Android, iOS, Windows, macOS, Linux), and server-side Dart.

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

## Full Step-by-Step Guide: How to Scrape YouTube Music

Follow these step-by-step instructions to extract tracks, metadata, search results, direct playable audio stream URLs, download audio files, and scrape related YouTube Music recommendations.

### Step 1: Install `darttubefix`

Add the package to your project as shown in the Installation section above.

### Step 2: Search YouTube Music (Songs, Artists, Playlists & Albums)

Use the `Search` class to query YouTube Music and YouTube for content:

```dart
import 'package:darttubefix/darttubefix.dart';

void main() async {
  // Initialize search query
  final search = Search('The Weeknd Blinding Lights');
  
  // Fetch initial results
  await search.fetch();

  print('Found ${search.results.length} results\n');

  // 1. Scrape Tracks / Videos
  print('--- Songs / Videos ---');
  for (final video in search.videos.take(5)) {
    print('Title  : ${video.title}');
    print('ID     : ${video.videoId}');
    print('Author : ${video.author}');
    print('Length : ${video.length} seconds\n');
  }

  // 2. Scrape Artists / Channels
  print('--- Artists ---');
  for (final artist in search.artists) {
    print('Artist Name : ${artist.title}');
    print('Channel ID  : ${artist.channelId}\n');
  }

  // 3. Scrape Playlists & Albums
  print('--- Playlists & Albums ---');
  for (final playlist in search.playlists) {
    print('Playlist Title : ${playlist.title}');
    print('Playlist ID    : ${playlist.playlistId}\n');
  }

  // 4. Pagination - Load next page of search results
  if (search.hasMoreResults) {
    await search.next();
    print('Loaded next page. Total results now: ${search.results.length}');
  }
}
```

---

### Step 3: Extract Track Metadata & Direct Playable Audio Stream URLs

To stream audio directly inside an audio player (e.g. `just_audio`, `audioplayers`, or VLC), extract the audio streams and decrypt the URL:

```dart
import 'package:darttubefix/darttubefix.dart';

void main() async {
  // YouTube Music track URL or Video URL
  final musicUrl = 'https://music.youtube.com/watch?v=4NRXx6U8ABQ';
  final yt = YouTube(musicUrl);

  try {
    // Extract metadata
    final title = await yt.title;
    final author = await yt.author;
    final duration = await yt.length;
    final thumbnail = await yt.thumbnailUrl;

    print('Title     : $title');
    print('Artist    : $author');
    print('Duration  : $duration seconds');
    print('Thumbnail : $thumbnail\n');

    // Fetch stream query with decrypted URLs
    final streams = await yt.streams;

    // Extract high-quality audio stream (M4A / WebM)
    final audioStream = streams.getAudioOnly(subtype: 'mp4') ?? streams.bestAudio;

    if (audioStream != null) {
      print('Audio Stream Format : ${audioStream.mimeType}');
      print('Bitrate             : ${audioStream.abr}');
      print('Direct Playable URL : ${audioStream.url}');
      // You can pass `audioStream.url` directly to your audio player!
    }
  } catch (e) {
    print('Error extracting track: $e');
  }
}
```

---

### Step 4: Download YouTube Music Audio Track to File

Download the extracted audio stream directly to local disk with progress tracking:

```dart
import 'package:darttubefix/darttubefix.dart';

void main() async {
  final yt = YouTube('https://music.youtube.com/watch?v=4NRXx6U8ABQ');
  final streams = await yt.streams;
  final audioStream = streams.getAudioOnly(subtype: 'mp4') ?? streams.bestAudio;

  if (audioStream != null) {
    final filePath = 'downloaded_song.${audioStream.subtype}';

    print('Downloading audio to $filePath...');
    final file = await audioStream.download(
      filePath,
      onProgress: (downloadedBytes, totalBytes) {
        if (totalBytes > 0) {
          final percentage = ((downloadedBytes / totalBytes) * 100).toStringAsFixed(1);
          print('Progress: $percentage% ($downloadedBytes / $totalBytes bytes)');
        }
      },
    );

    print('Download Complete! Saved at: ${file.absolute.path}');
  }
}
```

---

### Step 5: Scrape YouTube Music Related Content & Artist Bio

Scrape the YouTube Music sidebar / watch page metadata: **Recommended Playlists**, **Similar Artists**, **More From Artist**, and **Artist Bio/Description**:

```dart
import 'package:darttubefix/darttubefix.dart';

void main() async {
  final musicUrl = 'https://music.youtube.com/watch?v=y9VW61sgfWQ';

  // Approach 1: Directly using MusicRelated
  final related = MusicRelated(musicUrl);
  await related.fetch();

  // 1. Recommended Playlists
  print('=== Recommended Playlists ===');
  for (final playlist in related.recommendedPlaylists) {
    print('Title       : ${playlist.title}');
    print('Playlist ID : ${playlist.playlistId}');
    print('Thumbnail   : ${playlist.thumbnailUrl}\n');
  }

  // 2. Similar Artists
  print('=== Similar Artists ===');
  for (final artist in related.similarArtists) {
    print('Artist Name : ${artist.title}');
    print('Subscribers : ${artist.subscribers ?? "N/A"}');
    print('Channel ID  : ${artist.channelId}\n');
  }

  // 3. More From Artist
  if (related.moreFromArtist.isNotEmpty) {
    print('=== ${related.moreFromArtistTitle} ===');
    for (final item in related.moreFromArtist) {
      print('Item Title : ${item.title}');
    }
  }

  // 4. Artist Bio / Information
  if (related.aboutArtist != null) {
    print('\n=== About the Artist ===');
    print('Name        : ${related.aboutArtist!.title}');
    print('Description : ${related.aboutArtist!.description}');
  }

  // Approach 2: Via YouTube instance
  final yt = YouTube(musicUrl);
  final musicData = await yt.musicRelated;
  print('\nFound ${musicData.recommendedPlaylists.length} recommended playlists.');
}
```

---

### Step 6: Customizing InnerTube Clients

YouTube uses various API client configurations (`WEB_MUSIC`, `ANDROID_VR`, `TV`, `IOS`, `WEB`). You can specify a custom client if needed:

```dart
import 'package:darttubefix/darttubefix.dart';

void main() async {
  // Use specific client for requests
  final yt = YouTube('https://music.youtube.com/watch?v=4NRXx6U8ABQ', client: 'WEB_MUSIC');
  final title = await yt.title;
  print('Track Title: $title');
}
```

---

## Summary of Scraped YouTube Music Data Fields

| Category | Scraped Data Fields | Class / Method |
| :--- | :--- | :--- |
| **Track Details** | Title, Artist/Author, Duration, Views, Thumbnail URL | `YouTube` instance |
| **Audio Streams** | Direct Playable URL, Bitrate (ABR), Container (MP4/WebM), MIME Type, File Size | `yt.streams` -> `StreamQuery` |
| **Search** | Videos, Songs, Artists, Channels, Playlists, Albums | `Search` class |
| **Playlists** | Title, Playlist ID, Track Count, Thumbnails | `MusicRelated.recommendedPlaylists` |
| **Artists** | Title, Channel ID, Subscriber Count, Thumbnails | `MusicRelated.similarArtists` |
| **Artist Bio** | Description/Bio, Title, Metadata | `MusicRelated.aboutArtist` |

---

## License

Distributed under the [MIT License](LICENSE).
