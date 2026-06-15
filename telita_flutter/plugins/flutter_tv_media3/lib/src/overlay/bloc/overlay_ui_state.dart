part of 'overlay_ui_bloc.dart';

/// Represents the current state of the player's overlay UI.
class OverlayUiState extends Equatable {
  const OverlayUiState({
    this.playIndex = -1,
    this.playerPanel = PlayerPanel.placeholder,
    this.clockSettings = const ClockSettings(),
    this.sideSheetOpen = false,
    this.sleepTime = Duration.zero,
    this.sleepAfter = false,
    this.sleepAfterNext = false,
    this.tabIndex = 0,
    this.settingsItemIndex = 0,
    this.endPlaybackAndSleep = false,
    this.isChangePlayerSettings,
    required this.clockPosition,
    this.customInfoText,
    this.isScreenLocked = false,
    this.isTouch = false,
  });

  /// The index of the current item in the playlist.
  final int playIndex;

  /// The active panel being displayed in the UI.
  final PlayerPanel playerPanel;

  /// The current settings for the clock.
  final ClockSettings clockSettings;

  /// A flag indicating whether the side sheet is open.
  final bool sideSheetOpen;

  /// The time remaining until the sleep timer triggers.
  final Duration sleepTime;

  /// A flag indicating if the sleep timer is set to trigger after the track ends.
  final bool sleepAfter;

  /// A flag indicating if the sleep timer will trigger after the *next* track.
  final bool sleepAfterNext;

  /// The index of the active tab in the setup panel.
  final int tabIndex;

  /// The index of the selected item in a settings menu.
  final int settingsItemIndex;

  /// A flag to end playback and enter sleep mode.
  final bool endPlaybackAndSleep;

  /// A flag indicating that player settings have been changed.
  final bool? isChangePlayerSettings;

  /// The current position of the clock on the screen.
  final ClockPosition clockPosition;

  /// A custom string to be displayed in the info panel.
  final String? customInfoText;

  /// A flag indicating if the touch controls are locked.
  final bool isScreenLocked;

  /// A flag indicating if the UI is in touch mode.
  final bool isTouch;

  @override
  List<Object?> get props => [
    playIndex,
    playerPanel,
    tabIndex,
    settingsItemIndex,
    sideSheetOpen,
    sleepTime,
    sleepAfter,
    sleepAfterNext,
    clockSettings,
    clockPosition,
    customInfoText,
    isScreenLocked,
    isTouch,
  ];

  OverlayUiState copyWith({
    int? playIndex,
    PlayerPanel? playerPanel,
    ClockSettings? clockSettings,
    bool? sideSheetOpen,
    Duration? sleepTime,
    bool? sleepAfter,
    bool? sleepAfterNext,
    int? tabIndex,
    int? settingsItemIndex,
    bool? endPlaybackAndSleep,
    bool? isChangePlayerSettings,
    ClockPosition? clockPosition,
    String? customInfoText,
    bool? isScreenLocked,
    bool? isTouch,
  }) {
    return OverlayUiState(
      playIndex: playIndex ?? this.playIndex,
      playerPanel: playerPanel ?? this.playerPanel,
      clockSettings: clockSettings ?? this.clockSettings,
      sideSheetOpen: sideSheetOpen ?? this.sideSheetOpen,
      sleepTime: sleepTime ?? this.sleepTime,
      sleepAfter: sleepAfter ?? this.sleepAfter,
      sleepAfterNext: sleepAfterNext ?? this.sleepAfterNext,
      tabIndex: tabIndex ?? this.tabIndex,
      settingsItemIndex: settingsItemIndex ?? this.settingsItemIndex,
      endPlaybackAndSleep: endPlaybackAndSleep ?? this.endPlaybackAndSleep,
      isChangePlayerSettings:
          isChangePlayerSettings ?? this.isChangePlayerSettings,
      clockPosition: clockPosition ?? this.clockPosition,
      customInfoText: customInfoText ?? this.customInfoText,
      isScreenLocked: isScreenLocked ?? this.isScreenLocked,
      isTouch: isTouch ?? this.isTouch,
    );
  }
}

/// Defines the different panels that can be displayed in the overlay UI.
enum PlayerPanel {
  /// Nothing is displayed.
  none,

  /// Panel with detailed media information.
  info,

  /// Simple panel with a progress bar.
  simple,

  /// General setup panel (fallback).
  setup,

  /// Playlist panel.
  playlist,

  /// Video settings panel.
  video,

  /// Audio settings panel.
  audio,

  /// Subtitle settings panel.
  subtitle,

  /// Main settings panel.
  settings,

  /// Sleep timer panel.
  sleep,

  /// Placeholder shown during loading.
  placeholder,

  /// Error panel.
  error,

  /// Electronic Program Guide (EPG) screen.
  epg,

  /// A panel with touch-friendly controls.
  touchOverlay,

  /// A horizontal playlist panel (YouTube style).
  horizontalPlaylist,
}
