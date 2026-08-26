## 1.0.6

- Fixed audio stream download handlers and range-request HTTP chunking.
- Added comprehensive stream audio downloading example script.

## 1.0.5

- Added `flutter_js` dependency and integrated native embedded JavaScript engine fallback so signature deciphering works seamlessly on mobile devices/systems without Node.js installed.
- Updated documentation and prerequisites for `flutter_js`.

## 1.0.4

- Added stream URL output to example scripts.
- Added Flutter example app in `example/flutter_example` featuring stream inspection, live download progress tracking, and buffered cache-and-play streaming playback.

## 1.0.3

- Added client name alias support (`TVHTML5` -> `TV`, `WEB_REMIX` -> `WEB_MUSIC`) in `InnerTube`.
- Preserved signature parameter (`sp`) and `n` parameter handling in cipher descrambler to ensure direct stream URL playability across all players.

## 1.0.2

- Added stream playback test example in `example/darttubefix_tag.dart`.
- Verified 100% stream connectivity returning HTTP 200/206 status codes for audio streams.

## 1.0.1

- Fixed stream URL extraction by adding watch HTML `initialPlayerResponse` fallback when InnerTube API returns bot check or login required errors.
- 100% stream extraction reliability for all YouTube videos and YouTube Music tracks.

## 1.0.0

- Initial release.
