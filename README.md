# darttubefix

A lightweight and powerful YouTube content extraction library for Dart, translated and extracted from the popular Python package `pytubefix`.

`darttubefix` allows you to fetch YouTube video details (title, author, length, streams, etc.) and decrypt signatures and n-signatures for media URLs directly in Dart.

## Features

- **Video Details**: Easily retrieve video metadata such as title, author, length, and thumbnail URL.
- **Stream Extraction**: Extract and group audio and video stream formats (progressive, adaptive, audio-only).
- **Signature & N-Signature Decryption**: Full support for signature and n-signature deciphering utilizing an integrated JavaScript runner.
- **Age-Restricted Video Support**: Fallback mechanisms to extract stream details for age-restricted videos when possible.
- **Client Fallbacks**: Intelligent client-switching support (e.g., ANDROID_VR, IOS, TV, WEB) to ensure media playability.

## Origin

This package is a Dart translation/extraction of the python-based library **[pytubefix](https://github.com/JuanBindez/pytubefix)**. All extraction patterns, InnerTube clients, and signature deciphering mechanics have been ported to Dart to provide a seamless experience on Dart-native and Flutter platforms.

## Getting Started

Add `darttubefix` to your `pubspec.yaml` dependencies:

```yaml
dependencies:
  darttubefix:
    path: . # Or use the Git/Pub package dependency once hosted
```

Run `dart pub get` to install dependencies. Make sure you have **Node.js** installed on your environment, as it is required to execute signature decryption scripts.

## Usage

Here is a simple example showing how to initialize `YouTube` and list available streams:

```dart
import 'package:darttubefix/darttubefix.dart';

void main() async {
  // Initialize the YouTube video instance
  final videoUrl = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
  final yt = YouTube(videoUrl);

  try {
    // Retrieve metadata
    final title = await yt.title;
    final author = await yt.author;
    final duration = await yt.length; // In seconds
    
    print('Title: $title');
    print('Author: $author');
    print('Duration: $duration seconds');

    // Retrieve streams
    final streams = await yt.streams;
    print('Found ${streams.length} streams:');
    
    for (final s in streams) {
      print('itag: ${s.itag}, mime: ${s.mimeType}, resolution: ${s.resolution}');
      print('URL: ${s.url}');
    }
  } catch (e) {
    print('An error occurred: $e');
  }
}
```

## Running the Example

An example file is provided in the repository under `example/darttubefix_example.dart`. You can run it with:

```bash
dart run example/darttubefix_example.dart
```

## Requirements

- **Dart SDK**: `^3.9.0`
- **Node.js**: The library spawns a Node.js process to run the signature/n-signature decryption code dynamically. Ensure `node` is available in your system's PATH.
