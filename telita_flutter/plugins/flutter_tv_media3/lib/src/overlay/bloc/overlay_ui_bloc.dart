import 'dart:async';

import 'package:bloc_event_transformers/bloc_event_transformers.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../flutter_tv_media3.dart';
import '../media_ui_service/media3_ui_controller.dart';

part 'overlay_ui_event.dart';
part 'overlay_ui_state.dart';

/// BLoC that manages the state of the player's overlay UI.
///
/// This BLoC is responsible for the logic of displaying different panels
/// (info, settings, error), handling the sleep timer, and reacting to
/// player state changes coming from the [Media3UiController].
class OverlayUiBloc extends Bloc<OverlayUiEvent, OverlayUiState> {
  final Media3UiController controller;
  late StreamSubscription<PlayerState> _streamSubscription;
  StreamSubscription<PlaybackState>? _streamSubscription2;
  Timer? _timer;

  OverlayUiBloc({required this.controller})
    : super(
        OverlayUiState(
          playIndex: controller.playerState.playIndex,
          clockPosition: ClockPosition.none,
          playerPanel: controller.playerState.stateValue == StateValue.playing 
              ? PlayerPanel.none 
              : PlayerPanel.placeholder,
        ),
      ) {
    // Subscribe to player state changes.
    _streamSubscription = controller.playerStateStream.listen((playerState) {
      // Logic for the sleep timer after track completion.
      if (playerState.stateValue == StateValue.ended &&
          state.sleepAfter == true) {
        if (state.sleepAfterNext == true) {
          add(SetSleepTimer(sleepAfter: true, sleepAfterNext: false));
        } else {
          controller.sleepTimerExec();
        }
      }
      add(SetPlayerState(playerState: playerState));
    });

    // Register event handlers.
    on<SetPlayerState>(_setPlayerState);
    on<SetPlayIndex>(_setPlayIndex);
    on<SetActivePanel>(_setActivePanel);
    on<DebounceActivePanel>(
      _debounceActivePanel,
      transformer: debounce(const Duration(seconds: 2)),
    );
    on<SetSetupTabIndex>(_setSetupTabIndex);
    on<SetSettingsItemIndex>(_setSettingsItemIndex);
    on<SetSideSheetState>(_setSideSheetState);
    on<SetSleepTimer>(_setSleepTimer);
    on<SetSleepTimeLeft>(_setSleepTimeLeft);
    on<SetClockSettings>(_setClockSettings);
    on<SetClockPosition>(_setClockPosition);
    on<ToggleScreenLock>(_toggleScreenLock);
    on<SetTouchMode>(_onSetTouchMode);
  }

  /// Handles updates to the full player state.
  void _setPlayerState(SetPlayerState event, Emitter<OverlayUiState> emit) {
    // Automatically show the simple panel when playback starts.
    if (state.playerPanel == PlayerPanel.placeholder &&
        event.playerState.stateValue == StateValue.playing) {
      add(SetActivePanel(playerPanel: PlayerPanel.simple, debounce: true));
    }
    // Show a placeholder when the track changes.
    if (state.playIndex != event.playerState.playIndex) {
      add(const SetActivePanel(playerPanel: PlayerPanel.placeholder));
    }
    // Show the error panel if an error has occurred.
    if (state.playerPanel != PlayerPanel.placeholder &&
        event.playerState.lastError != null) {
      add(SetActivePanel(playerPanel: PlayerPanel.error));
    }
    // Update clock settings if they have changed.
    if (state.clockSettings != event.playerState.clockSettings) {
      add(SetClockSettings(clockSettings: event.playerState.clockSettings));
    }
    emit(
      state.copyWith(
        playIndex: event.playerState.playIndex,
        customInfoText: event.playerState.customInfoText,
      ),
    );
  }

  /// Handles a change in the playback index.
  void _setPlayIndex(SetPlayIndex event, Emitter<OverlayUiState> emit) {
    emit(
      state.copyWith(playIndex: event.playIndex, playerPanel: PlayerPanel.simple),
    );
    if (event.debounce == true) {
      add(
        const DebounceActivePanel(
          playerPanel: PlayerPanel.none,
          debouncePanel: PlayerPanel.simple,
        ),
      );
    }
  }

  /// Sets the active UI panel.
  void _setActivePanel(SetActivePanel event, Emitter<OverlayUiState> emit) {
    emit(state.copyWith(playerPanel: event.playerPanel));
    if (event.debounce == true) {
      add(
        DebounceActivePanel(
          playerPanel: PlayerPanel.none,
          debouncePanel: event.playerPanel,
        ),
      );
    }
  }

  /// Hides the panel after a delay if it's still active.
  void _debounceActivePanel(
    DebounceActivePanel event,
    Emitter<OverlayUiState> emit,
  ) {
    if (controller.playerState.stateValue == StateValue.paused) {
      return;
    }
    if (event.debouncePanel == state.playerPanel) {
      emit(state.copyWith(playerPanel: event.playerPanel));
    }
  }

  @override
  Future<void> close() {
    _streamSubscription.cancel();
    _streamSubscription2?.cancel();
    _timer?.cancel();
    return super.close();
  }

  /// Sets the active tab in the setup panel.
  void _setSetupTabIndex(SetSetupTabIndex event, Emitter<OverlayUiState> emit) {
    emit(state.copyWith(tabIndex: event.tabIndex));
  }

  /// Sets the index of the selected item in a settings menu.
  void _setSettingsItemIndex(
    SetSettingsItemIndex event,
    Emitter<OverlayUiState> emit,
  ) => emit(state.copyWith(settingsItemIndex: event.index));

  /// Sets the state of the side sheet (open/closed).
  void _setSideSheetState(
    SetSideSheetState event,
    Emitter<OverlayUiState> emit,
  ) => emit(state.copyWith(sideSheetOpen: event.isOpen));

  /// Manages the sleep timer logic.
  void _setSleepTimer(SetSleepTimer event, Emitter<OverlayUiState> emit) {
    bool sleepAfter = event.sleepAfter ?? false;
    Duration sleepTime =
        event.sleepAfter == null
            ? event.sleepTime ?? Duration.zero
            : Duration.zero;
    emit(
      state.copyWith(
        sleepTime: sleepTime,
        sleepAfter: sleepAfter,
        sleepAfterNext: event.sleepAfterNext ?? false,
      ),
    );
    if (sleepTime == Duration.zero) {
      _timer?.cancel();
      _streamSubscription2?.cancel();
      add(SetSleepTimeLeft(sleepTime: sleepTime));
    } else {
      // Start a periodic timer that updates the remaining time.
      _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
        final sleepTime = (state.sleepTime - const Duration(minutes: 1));
        add(SetSleepTimeLeft(sleepTime: sleepTime));
        if (sleepTime == const Duration(minutes: 2)) {
          add(const SetActivePanel(playerPanel: PlayerPanel.sleep));
        }
        if (sleepTime == Duration.zero) {
          timer.cancel();
          controller.sleepTimerExec();
        }
      });
    }

    // Logic for sleeping after the track finishes.
    if (sleepAfter == true) {
      _streamSubscription2 = controller.playbackStateStream.listen((data) {
        if (state.sleepAfterNext == false) {
          final f = data.duration - data.position;
          if (f < 120 && f > 100) {
            add(const SetActivePanel(playerPanel: PlayerPanel.sleep));
            _streamSubscription2?.cancel();
          }
        }
      });
    }
  }

  /// Updates the remaining time until sleep.
  void _setSleepTimeLeft(
    SetSleepTimeLeft event,
    Emitter<OverlayUiState> emit,
  ) => emit(state.copyWith(sleepTime: event.sleepTime));

  /// Updates the clock settings.
  void _setClockSettings(SetClockSettings event, Emitter<OverlayUiState> emit) {
    if (state.clockSettings.clockPosition !=
        event.clockSettings.clockPosition) {
      final clockPosition =
          event.clockSettings.clockPosition != ClockPosition.random
              ? event.clockSettings.clockPosition
              : ClockPosition.getRandomPosition();
      emit(state.copyWith(clockPosition: clockPosition));
    }
    emit(state.copyWith(clockSettings: event.clockSettings));
  }

  /// Updates the clock position.
  void _setClockPosition(SetClockPosition event, Emitter<OverlayUiState> emit) {
    emit(state.copyWith(clockPosition: event.clockPosition));
  }

  /// Toggles the screen lock state.
  void _toggleScreenLock(ToggleScreenLock event, Emitter<OverlayUiState> emit) {
    emit(state.copyWith(isScreenLocked: !state.isScreenLocked));
  }

  /// Sets the touch mode.
  void _onSetTouchMode(SetTouchMode event, Emitter<OverlayUiState> emit) {
    emit(state.copyWith(isTouch: event.isTouch));
  }
}
