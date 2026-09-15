import 'extract.dart' as extract;
import 'innertube.dart';

/// Represents a recommended playlist item in YouTube Music Related content.
class RelatedPlaylist {
  final String playlistId;
  final String title;
  final String thumbnail;
  final String? subtitle;

  RelatedPlaylist({
    required this.playlistId,
    required this.title,
    required this.thumbnail,
    this.subtitle,
  });

  @override
  String toString() => 'RelatedPlaylist(playlistId: $playlistId, title: $title, subtitle: $subtitle)';
}

/// Represents a similar artist item in YouTube Music Related content.
class RelatedArtist {
  final String channelId;
  final String title;
  final String thumbnail;
  final String? subscribers;

  RelatedArtist({
    required this.channelId,
    required this.title,
    required this.thumbnail,
    this.subscribers,
  });

  @override
  String toString() => 'RelatedArtist(channelId: $channelId, title: $title, subscribers: $subscribers)';
}

/// Represents a general related track, video, or release item.
class RelatedItem {
  final String title;
  final String thumbnail;
  final String? videoId;
  final String? playlistId;
  final String? browseId;
  final String? subtitle;

  RelatedItem({
    required this.title,
    required this.thumbnail,
    this.videoId,
    this.playlistId,
    this.browseId,
    this.subtitle,
  });

  @override
  String toString() => 'RelatedItem(title: $title, videoId: $videoId, playlistId: $playlistId, subtitle: $subtitle)';
}

/// Represents the "About the artist" section of YouTube Music Related content.
class AboutArtist {
  final String? title;
  final String description;
  final String? subheader;
  final String? thumbnail;

  AboutArtist({
    this.title,
    required this.description,
    this.subheader,
    this.thumbnail,
  });

  @override
  String toString() => 'AboutArtist(title: $title, subheader: $subheader, description: $description)';
}

/// Represents a generic section/shelf of items in YouTube Music Related content.
class RelatedShelf {
  final String title;
  final String shelfType;
  final List<dynamic> items;

  RelatedShelf({
    required this.title,
    required this.shelfType,
    required this.items,
  });

  @override
  String toString() => 'RelatedShelf(title: $title, shelfType: $shelfType, itemsCount: ${items.length})';
}

/// Handles fetching and parsing YouTube Music "Related" section contents for a song or video.
class MusicRelated {
  final String url;
  late final String videoId;
  final InnerTube _innertube;
  bool _hasFetched = false;

  final List<RelatedPlaylist> _recommendedPlaylists = [];
  final List<RelatedArtist> _similarArtists = [];
  final List<RelatedItem> _moreFromArtist = [];
  String? _moreFromArtistTitle;
  AboutArtist? _aboutArtist;
  final List<RelatedShelf> _shelves = [];

  MusicRelated(this.url, {String client = 'WEB_MUSIC'})
      : videoId = extract.videoId(url),
        _innertube = InnerTube(clientName: client);

  /// Returns recommended playlists found in the Related section.
  List<RelatedPlaylist> get recommendedPlaylists {
    _ensureFetched();
    return _recommendedPlaylists;
  }

  /// Returns similar artists found in the Related section.
  List<RelatedArtist> get similarArtists {
    _ensureFetched();
    return _similarArtists;
  }

  /// Returns items from "MORE FROM [Artist]" or artist releases/performances shelf.
  List<RelatedItem> get moreFromArtist {
    _ensureFetched();
    return _moreFromArtist;
  }

  /// Title of the "MORE FROM [Artist]" section if present.
  String? get moreFromArtistTitle {
    _ensureFetched();
    return _moreFromArtistTitle;
  }

  /// "About the artist" biography/description details if present.
  AboutArtist? get aboutArtist {
    _ensureFetched();
    return _aboutArtist;
  }

  /// All shelves/sections extracted from the Related tab.
  List<RelatedShelf> get shelves {
    _ensureFetched();
    return _shelves;
  }

  void _ensureFetched() {
    if (!_hasFetched) {
      throw StateError('MusicRelated data has not been fetched yet. Call fetch() first.');
    }
  }

  /// Fetches the YouTube Music Related section data.
  Future<void> fetch() async {
    if (_hasFetched) return;
    final nextResp = await _innertube.next(videoId);
    final tabs = nextResp['contents']?['singleColumnMusicWatchNextResultsRenderer']?['tabbedRenderer']?['watchNextTabbedResultsRenderer']?['tabs'] as List?;
    
    String? relatedBrowseId;
    if (tabs != null) {
      for (final tabObj in tabs) {
        if (tabObj is Map) {
          final tab = tabObj['tabRenderer'] as Map?;
          final title = tab?['title'] as String? ?? '';
          final endpoint = tab?['endpoint'];
          final browseId = endpoint?['browseEndpoint']?['browseId'] as String?;
          if (title.toLowerCase() == 'related' || (browseId != null && browseId.startsWith('MPTR'))) {
            relatedBrowseId = browseId;
            break;
          }
        }
      }
    }

    if (relatedBrowseId != null) {
      final browseResp = await _innertube.browse(relatedBrowseId);
      _parseBrowseResponse(browseResp);
    }
    _hasFetched = true;
  }

  void _parseBrowseResponse(Map<String, dynamic> response) {
    final sectionList = response['contents']?['sectionListRenderer']?['contents'] as List?;
    if (sectionList == null) return;

    for (final sec in sectionList) {
      if (sec is! Map) continue;

      // Check for description shelf (About the artist)
      if (sec.containsKey('musicDescriptionShelfRenderer')) {
        final ds = sec['musicDescriptionShelfRenderer'] as Map;
        final descRuns = ds['description']?['runs'] as List?;
        final description = descRuns?.map((r) => r['text'] ?? '').join('') ?? '';
        
        final headerObj = ds['header'];
        String title = 'About the artist';
        if (headerObj is Map) {
          final runs = headerObj['runs'] as List? ?? headerObj['musicDescriptionShelfHeaderRenderer']?['title']?['runs'] as List?;
          if (runs != null && runs.isNotEmpty) {
            title = runs.map((r) => r['text'] ?? '').join('');
          }
        }
        
        final subheaderRuns = ds['subheader']?['runs'] as List?;
        final subheader = subheaderRuns?.map((r) => r['text'] ?? '').join('');

        _aboutArtist = AboutArtist(
          title: title.isNotEmpty ? title : 'About the artist',
          description: description,
          subheader: subheader?.isNotEmpty == true ? subheader : null,
        );
        _shelves.add(RelatedShelf(
          title: title.isNotEmpty ? title : 'About the artist',
          shelfType: 'musicDescriptionShelfRenderer',
          items: [_aboutArtist!],
        ));
        continue;
      }

      // Check for carousel shelf or generic shelf
      final shelfData = sec['musicCarouselShelfRenderer'] as Map? ??
                        sec['musicShelfRenderer'] as Map? ??
                        sec['shelfRenderer'] as Map?;
      if (shelfData == null) continue;

      final header = shelfData['header'];
      final strapline = _extractText(header?['musicCarouselShelfBasicHeaderRenderer']?['strapline']);
      final titleMain = _extractText(header?['musicCarouselShelfBasicHeaderRenderer']?['title']).isNotEmpty
          ? _extractText(header?['musicCarouselShelfBasicHeaderRenderer']?['title'])
          : _extractText(header?['musicHeaderRenderer']?['title']).isNotEmpty
              ? _extractText(header?['musicHeaderRenderer']?['title'])
              : _extractText(shelfData['title']);

      final headerTitle = strapline.isNotEmpty ? '$strapline $titleMain' : titleMain;
      final titleLower = headerTitle.toLowerCase();

      final items = shelfData['contents'] as List?;
      if (items == null) continue;

      final shelfItems = <dynamic>[];

      if (titleLower.contains('playlist') || titleLower.contains('recommended')) {
        for (final item in items) {
          final playlist = _parsePlaylist(item);
          if (playlist != null) {
            _recommendedPlaylists.add(playlist);
            shelfItems.add(playlist);
          }
        }
      } else if (titleLower.contains('artist') || titleLower.contains('similar') || titleLower.contains('fans also')) {
        for (final item in items) {
          final artist = _parseArtist(item);
          if (artist != null) {
            _similarArtists.add(artist);
            shelfItems.add(artist);
          }
        }
      } else if (strapline.toLowerCase().contains('more from') ||
                 titleLower.contains('more from') ||
                 _moreFromArtist.isEmpty) {
        if (_moreFromArtist.isEmpty) {
          _moreFromArtistTitle = headerTitle;
        }
        for (final item in items) {
          final relItem = _parseItem(item);
          if (relItem != null) {
            _moreFromArtist.add(relItem);
            shelfItems.add(relItem);
          }
        }
      } else {
        for (final item in items) {
          final relItem = _parseItem(item);
          if (relItem != null) {
            shelfItems.add(relItem);
          }
        }
      }

      // Also extract artists from items if any exist
      for (final item in items) {
        final artist = _parseArtist(item);
        if (artist != null && !_similarArtists.any((a) => a.channelId == artist.channelId)) {
          _similarArtists.add(artist);
        }
      }

      _shelves.add(RelatedShelf(
        title: headerTitle,
        shelfType: sec.keys.first.toString(),
        items: shelfItems,
      ));
    }
  }

  RelatedPlaylist? _parsePlaylist(dynamic item) {
    if (item is! Map) return null;
    final renderer = item['musicTwoRowItemRenderer'] as Map? ?? item['musicResponsiveListItemRenderer'] as Map?;
    if (renderer == null) return null;

    final title = _extractText(renderer['title']);
    final subtitle = _extractText(renderer['subtitle']);
    final thumbnail = _extractThumbnail(renderer);
    final endpoint = renderer['navigationEndpoint'] ?? renderer['title']?['runs']?[0]?['navigationEndpoint'];

    String playlistId = '';
    if (endpoint is Map) {
      if (endpoint.containsKey('watchEndpoint')) {
        playlistId = endpoint['watchEndpoint']['playlistId'] as String? ?? '';
      } else if (endpoint.containsKey('browseEndpoint')) {
        var bId = endpoint['browseEndpoint']['browseId'] as String? ?? '';
        if (bId.startsWith('VL')) bId = bId.substring(2);
        playlistId = bId;
      }
    }

    if (title.isEmpty && playlistId.isEmpty) return null;
    return RelatedPlaylist(
      playlistId: playlistId,
      title: title,
      thumbnail: thumbnail,
      subtitle: subtitle.isNotEmpty ? subtitle : null,
    );
  }

  RelatedArtist? _parseArtist(dynamic item) {
    if (item is! Map) return null;
    final renderer = item['musicTwoRowItemRenderer'] as Map? ?? item['musicResponsiveListItemRenderer'] as Map?;
    if (renderer == null) return null;

    final title = _extractText(renderer['title']);
    final subtitle = _extractText(renderer['subtitle']);
    final thumbnail = _extractThumbnail(renderer);
    final endpoint = renderer['navigationEndpoint'] ?? renderer['title']?['runs']?[0]?['navigationEndpoint'];

    String channelId = '';
    if (endpoint is Map && endpoint.containsKey('browseEndpoint')) {
      channelId = endpoint['browseEndpoint']['browseId'] as String? ?? '';
    }

    if (title.isEmpty && channelId.isEmpty) return null;
    return RelatedArtist(
      channelId: channelId,
      title: title,
      thumbnail: thumbnail,
      subscribers: subtitle.isNotEmpty ? subtitle : null,
    );
  }

  RelatedItem? _parseItem(dynamic item) {
    if (item is! Map) return null;
    final renderer = item['musicTwoRowItemRenderer'] as Map? ?? item['musicResponsiveListItemRenderer'] as Map?;
    if (renderer == null) return null;

    final title = _extractText(renderer['title']);
    final subtitle = _extractText(renderer['subtitle']);
    final thumbnail = _extractThumbnail(renderer);
    final endpoint = renderer['navigationEndpoint'] ?? renderer['title']?['runs']?[0]?['navigationEndpoint'];

    String? videoId;
    String? playlistId;
    String? browseId;

    if (endpoint is Map) {
      if (endpoint.containsKey('watchEndpoint')) {
        videoId = endpoint['watchEndpoint']['videoId'] as String?;
        playlistId = endpoint['watchEndpoint']['playlistId'] as String?;
      } else if (endpoint.containsKey('browseEndpoint')) {
        browseId = endpoint['browseEndpoint']['browseId'] as String?;
        if (browseId != null && (browseId.startsWith('VL') || browseId.startsWith('RD') || browseId.startsWith('OLAK'))) {
          playlistId = browseId.startsWith('VL') ? browseId.substring(2) : browseId;
        }
      }
    }

    if (title.isEmpty) return null;
    return RelatedItem(
      title: title,
      thumbnail: thumbnail,
      videoId: videoId,
      playlistId: playlistId,
      browseId: browseId,
      subtitle: subtitle.isNotEmpty ? subtitle : null,
    );
  }

  String _extractText(dynamic obj) {
    if (obj == null) return '';
    if (obj is Map && obj.containsKey('runs')) {
      final runs = obj['runs'] as List?;
      return runs?.map((r) => r['text'] ?? '').join('') ?? '';
    }
    if (obj is Map && obj.containsKey('simpleText')) {
      return obj['simpleText'] as String? ?? '';
    }
    return '';
  }

  String _extractThumbnail(Map renderer) {
    final thumbObj = renderer['thumbnailRenderer']?['musicThumbnailRenderer']?['thumbnail'] ??
                     renderer['thumbnail']?['musicThumbnailRenderer']?['thumbnail'] ??
                     renderer['thumbnail'];
    if (thumbObj is Map && thumbObj.containsKey('thumbnails')) {
      final thumbnails = thumbObj['thumbnails'] as List?;
      if (thumbnails != null && thumbnails.isNotEmpty) {
        return thumbnails.last['url'] as String? ?? '';
      }
    }
    return '';
  }
}
