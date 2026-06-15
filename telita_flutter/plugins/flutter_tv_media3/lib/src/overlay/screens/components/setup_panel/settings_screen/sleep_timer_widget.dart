import 'package:flutter_tv_media3/src/localization/overlay_localizations.dart';
import 'dart:async';

import '../../../../../app_theme/app_theme.dart';
import '../../../../../utils/string_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../bloc/overlay_ui_bloc.dart';

class SleepTimerWidget extends StatefulWidget {
  final OverlayUiBloc bloc;
  final bool isAuto;
  const SleepTimerWidget({super.key, required this.bloc, this.isAuto = false});

  @override
  State<SleepTimerWidget> createState() => _SleepTimerWidgetState();
}

class _SleepTimerWidgetState extends State<SleepTimerWidget> {
  Timer? _timer;

  List<_SleepTimerOption> _getTimerOptions(OverlayUiState state) {
    final bool isDeferred = state.sleepAfter && state.sleepAfterNext;
    final bool canBeDeferred = state.sleepAfter && !state.sleepAfterNext;
    return [
      _SleepTimerOption(
        label: OverlayLocalizations.get('off'),
        isOff: true,
        duration: Duration.zero,
      ),
      _SleepTimerOption(
        label:
            isDeferred
                ? OverlayLocalizations.get('afterNextFile')
                : OverlayLocalizations.get('afterThisFile'),
        isAfterFile: true,
        subtitle:
            canBeDeferred
                ? OverlayLocalizations.get('tapToApplyAfterNextFile')
                : null,
      ),
      _SleepTimerOption(
        label: OverlayLocalizations.get('min15'),
        duration: Duration(minutes: 15),
      ),
      _SleepTimerOption(
        label: OverlayLocalizations.get('min30'),
        duration: Duration(minutes: 30),
      ),
      _SleepTimerOption(
        label: OverlayLocalizations.get('min60'),
        duration: Duration(minutes: 60),
      ),
      _SleepTimerOption(
        label: OverlayLocalizations.get('min90'),
        duration: Duration(minutes: 90),
      ),
      _SleepTimerOption(
        label: OverlayLocalizations.get('min120'),
        duration: Duration(minutes: 120),
      ),
    ];
  }

  @override
  void initState() {
    if (widget.isAuto) {
      _timer = Timer(const Duration(seconds: 30), () {
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          Navigator.of(context).pop();
        }
      });
    }
    super.initState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft):
            () => _returnToMenu(context),
        const SingleActivator(LogicalKeyboardKey.arrowRight):
            () => _returnToMenu(context),
        const SingleActivator(LogicalKeyboardKey.contextMenu):
            () => _returnToMenu(context),
        const SingleActivator(LogicalKeyboardKey.keyQ):
            () => _returnToMenu(context),
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _SleepTimerHeader(bloc: widget.bloc),
          Expanded(
            child: BlocBuilder<OverlayUiBloc, OverlayUiState>(
              bloc: widget.bloc,
              buildWhen:
                  (oldState, newState) =>
                      oldState.sleepTime != newState.sleepTime ||
                      oldState.sleepAfter != newState.sleepAfter,
              builder: (context, state) {
                final options = _getTimerOptions(state);
                final selectedIndex = _getSelectedIndex(state, options);
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];
                    return _TimerOptionTile(
                      label: option.label,
                      isSelected: index == selectedIndex,
                      onTap: () => _onOptionTap(context, option, state),
                      onFocusChange: () => _timer?.cancel(),
                      subtitle: option.subtitle,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _onOptionTap(
    BuildContext context,
    _SleepTimerOption option,
    OverlayUiState currentState,
  ) {
    if (option.isOff) {
      widget.bloc.add(const SetSleepTimer());
    } else if (option.isAfterFile) {
      if (currentState.sleepAfter && !currentState.sleepAfterNext) {
        widget.bloc.add(
          const SetSleepTimer(sleepAfter: true, sleepAfterNext: true),
        );
      } else {
        widget.bloc.add(const SetSleepTimer(sleepAfter: true));
      }
    } else {
      widget.bloc.add(SetSleepTimer(sleepTime: option.duration!));
    }
    Navigator.of(context).pop();
  }

  int _getSelectedIndex(OverlayUiState state, List<_SleepTimerOption> options) {
    if (state.sleepAfter) return options.indexWhere((opt) => opt.isAfterFile);
    if (state.sleepTime != Duration.zero) {
      final index = options.indexWhere(
        (opt) => opt.duration != null && opt.duration! >= state.sleepTime,
      );
      return index != -1 ? index : 2;
    }
    return options.indexWhere((opt) => opt.isOff);
  }

  void _returnToMenu(BuildContext context) {
    Navigator.of(context).pop();
    widget.bloc.add(const SetActivePanel(playerPanel: PlayerPanel.setup));
  }
}

class _SleepTimerHeader extends StatelessWidget {
  final OverlayUiBloc bloc;
  const _SleepTimerHeader({required this.bloc});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<OverlayUiBloc, OverlayUiState, bool>(
      bloc: bloc,
      selector: (state) => state.isTouch,
      builder: (context, isTouch) {
        return BlocBuilder<OverlayUiBloc, OverlayUiState>(
          bloc: bloc,
          buildWhen:
              (oldState, newState) => oldState.sleepTime != newState.sleepTime,
          builder: (context, state) {
            return ListTile(
              leading:
                  isTouch
                      ? IconButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          bloc.add(
                            SetActivePanel(playerPanel: PlayerPanel.settings),
                          );
                        },
                        icon: Icon(Icons.arrow_back),
                      )
                      : const Icon(Icons.timelapse),
              trailing:
                  isTouch
                      ? IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close),
                      )
                      : null,
              title: const Text('Sleep Timer'),
              titleTextStyle: Theme.of(context).textTheme.headlineMedium,
              subtitle: Visibility(
                visible: state.sleepTime != Duration.zero,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 5,
                  children: [
                    const Icon(
                      Icons.access_time_filled_outlined,
                      color: Colors.white60,
                      size: 20,
                    ),
                    Text(
                      state.sleepTime.toString().durationClear(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color:
                            state.sleepTime < const Duration(minutes: 4)
                                ? AppTheme.timeWarningColor
                                : Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TimerOptionTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onFocusChange;
  final String? subtitle;
  const _TimerOptionTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.subtitle,
    required this.onFocusChange,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        selected: isSelected,
        autofocus: isSelected,
        focusColor: AppTheme.focusColor,
        onFocusChange: (focus) {
          if (focus == false) onFocusChange();
        },
        title: Text(label),
        onTap: onTap,
        titleTextStyle: Theme.of(context).textTheme.titleLarge,
        leading:
            isSelected ? const Icon(Icons.check) : const SizedBox(width: 24),
        subtitle: subtitle != null ? Text(subtitle!) : null,
      ),
    );
  }
}

class _SleepTimerOption {
  final String label;
  final Duration? duration;
  final bool isOff;
  final bool isAfterFile;
  final String? subtitle;
  const _SleepTimerOption({
    required this.label,
    this.duration,
    this.isOff = false,
    this.isAfterFile = false,
    this.subtitle,
  });
}
