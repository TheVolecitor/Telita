import 'package:flutter_tv_media3/src/localization/overlay_localizations.dart';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../entity/epg_channel.dart';
import 'package:flutter_tv_media3/src/overlay/media_ui_service/media3_ui_controller.dart';
import '../../../../../entity/player_state.dart';

part 'epg_event.dart';
part 'epg_state.dart';

enum EpgStatus { initial, loading, success, failure }

class EpgBloc extends Bloc<EpgEvent, EpgState> {
  final Media3UiController _media3UiController;
  StreamSubscription? _playerStateSubscription;
  Timer? _timer;

  EpgBloc({
    required Media3UiController media3UiController,
    required int initialPage,
  }) : _media3UiController = media3UiController,
       super(EpgState(currentPage: initialPage)) {
    on<EpgStarted>(_onEpgStarted);
    on<EpgChannelSelected>(_onChannelSelected);
    on<EpgProgramSelected>(_onProgramSelected);
    on<EpgPageChanged>(_onPageChanged);

    on<EpgTimerTicked>(_onTimerTicked);
    on<EpgDateChanged>(_onDateChanged);
    on<EpgScrolled>(_onEpgScrolled);
    on<EpgPlayerStateUpdated>(_onPlayerStateUpdated);
    _startTimer();
    _playerStateSubscription = _media3UiController.playerStateStream.listen((
      playerState,
    ) {
      add(EpgPlayerStateUpdated(playerState));
    });
  }

  Future<void> _onEpgStarted(EpgStarted event, Emitter<EpgState> emit) async {
    emit(state.copyWith(status: EpgStatus.loading));
    try {
      final playerState = _media3UiController.playerState;
      final tvChannels =
          playerState.playlist
              .asMap()
              .entries
              .where((entry) => entry.value.programs != null)
              .map(
                (entry) => EpgChannel.fromPlaylistMediaItem(
                  item: entry.value,
                  index: entry.key,
                ),
              )
              .toList();

      if (tvChannels.isEmpty) {
        emit(
          state.copyWith(
            status: EpgStatus.failure,
            errorMessage: OverlayLocalizations.get('epgNoChannels'),
          ),
        );
        return;
      }

      final initialChannelIndex = tvChannels.indexWhere(
        (c) => c.id == event.initialChannelId,
      );
      final selectedChannelIndex =
          initialChannelIndex != -1 ? initialChannelIndex : 0;

      final newState = state.copyWith(
        status: EpgStatus.success,
        allChannels: tvChannels,
        selectedChannelIndex: selectedChannelIndex,
      );

      emit(newState);
      _selectInitialProgramForChannel(emit, newState);
    } catch (e) {
      emit(
        state.copyWith(status: EpgStatus.failure, errorMessage: e.toString()),
      );
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _playerStateSubscription?.cancel();
    return super.close();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (state.status == EpgStatus.success) {
        add(EpgTimerTicked());
      }
    });
  }

  void _onPlayerStateUpdated(
    EpgPlayerStateUpdated event,
    Emitter<EpgState> emit,
  ) {
    final playerState = event.playerState;
    final tvChannels =
        playerState.playlist
            .asMap()
            .entries
            .where((entry) => entry.value.programs != null)
            .map(
              (entry) => EpgChannel.fromPlaylistMediaItem(
                item: entry.value,
                index: entry.key,
              ),
            )
            .toList();

    emit(state.copyWith(allChannels: tvChannels));
  }

  void _onChannelSelected(EpgChannelSelected event, Emitter<EpgState> emit) {
    final newState = state.copyWith(selectedChannelIndex: event.channelIndex);
    _selectInitialProgramForChannel(emit, newState);
  }

  void _onProgramSelected(EpgProgramSelected event, Emitter<EpgState> emit) {
    final newDateIndex = _findDateIndexForProgram(event.programIndex, state);
    emit(
      state.copyWith(
        selectedProgramIndex: event.programIndex,
        selectedDateIndex: newDateIndex,
      ),
    );
  }

  void _onDateChanged(EpgDateChanged event, Emitter<EpgState> emit) {
    if (event.dateIndex >= 0 && event.dateIndex < state.availableDates.length) {
      final selectedDate = state.availableDates[event.dateIndex];
      final programIndex = state.selectedChannel?.programs.indexWhere((p) {
        final programDate = DateTime(
          p.startTime.year,
          p.startTime.month,
          p.startTime.day,
        );
        return programDate.isAtSameMomentAs(selectedDate);
      });

      if (programIndex != -1) {
        emit(
          state.copyWith(
            selectedDateIndex: event.dateIndex,
            programIndexToScroll: programIndex,
          ),
        );
      } else {
        emit(state.copyWith(selectedDateIndex: event.dateIndex));
      }
    }
  }

  void _onEpgScrolled(EpgScrolled event, Emitter<EpgState> emit) {
    emit(state.copyWith(programIndexToScroll: null));
  }

  void _onPageChanged(EpgPageChanged event, Emitter<EpgState> emit) {
    emit(state.copyWith(currentPage: event.pageIndex));
  }

  void _onTimerTicked(EpgTimerTicked event, Emitter<EpgState> emit) {
    final now = DateTime.now();
    final programs = state.selectedChannel?.programs ?? [];
    if (programs.isEmpty) return;

    final newActiveIndex = programs.indexWhere(
      (p) =>
          (p.startTime.isBefore(now) || p.startTime.isAtSameMomentAs(now)) &&
          p.endTime.isAfter(now),
    );

    if (newActiveIndex != state.activeProgramIndex) {
      emit(state.copyWith(activeProgramIndex: newActiveIndex));
    }
  }

  void _selectInitialProgramForChannel(
    Emitter<EpgState> emit,
    EpgState currentState,
  ) {
    final now = DateTime.now();
    final programs = currentState.selectedChannel?.programs ?? [];
    int activeProgramIndex = -1;
    int programToSelect = 0;

    if (programs.isNotEmpty) {
      activeProgramIndex = programs.indexWhere(
        (p) =>
            (p.startTime.isBefore(now) || p.startTime.isAtSameMomentAs(now)) &&
            p.endTime.isAfter(now),
      );

      programToSelect =
          activeProgramIndex != -1
              ? activeProgramIndex
              : programs.indexWhere((p) => p.startTime.isAfter(now));
      if (programToSelect == -1) {
        programToSelect = 0;
      }
    }

    final availableDates = _getAvailableDates(currentState.selectedChannel);
    final newDateIndex = _findDateIndexForProgram(
      programToSelect,
      currentState.copyWith(availableDates: availableDates),
    );

    emit(
      currentState.copyWith(
        activeProgramIndex: activeProgramIndex,
        selectedProgramIndex: programToSelect,
        availableDates: availableDates,
        selectedDateIndex: newDateIndex,
      ),
    );
  }

  List<DateTime> _getAvailableDates(EpgChannel? channel) {
    if (channel == null || channel.programs.isEmpty) return [];
    final dateSet = <DateTime>{};
    for (final program in channel.programs) {
      dateSet.add(
        DateTime(
          program.startTime.year,
          program.startTime.month,
          program.startTime.day,
        ),
      );
    }
    return dateSet.toList()..sort();
  }

  int _findDateIndexForProgram(int programIndex, EpgState state) {
    final programs = state.selectedChannel?.programs ?? [];
    if (programIndex < programs.length) {
      final program = programs[programIndex];
      final focusedDate = DateTime(
        program.startTime.year,
        program.startTime.month,
        program.startTime.day,
      );
      final newDateIndex = state.availableDates.indexWhere(
        (d) => d.isAtSameMomentAs(focusedDate),
      );
      return newDateIndex != -1 ? newDateIndex : state.selectedDateIndex;
    }
    return state.selectedDateIndex;
  }
}
