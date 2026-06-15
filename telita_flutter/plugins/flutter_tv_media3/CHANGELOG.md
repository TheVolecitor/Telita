## 0.2.0

- Major internal restructuring and cleanup of both Dart and Kotlin codebases for better maintainability.
- Significant rewrite and optimization of `PlayerActivity.kt`.
- Enhanced `getThumbnail` and `getMediaMetadata` logic for more reliable metadata extraction.
- Added ability to take screenshots directly from the player UI, including `TouchControlsOverlay` support.
- Introduced `PlaceholderWidget` for better visual feedback during loading or state transitions in `Media3PlayerScreen`.
- Expanded support for additional `LogicalKeyboardKey` symbols, improving compatibility with various Android TV remote controls.
- Improved `PlayerSettings` initialization and propagation between Flutter and Native layers.
- Comprehensive update of `README.md` and documentation on screenshot handling and metadata retrieval.

## 0.1.2

- feat: Updated Media3 to 1.9.2

## 0.1.1

- fix: renamed RepeatMode to PlayerRepeatMode to avoid naming conflicts

## 0.1.0

- update minSdk to 23
- update media3 to 1.9.0
- Update libraries(decoder_av1-release.aar,decoder_ffmpeg-release.aar,decoder_iamf-release.aar,
decoder_mpegh-release.aar, decoder_vp9-release.aar, decoder_flac-release.aar,
decoder_opus-release.aar). media3 v1.9.0.
- Add PlayerTransferState, which facilitates transferring the playback state across
Player instances. media3 v1.9.0.
- Add a stuck player detection that triggers a StuckPlayerException player error
if the player seems stuck. media3 v1.9.0.
- Add Preview Player  specialized widget for displaying video previews directly within your
application. media3 v1.9.0.
- Add TrackManager for managing audio, video, and text tracks. media3 v1.9.0.
- Improve support for external subtitles. media3 v1.9.0.
- Added many new methods to FtvMedia3PlayerController for controlling the player
from the main application. media3 v1.9.0.
- Add a custom overlay UI for the player that can be customized with your own
widgets. media3 v1.9.0.
- Added support for AFR (Auto Frame Rate) switching. media3 v1.9.0.
- Added support for HDR and Dolby Vision. media3 v1.9.0.

## 0.0.1

- Initial release of the plugin.
