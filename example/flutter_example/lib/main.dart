import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:darttubefix/darttubefix.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const DartTubeFixApp());
}

class DartTubeFixApp extends StatelessWidget {
  const DartTubeFixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'darttubefix Tester',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF0000),
          brightness: Brightness.dark,
          primary: const Color(0xFFFF0000),
          surface: const Color(0xFF1E1E1E),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardTheme: const CardThemeData(
          color: Color(0xFF1E1E1E),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController(
    text: 'https://www.youtube.com/watch?v=-mpP5nkKolc',
  );

  bool _isLoading = false;
  String? _errorMessage;
  StreamQuery? _streamQuery;

  // Extracted Video Info
  String _videoTitle = '';
  String _videoAuthor = '';
  int _videoLength = 0;
  String _videoThumbnail = '';

  // Downloaded files map (itag -> filePath)
  final Map<int, String> _downloadedFilePaths = {};

  // Downloading state
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  String? _activeDownloadingItag;

  // Cache & Play Audio Player State
  AudioPlayer? _audioPlayer;
  bool _isBufferingAndPlaying = false;
  double _bufferProgress = 0.0;
  String? _bufferingItag;
  File? _activeCachedFile;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  String _nowPlayingTitle = '';

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initAudioPlayerListeners();
    _fetchVideoInfo();
  }

  void _initAudioPlayerListeners() {
    try {
      _audioPlayer = AudioPlayer();
      _audioPlayer!.onPositionChanged.listen((pos) {
        if (mounted) {
          setState(() {
            _currentPosition = pos;
          });
        }
      });

      _audioPlayer!.onDurationChanged.listen((dur) {
        if (mounted) {
          setState(() {
            _totalDuration = dur;
          });
        }
      });

      _audioPlayer!.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state == PlayerState.playing;
          });
        }
      });

      _audioPlayer!.onPlayerComplete.listen((_) async {
        await _stopAndCleanupCache();
      });
    } catch (_) {
      _audioPlayer = null;
    }
  }

  @override
  void dispose() {
    _stopAndCleanupCache();
    _audioPlayer?.dispose();
    _urlController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _stopAndCleanupCache() async {
    try {
      await _audioPlayer?.stop();
    } catch (_) {}

    if (_activeCachedFile != null) {
      try {
        if (await _activeCachedFile!.exists()) {
          await _activeCachedFile!.delete();
        }
      } catch (_) {}
      _activeCachedFile = null;
    }
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _isBufferingAndPlaying = false;
        _bufferingItag = null;
        _currentPosition = Duration.zero;
        _totalDuration = Duration.zero;
      });
    }
  }

  Future<void> _fetchVideoInfo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final yt = YouTube(url);
      final query = await yt.streams;
      final title = await yt.title;
      final author = await yt.author;
      final length = await yt.length;
      final thumbnail = await yt.thumbnailUrl;

      if (mounted) {
        setState(() {
          _streamQuery = query;
          _videoTitle = title;
          _videoAuthor = author;
          _videoLength = length;
          _videoThumbnail = thumbnail;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Buffers the stream into temporary cache directory, plays it, and deletes on stop.
  Future<void> _playStreamFromCache(Stream stream) async {
    await _stopAndCleanupCache();

    setState(() {
      _isBufferingAndPlaying = true;
      _bufferProgress = 0.0;
      _bufferingItag = stream.itag.toString();
      _nowPlayingTitle = 'itag ${stream.itag} (${stream.mimeType})';
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final cacheFilename = 'cache_play_${stream.itag}_${DateTime.now().millisecondsSinceEpoch}.${stream.subtype}';
      final cachePath = '${tempDir.path}${Platform.pathSeparator}$cacheFilename';

      final file = await stream.download(
        cachePath,
        onProgress: (downloaded, total) {
          if (mounted) {
            setState(() {
              _bufferProgress = total > 0 ? downloaded / total : 0.0;
            });
          }
        },
      );

      _activeCachedFile = file;

      if (_audioPlayer != null) {
        try {
          await _audioPlayer!.play(DeviceFileSource(file.path));
          if (mounted) {
            setState(() {
              _isBufferingAndPlaying = false;
              _isPlaying = true;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Playing itag ${stream.itag} (Cached & ready)'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
            return;
          }
        } catch (_) {}
      }

      // Fallback if in-app player plugin channel is not registered
      if (mounted) {
        setState(() {
          _isBufferingAndPlaying = false;
        });
        await _launchFile(file.path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Opened cached stream in media player! (Restart "flutter run" for in-app player)'),
              backgroundColor: Colors.blue,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      await _stopAndCleanupCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cache & Play failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _downloadStream(Stream stream) async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadedBytes = 0;
      _totalBytes = stream.filesize;
      _activeDownloadingItag = stream.itag.toString();
    });

    try {
      final dir = await getApplicationDocumentsDirectory();
      final filename = 'darttubefix_${stream.itag}.${stream.subtype}';
      final savePath = '${dir.path}${Platform.pathSeparator}$filename';

      final file = await stream.download(
        savePath,
        onProgress: (downloaded, total) {
          if (mounted) {
            setState(() {
              _downloadedBytes = downloaded;
              _totalBytes = total;
              _downloadProgress = total > 0 ? downloaded / total : 0.0;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadedFilePaths[stream.itag] = file.path;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded successfully to ${file.path}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _launchFile(String filePath) async {
    final uri = Uri.file(filePath);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: $filePath')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.play_circle_fill, color: Color(0xFFFF0000), size: 28),
            SizedBox(width: 8),
            Text('darttubefix Tester', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Input Section
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E1E1E),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        decoration: InputDecoration(
                          hintText: 'Enter YouTube URL or Video ID',
                          prefixIcon: const Icon(Icons.link, color: Colors.redAccent),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF2A2A2A),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (_) => _fetchVideoInfo(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _fetchVideoInfo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF0000),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Fetch', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Quick sample buttons
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text('Quick Test: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      _presetChip('Sample Video', 'https://www.youtube.com/watch?v=-mpP5nkKolc'),
                      _presetChip('Shorts', 'https://www.youtube.com/shorts/dQw4w9WgXcQ'),
                      _presetChip('Lofi Beats', 'https://www.youtube.com/watch?v=jfKfPfyJRdk'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Body
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFFFF0000)),
                        SizedBox(height: 16),
                        Text('Extracting YouTube Stream Metadata...'),
                      ],
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                              const SizedBox(height: 12),
                              Text(
                                'Error: $_errorMessage',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _fetchVideoInfo,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _streamQuery == null
                        ? const Center(child: Text('Enter a video URL to begin'))
                        : _buildVideoContent(),
          ),

          // In-App Cache Audio Player Bar
          if (_isPlaying || _isBufferingAndPlaying || _activeCachedFile != null)
            _buildInAppAudioPlayerBar(),

          // Downloading Progress Bar Footer
          if (_isDownloading) _buildDownloadProgressFooter(),
        ],
      ),
    );
  }

  Widget _presetChip(String label, String url) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        backgroundColor: const Color(0xFF2C2C2C),
        side: BorderSide.none,
        onPressed: () {
          _urlController.text = url;
          _fetchVideoInfo();
        },
      ),
    );
  }

  Widget _buildVideoContent() {
    final minutes = _videoLength ~/ 60;
    final seconds = _videoLength % 60;
    final durationStr = '${minutes}m ${seconds}s';

    return Column(
      children: [
        // Video Header Info
        Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_videoThumbnail.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _videoThumbnail,
                      width: 110,
                      height: 70,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 110,
                        height: 70,
                        color: Colors.grey[800],
                        child: const Icon(Icons.movie),
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _videoTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(_videoAuthor, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.timer, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(durationStr, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Stream Selector Tabs
        Container(
          color: const Color(0xFF1E1E1E),
          child: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFFFF0000),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Audio (${_streamQuery?.audioOnly.fmtStreams.length ?? 0})'),
              Tab(text: 'Progressive (${_streamQuery?.progressiveStreams.fmtStreams.length ?? 0})'),
              Tab(text: 'All Playable (${_streamQuery?.allPlayable.fmtStreams.length ?? 0})'),
            ],
          ),
        ),

        // Stream Lists
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildStreamList(_streamQuery?.audioOnly.fmtStreams ?? []),
              _buildStreamList(_streamQuery?.progressiveStreams.fmtStreams ?? []),
              _buildStreamList(_streamQuery?.allPlayable.fmtStreams ?? []),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStreamList(List<Stream> streams) {
    if (streams.isEmpty) {
      return const Center(child: Text('No streams available in this category'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: streams.length,
      itemBuilder: (context, index) {
        final s = streams[index];
        final isAudio = s.type == 'audio';
        final isProgressive = s.isProgressive;
        final sizeMb = (s.filesize / (1024 * 1024)).toStringAsFixed(2);
        final isCurrentBuffering = _isBufferingAndPlaying && _bufferingItag == s.itag.toString();

        final badgeColor = isProgressive
            ? Colors.green
            : isAudio
                ? Colors.blue
                : Colors.purple;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: badgeColor, width: 1),
                      ),
                      child: Text(
                        'itag ${s.itag}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${s.mimeType}${s.resolution != null ? ' (${s.resolution})' : ''}${s.abr != null ? ' ${s.abr}' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    if (s.filesize > 0)
                      Text('$sizeMb MB', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Codecs: ${s.codecs.join(', ')}',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Stream & Play (Cache and Play with auto cleanup)
                    ElevatedButton.icon(
                      onPressed: isCurrentBuffering ? null : () => _playStreamFromCache(s),
                      icon: isCurrentBuffering
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.play_arrow, size: 14),
                      label: Text(
                        isCurrentBuffering
                            ? 'Buffering (${(_bufferProgress * 100).toStringAsFixed(0)}%)'
                            : 'Stream & Play',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Copy URL Button
                    OutlinedButton.icon(
                      onPressed: () => _copyToClipboard(s.url, 'Stream URL'),
                      icon: const Icon(Icons.copy, size: 14),
                      label: const Text('Copy URL', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),

                    // Play Saved File Button (If downloaded permanently)
                    if (_downloadedFilePaths.containsKey(s.itag)) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _launchFile(_downloadedFilePaths[s.itag]!),
                        icon: const Icon(Icons.folder_open, size: 14),
                        label: const Text('Saved File', style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],

                    const Spacer(),

                    // Permanent Download Button
                    ElevatedButton.icon(
                      onPressed: _isDownloading ? null : () => _downloadStream(s),
                      icon: const Icon(Icons.download, size: 14),
                      label: Text(
                        _isDownloading && _activeDownloadingItag == s.itag.toString()
                            ? '${(_downloadProgress * 100).toStringAsFixed(0)}%'
                            : 'Save File',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF0000),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInAppAudioPlayerBar() {
    final posSec = _currentPosition.inSeconds;
    final durSec = _totalDuration.inSeconds > 0 ? _totalDuration.inSeconds : 1;
    final posStr = '${_currentPosition.inMinutes}:${(_currentPosition.inSeconds % 60).toString().padLeft(2, '0')}';
    final durStr = '${_totalDuration.inMinutes}:${(_totalDuration.inSeconds % 60).toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF1E2A38),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.music_note, color: Colors.greenAccent, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _videoTitle.isNotEmpty ? _videoTitle : _nowPlayingTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      _isBufferingAndPlaying
                          ? 'Buffering to cache (${(_bufferProgress * 100).toStringAsFixed(0)}%)...'
                          : 'Cached Streaming • Auto-deletes on stop',
                      style: TextStyle(
                        color: _isBufferingAndPlaying ? Colors.orangeAccent : Colors.greenAccent,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 32),
                color: Colors.greenAccent,
                onPressed: () async {
                  if (_isPlaying) {
                    await _audioPlayer?.pause();
                  } else {
                    await _audioPlayer?.resume();
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey, size: 24),
                onPressed: _stopAndCleanupCache,
                tooltip: 'Stop & Clear Cache',
              ),
            ],
          ),
          if (!_isBufferingAndPlaying && _totalDuration.inSeconds > 0)
            Row(
              children: [
                Text(posStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: posSec.toDouble().clamp(0.0, durSec.toDouble()),
                      max: durSec.toDouble(),
                      activeColor: Colors.greenAccent,
                      inactiveColor: Colors.grey[700],
                      onChanged: (val) {
                        _audioPlayer?.seek(Duration(seconds: val.toInt()));
                      },
                    ),
                  ),
                ),
                Text(durStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDownloadProgressFooter() {
    final percentStr = (_downloadProgress * 100).toStringAsFixed(1);
    final downloadedMb = (_downloadedBytes / (1024 * 1024)).toStringAsFixed(2);
    final totalMb = (_totalBytes / (1024 * 1024)).toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF252525),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Saving stream (itag $_activeDownloadingItag)...',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Text(
                '$downloadedMb / $totalMb MB ($percentStr%)',
                style: const TextStyle(fontSize: 11, color: Colors.redAccent),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: _downloadProgress > 0 ? _downloadProgress : null,
            color: const Color(0xFFFF0000),
            backgroundColor: Colors.grey[800],
          ),
        ],
      ),
    );
  }
}
