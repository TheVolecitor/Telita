part of 'overlay_ui_bloc.dart';

/// Base class for all events related to the overlay UI.
sealed class OverlayUiEvent extends Equatable {
  const OverlayUiEvent();
}

/// Event to update the player state in the BLoC.
///
/// Triggered when a new [PlayerState] is received from the [Media3UiController].
class SetPlayerState extends OverlayUiEvent {
  final PlayerState playerState;
  const SetPlayerState({required this.playerState});

  @override
  List<Object?> get props => [];
}

/// Sets the active UI panel (e.g., info, settings).
///
/// [debounce] - if `true`, the panel will be automatically hidden after a delay.
class SetActivePanel extends OverlayUiEvent {
  final PlayerPanel playerPanel;
  final bool debounce;
  const SetActivePanel({required this.playerPanel, this.debounce = false});

  @override
  List<Object?> get props => [];
}

/// Sets the index of the current playlist item.
///
/// [debounce] - if `true`, the panel will be automatically hidden after a delay.
class SetPlayIndex extends OverlayUiEvent {
  final int playIndex;
  final bool debounce;
  const SetPlayIndex({required this.playIndex, this.debounce = false});

  @override
  List<Object?> get props => [];
}

/// Internal event for debouncing the active panel (hiding it after a delay).
class DebounceActivePanel extends OverlayUiEvent {
  final PlayerPanel playerPanel;
  final PlayerPanel debouncePanel;
  const DebounceActivePanel({
    required this.playerPanel,
    required this.debouncePanel,
  });

  @override
  List<Object?> get props => [];
}

/// Sets a random position for the clock.
class SetRandomClocPosition extends OverlayUiEvent {
  final int position;
  const SetRandomClocPosition({required this.position});

  @override
  List<Object?> get props => [];
}

/// Sets the active tab in the setup panel.
class SetSetupTabIndex extends OverlayUiEvent {
  final int tabIndex;
  const SetSetupTabIndex({required this.tabIndex});

  @override
  List<Object?> get props => [];
}

/// Sets the state of the side sheet (open/closed).
class SetSideSheetState extends OverlayUiEvent {
  final bool isOpen;
  const SetSideSheetState({required this.isOpen});

  @override
  List<Object?> get props => [];
}

/// Sets the index of the selected item in a settings menu.
class SetSettingsItemIndex extends OverlayUiEvent {
  final int index;
  const SetSettingsItemIndex({required this.index});

  @override
  List<Object?> get props => [];
}

/// Sets or updates the sleep timer.
class SetSleepTimer extends OverlayUiEvent {
  final Duration? sleepTime;
  final bool? sleepAfter;
  final bool? sleepAfterNext;
  const SetSleepTimer({this.sleepTime, this.sleepAfter, this.sleepAfterNext});

  @override
  List<Object?> get props => [];
}

/// Updates the time left on the sleep timer.
class SetSleepTimeLeft extends OverlayUiEvent {
  final Duration sleepTime;
  const SetSleepTimeLeft({required this.sleepTime});

  @override
  List<Object?> get props => [];
}

/// Event to end playback and trigger sleep.
class SetEndPlaybackAndSleep extends OverlayUiEvent {
  final bool endPlaybackAndSleep;
  const SetEndPlaybackAndSleep({required this.endPlaybackAndSleep});

  @override
  List<Object?> get props => [];
}

/// Sets new settings for the clock.
class SetClockSettings extends OverlayUiEvent {
  final ClockSettings clockSettings;
  const SetClockSettings({required this.clockSettings});

  @override
  List<Object?> get props => [];
}

/// Sets a new position for the clock.
class SetClockPosition extends OverlayUiEvent {
  final ClockPosition clockPosition;
  const SetClockPosition({required this.clockPosition});

  @override
  List<Object?> get props => [];
}

/// Toggles the screen lock state.
class ToggleScreenLock extends OverlayUiEvent {
  const ToggleScreenLock();

  @override
  List<Object?> get props => [];
}

/// Sets the touch mode for the UI.
class SetTouchMode extends OverlayUiEvent {
  final bool isTouch;
  const SetTouchMode({required this.isTouch});

  @override
  List<Object?> get props => [isTouch];
}
