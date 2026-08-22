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
