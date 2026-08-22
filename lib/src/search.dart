import 'innertube.dart';

abstract class SearchResult {
  final String title;
  final String thumbnail;

  SearchResult({
    required this.title,
    required this.thumbnail,
  });
}

class SearchVideo extends SearchResult {
  final String videoId;
  final String author;
  final String? duration;
  final bool isLive;

  SearchVideo({
    required String title,
    required String thumbnail,
    required this.videoId,
    required this.author,
    this.duration,
    required this.isLive,
  }) : super(title: title, thumbnail: thumbnail);

  @override
  String toString() {
    return 'SearchVideo(videoId: $videoId, title: $title, author: $author, duration: $duration, isLive: $isLive)';
  }
}

class SearchChannel extends SearchResult {
  final String channelId;

  SearchChannel({
    required String title,
    required String thumbnail,
    required this.channelId,
  }) : super(title: title, thumbnail: thumbnail);

  @override
  String toString() {
    return 'SearchChannel(channelId: $channelId, title: $title)';
  }
}

class SearchPlaylist extends SearchResult {
  final String playlistId;

  SearchPlaylist({
    required String title,
    required String thumbnail,
    required this.playlistId,
  }) : super(title: title, thumbnail: thumbnail);

  @override
  String toString() {
    return 'SearchPlaylist(playlistId: $playlistId, title: $title)';
  }
}

class Search {
  final String query;
  final InnerTube _innertube;
  
  final List<SearchResult> _results = [];
  final List<SearchVideo> _videos = [];
  final List<SearchChannel> _artists = [];
  final List<SearchPlaylist> _playlists = [];
  final List<SearchPlaylist> _albums = [];
  final List<SearchVideo> _broadcasts = [];

  String? _continuationToken;
  bool _hasFetched = false;

  Search(this.query, {String client = 'WEB'})
      : _innertube = InnerTube(clientName: client);

  List<SearchResult> get results {
    _ensureFetched();
    return _results;
  }

  List<SearchVideo> get videos {
    _ensureFetched();
    return _videos;
  }

  List<SearchVideo> get songs {
    _ensureFetched();
    return _videos; // On standard YouTube, songs are retrieved as videos
  }

  List<SearchChannel> get artists {
    _ensureFetched();
    return _artists;
  }

  List<SearchPlaylist> get playlists {
    _ensureFetched();
    return _playlists;
  }

  List<SearchPlaylist> get albums {
    _ensureFetched();
    return _albums;
  }

  List<SearchVideo> get broadcasts {
    _ensureFetched();
    return _broadcasts;
  }

  SearchResult? get topResult {
    _ensureFetched();
    return _results.isNotEmpty ? _results.first : null;
  }

  bool get hasMoreResults => _continuationToken != null;

  Future<void> fetch() async {
    if (_hasFetched) return;
    final response = await _innertube.search(query);
    _parseResponse(response);
    _hasFetched = true;
  }

  Future<bool> next() async {
    if (_continuationToken == null) return false;
    final response = await _innertube.search(query, continuation: _continuationToken);
    _parseResponse(response);
    return true;
  }

  void _ensureFetched() {
    if (!_hasFetched) {
      throw StateError('Search results have not been fetched yet. Call fetch() first.');
    }
  }

  void _addResult(SearchResult result) {
    _results.add(result);
    if (result is SearchVideo) {
      if (result.isLive) {
        _broadcasts.add(result);
      } else {
        _videos.add(result);
      }
    } else if (result is SearchChannel) {
      _artists.add(result);
    } else if (result is SearchPlaylist) {
      // Album playlist IDs start with OLAK5uy_, or titles containing "album" (case-insensitive)
      if (result.playlistId.startsWith('OLAK5uy_') || result.title.toLowerCase().contains('album')) {
        _albums.add(result);
      } else {
        _playlists.add(result);
      }
    }
  }

  void _parseResponse(Map<String, dynamic> parsed) {
    List? items;

    final contents = parsed['contents'] as Map?;
    if (contents != null) {
      final resultsList = contents['twoColumnSearchResultsRenderer']?['primaryContents']?['sectionListRenderer']?['contents'] as List?;
      if (resultsList != null) {
        for (final section in resultsList) {
          if (section is Map && section.containsKey('itemSectionRenderer')) {
            final sectItems = section['itemSectionRenderer']?['contents'] as List?;
            if (sectItems != null) {
              items ??= [];
              items.addAll(sectItems);
            }
          }
        }
      }
    }

    // Check for continuation commands
    final commands = parsed['onResponseReceivedCommands'] as List?;
    if (commands != null) {
      for (final cmd in commands) {
        if (cmd is Map && cmd.containsKey('appendContinuationItemsAction')) {
          final action = cmd['appendContinuationItemsAction'] as Map;
          final continuationItems = action['continuationItems'] as List?;
          if (continuationItems != null) {
            items ??= [];
            items.addAll(continuationItems);
          }
        }
      }
    }

    if (items == null) return;

    // Extract continuation token
    _continuationToken = _extractContinuationToken(parsed, items);

    // Parse items
    for (final item in items) {
      if (item is Map) {
        if (item.containsKey('shelfRenderer')) {
          final shelf = item['shelfRenderer'] as Map;
          final shelfContents = shelf['content']?['verticalListRenderer']?['contents'] as List? ??
                                shelf['content']?['horizontalListRenderer']?['items'] as List?;
          if (shelfContents != null) {
            for (final sItem in shelfContents) {
              if (sItem is Map) {
                final result = _parseRenderer(sItem);
                if (result != null) {
                  _addResult(result);
                }
              }
            }
          }
        } else {
          final result = _parseRenderer(item);
          if (result != null) {
            _addResult(result);
          }
        }
      }
    }
  }

  String? _extractContinuationToken(Map parsed, List items) {
    final contents = parsed['contents'] as Map?;
    if (contents != null) {
      final resultsList = contents['twoColumnSearchResultsRenderer']?['primaryContents']?['sectionListRenderer']?['contents'] as List?;
      if (resultsList != null) {
        for (final section in resultsList) {
          if (section is Map && section.containsKey('continuationItemRenderer')) {
            final cr = section['continuationItemRenderer'] as Map;
            final token = cr['continuationEndpoint']?['continuationCommand']?['token'] as String?;
            if (token != null) return token;
          }
        }
      }
    }

    for (final item in items) {
      if (item is Map && item.containsKey('continuationItemRenderer')) {
        final cr = item['continuationItemRenderer'] as Map;
        final token = cr['continuationEndpoint']?['continuationCommand']?['token'] as String?;
        if (token != null) return token;
      }
    }
    return null;
  }

  SearchResult? _parseRenderer(Map item) {
    if (item.containsKey('videoRenderer')) {
      final vr = item['videoRenderer'] as Map;
      final videoId = vr['videoId'] as String? ?? '';
      final title = vr['title']?['runs']?[0]?['text'] as String? ?? '';
      final author = vr['ownerText']?['runs']?[0]?['text'] as String? ??
                     vr['shortBylineText']?['runs']?[0]?['text'] as String? ?? '';

      String thumbnail = '';
      final thumbnails = vr['thumbnail']?['thumbnails'] as List?;
      if (thumbnails != null && thumbnails.isNotEmpty) {
        thumbnail = thumbnails.last['url'] as String? ?? '';
      }

      bool isLive = false;
      final badges = vr['badges'] as List?;
      if (badges != null) {
        for (final badge in badges) {
          if (badge is Map) {
            final style = badge['metadataBadgeRenderer']?['style'] as String?;
            final label = badge['metadataBadgeRenderer']?['label'] as String?;
            if (style == 'BADGE_STYLE_TYPE_LIVE_NOW' || label == 'LIVE') {
              isLive = true;
              break;
            }
          }
        }
      }

      final lengthText = vr['lengthText']?['simpleText'] as String?;

      return SearchVideo(
        title: title,
        thumbnail: thumbnail,
        videoId: videoId,
        author: author,
        duration: lengthText,
        isLive: isLive,
      );
    }

    if (item.containsKey('gridVideoRenderer')) {
      final gvr = item['gridVideoRenderer'] as Map;
      final videoId = gvr['videoId'] as String? ?? '';
      final title = gvr['title']?['runs']?[0]?['text'] as String? ?? '';
      final author = gvr['shortBylineText']?['runs']?[0]?['text'] as String? ?? '';

      String thumbnail = '';
      final thumbnails = gvr['thumbnail']?['thumbnails'] as List?;
      if (thumbnails != null && thumbnails.isNotEmpty) {
        thumbnail = thumbnails.last['url'] as String? ?? '';
      }

      return SearchVideo(
        title: title,
        thumbnail: thumbnail,
        videoId: videoId,
        author: author,
        duration: gvr['lengthText']?['simpleText'] as String?,
        isLive: false,
      );
    }

    if (item.containsKey('channelRenderer')) {
      final cr = item['channelRenderer'] as Map;
      final channelId = cr['channelId'] as String? ?? '';
      final title = cr['title']?['simpleText'] as String? ??
                    cr['title']?['runs']?[0]?['text'] as String? ?? '';

      String thumbnail = '';
      final thumbnails = cr['thumbnail']?['thumbnails'] as List?;
      if (thumbnails != null && thumbnails.isNotEmpty) {
        thumbnail = thumbnails.last['url'] as String? ?? '';
      }

      return SearchChannel(
        title: title,
        thumbnail: thumbnail,
        channelId: channelId,
      );
    }

    if (item.containsKey('playlistRenderer')) {
      final pr = item['playlistRenderer'] as Map;
      final playlistId = pr['playlistId'] as String? ?? '';
      final title = pr['title']?['simpleText'] as String? ??
                    pr['title']?['runs']?[0]?['text'] as String? ?? '';

      String thumbnail = '';
      final thumbnails = pr['thumbnail']?['thumbnails'] as List?;
      if (thumbnails != null && thumbnails.isNotEmpty) {
        thumbnail = thumbnails.last['url'] as String? ?? '';
      }

      return SearchPlaylist(
        title: title,
        thumbnail: thumbnail,
        playlistId: playlistId,
      );
    }

    if (item.containsKey('lockupViewModel')) {
      final lvm = item['lockupViewModel'] as Map;
      final contentId = lvm['contentId'] as String? ?? '';
      final contentType = lvm['contentType'] as String? ?? '';

      final metadata = lvm['metadata']?['lockupMetadataViewModel'] as Map?;
      final title = metadata?['title']?['content'] as String? ?? '';
      final thumbnail = _getLockupThumbnail(lvm);

      if (contentType == 'LOCKUP_CONTENT_TYPE_PLAYLIST') {
        return SearchPlaylist(
          title: title,
          thumbnail: thumbnail,
          playlistId: contentId,
        );
      } else if (contentType == 'LOCKUP_CONTENT_TYPE_VIDEO') {
        final author = _getLockupAuthor(lvm);
        return SearchVideo(
          title: title,
          thumbnail: thumbnail,
          videoId: contentId,
          author: author,
          isLive: false,
        );
      }
    }

    return null;
  }

  String _getLockupThumbnail(Map lvm) {
    final contentImage = lvm['contentImage'] as Map?;
    if (contentImage != null) {
      for (final key in contentImage.keys) {
        final model = contentImage[key] as Map?;
        if (model != null) {
          final primary = model['primaryThumbnail'] as Map? ?? model;
          final thumbViewModel = primary['thumbnailViewModel'] as Map? ?? primary;
          final image = thumbViewModel['image'] as Map?;
          if (image != null) {
            final sources = image['sources'] as List?;
            if (sources != null && sources.isNotEmpty) {
              return sources.last['url'] as String? ?? '';
            }
          }
        }
      }
    }
    return '';
  }

  String _getLockupAuthor(Map lvm) {
    final metadata = lvm['metadata']?['lockupMetadataViewModel'] as Map?;
    if (metadata != null) {
      final parts = metadata['metadata']?['metadataParts'] as List?;
      if (parts != null && parts.isNotEmpty) {
        final firstPart = parts.first as Map?;
        final textObj = firstPart?['text'] as Map?;
        if (textObj != null) {
          return textObj['content'] as String? ?? '';
        }
      }
    }
    return '';
  }
}
