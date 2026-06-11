import 'package:darttubefix/darttubefix.dart';

void main() async {
  // Use a standard public YouTube video ID
  const videoUrl = 'https://youtu.be/uQ31HRELL04?si=tG50d93kea8zh5zG';
  print('Initializing YouTube object for: $videoUrl');
  final yt = YouTube(videoUrl);

  try {
    print('Fetching title...');
    final title = await yt.title;
    print('Title: $title');

    print('Fetching author...');
    final author = await yt.author;
    print('Author: $author');

    print('Fetching length...');
    final length = await yt.length;
    print('Length: $length seconds');

    print('Fetching streams...');
    final streams = await yt.streams;
    print('Found ${streams.length} streams:');
    
    for (var i = 0; i < streams.length; i++) {
      final s = streams[i];
      print('[Stream $i] itag: ${s.itag}, mime: ${s.mimeType}, progressive: ${s.isProgressive}, res: ${s.resolution}');
      print('  Decrypted URL: ${s.url}');
      print('');
    }
    
    print('Verification finished successfully!');
  } catch (e, stack) {
    print('An error occurred during verification: $e');
    print(stack);
  }
}
