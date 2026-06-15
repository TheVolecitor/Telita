/// A Flutter plugin for playing video using the native Media3 player,
/// which runs in its own Android Activity.
///
/// The main difference of this plugin is that the player is launched
/// in a native window, not as a widget in the Flutter hierarchy. This approach
/// allows for the use of native features like Auto Frame Rate (AFR) switching
/// and potential support for HDR/Dolby Vision.
///
/// ### UI and Controls
/// The user interface (UI) for the player is written in Flutter and runs
/// in a separate Flutter Engine.
/// **Important:**
/// - The UI is controlled **exclusively via D-pad** (remote control's
///   directional pad); there is no support for touch or mouse input.
/// - The player UI is an internal part of the plugin and cannot be customized
///   by the developer without modifying the plugin's code.
///
/// ### FtvMedia3PlayerController
/// Interaction with the plugin is done through the [FtvMedia3PlayerController], which
/// has a dual purpose:
/// 1.  **Launching the Player:** The `openPlayer` method is the primary way
///     to launch the player from your app with the desired playlist.
/// 2.  **External Control:** All other public methods (`playPause`, `seekTo`,
///     `selectTrack`, etc.) are intended for **external programmatic control**.
///     They are ideal for implementing IP control (e.g., a remote in a mobile app)
///     or other programmatic logic.
///
/// ### Getting Started and Configuration
/// 1.  **Get the controller:** `final controller = FlutterTvMedia3.controller;`
/// 2.  **Configure callbacks (optional):**
///     - `controller.saveWatchTime = ...` to save viewing progress.
///     - `controller.savePlayerSettings = ...` to save quality settings.
///     - `controller.localeStrings = {'loading': 'Loading...'};` for localization.
/// 3.  **Launch the player:** `controller.openPlayer(context: context, ...);`
///
/// For a detailed example, see the `example/lib/main.dart` file.
library;

export 'src/overlay/overlay_main.dart';
export 'src/main_app/app_service/ftv_media3_player_controller.dart';
export 'src/main_app/screens/media3_player_screen.dart';
export 'src/overlay/screens/overlay_screen.dart';
export 'src/entity/playlist_media_item.dart';
export 'src/entity/player_state.dart';
export 'src/entity/subtitle_style.dart';
export 'src/entity/clock_settings.dart';
export 'src/entity/player_settings.dart';
export 'src/entity/media_metadata.dart';
export 'src/entity/playback_state.dart';
export 'src/entity/media_track.dart';
export 'src/entity/streaming_metadata.dart';
export 'src/entity/epg_channel.dart';
export 'src/const/basic_colors.dart';
export 'src/const/extended_colors.dart';
export 'src/app_theme/app_theme.dart';
export 'src/utils/string_utils.dart';
export 'src/utils/debouncer_throttler.dart';
export 'src/localization/overlay_localizations.dart';
export 'src/const/iso_language_list.dart';
export 'src/preview/media3_preview.dart';
import 'src/main_app/app_service/ftv_media3_player_controller.dart';

/// The main class for accessing the media player controller.
class FlutterTvMedia3 {
  /// Provides access to the singleton instance of the [FtvMedia3PlayerController].
  ///
  /// The [FtvMedia3PlayerController] is the primary entry point for interacting with
  /// the player from the main application. It is used to open the player,
  /// manage playlists, and control playback externally.
  static FtvMedia3PlayerController get controller =>
      FtvMedia3PlayerController();
}
