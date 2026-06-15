import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../../flutter_tv_media3.dart';
import '../../../../bloc/overlay_ui_bloc.dart';
import '../../../../media_ui_service/media3_ui_controller.dart';
import 'color_selector_widget.dart';
import 'string_settings_widget.dart';

class ClockSettingsWidget extends StatelessWidget {
  final Media3UiController controller;
  final OverlayUiBloc bloc;
  const ClockSettingsWidget({
    super.key,
    required this.controller,
    required this.bloc,
  });

  void _returnToMenu({required BuildContext context}) {
    Navigator.pop(context);
    bloc.add(const SetActivePanel(playerPanel: PlayerPanel.setup));
  }

  @override
  Widget build(BuildContext context) {
    final defaultSettings = ClockSettings();

    return BlocSelector<OverlayUiBloc, OverlayUiState, bool>(
      bloc: bloc,
      selector: (state) => state.isTouch,
      builder: (context, isTouch) {
        return BlocBuilder<OverlayUiBloc, OverlayUiState>(
          bloc: bloc,
          buildWhen:
              (oldState, newState) =>
                  oldState.clockSettings != newState.clockSettings,
          builder: (context, state) {
            return SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ListTile(
                    leading:
                        isTouch
                            ? IconButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                bloc.add(
                                  SetActivePanel(
                                    playerPanel: PlayerPanel.settings,
                                  ),
                                );
                              },
                              icon: Icon(Icons.arrow_back),
                            )
                            : const Icon(Icons.access_time),
                    trailing:
                        isTouch
                            ? IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: Icon(Icons.close),
                            )
                            : null,
                    title: Text(
                      OverlayLocalizations.get('clock'),
                      textAlign: TextAlign.center,
                    ),
                    titleTextStyle: Theme.of(context).textTheme.headlineMedium,
                  ),
                  CallbackShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.arrowLeft):
                          () => _returnToMenu(context: context),
                      const SingleActivator(LogicalKeyboardKey.arrowRight):
                          () => _returnToMenu(context: context),
                      const SingleActivator(LogicalKeyboardKey.contextMenu):
                          () => _returnToMenu(context: context),
                      const SingleActivator(LogicalKeyboardKey.keyQ):
                          () => _returnToMenu(context: context),
                    },
                    child: ListView(
                      shrinkWrap: true,
                      physics:
                          const NeverScrollableScrollPhysics(), // Disable inner ListView scrolling
                      children: [
                        StringSettingsWidget(
                          bloc: bloc,
                          autofocus: true,
                          leftCallback:
                              () async => await _setClockPosition(
                                action: -1,
                                clockSettings: state.clockSettings,
                              ),
                          rightCallback:
                              () async => await _setClockPosition(
                                action: 1,
                                clockSettings: state.clockSettings,
                              ),
                          enterCallback:
                              () async => await _saveClockSettings(
                                clockSettings: state.clockSettings.copyWith(
                                  clockPosition: defaultSettings.clockPosition,
                                ),
                              ),
                          valueTitle: state.clockSettings.clockPosition.title,
                          title: OverlayLocalizations.get('clockPosition'),
                        ),
                        ColorSelectorWidget(
                          title: OverlayLocalizations.get('clockColor'),
                          onTap:
                              () async => await _saveClockSettings(
                                clockSettings: state.clockSettings.copyWith(
                                  clockColor: defaultSettings.clockColor,
                                ),
                              ),
                          selectedItem: state.clockSettings.clockColor.index,
                          saveResult:
                              (int itemIndex) async => await _saveClockSettings(
                                clockSettings: state.clockSettings.copyWith(
                                  clockColor: ExtendedColors.values[itemIndex],
                                ),
                              ),
                          colorList: ExtendedColors.allColors,
                        ),
                        StringSettingsWidget(
                          bloc: bloc,
                          leftCallback:
                              () async => await _saveClockSettings(
                                clockSettings: state.clockSettings.copyWith(
                                  showClockBorder:
                                      !state.clockSettings.showClockBorder,
                                ),
                              ),
                          rightCallback:
                              () async => await _saveClockSettings(
                                clockSettings: state.clockSettings.copyWith(
                                  showClockBorder:
                                      !state.clockSettings.showClockBorder,
                                ),
                              ),
                          enterCallback:
                              () async => await _saveClockSettings(
                                clockSettings: state.clockSettings.copyWith(
                                  showClockBorder: true,
                                ),
                              ),
                          valueTitle:
                              state.clockSettings.showClockBorder == true
                                  ? OverlayLocalizations.get('yes')
                                  : OverlayLocalizations.get('no'),
                          title: OverlayLocalizations.get('clockBorder'),
                        ),
                        ColorSelectorWidget(
                          title: OverlayLocalizations.get('borderColor'),
                          onTap:
                              () async => await _saveClockSettings(
                                clockSettings: state.clockSettings.copyWith(
                                  borderColor: defaultSettings.borderColor,
                                ),
                              ),
                          selectedItem: state.clockSettings.borderColor.index,
                          saveResult:
                              (int itemIndex) async => await _saveClockSettings(
                                clockSettings: state.clockSettings.copyWith(
                                  borderColor: ExtendedColors.values[itemIndex],
                                ),
                              ),
                          colorList: ExtendedColors.allColors,
                        ),
                        StringSettingsWidget(
                          bloc: bloc,
                          leftCallback:
                              () async => await _saveClockSettings(
                                clockSettings: state.clockSettings.copyWith(
                                  showClockBackground:
                                      !state.clockSettings.showClockBackground,
                                ),
                              ),
                          rightCallback:
                              () async => await _saveClockSettings(
                                clockSettings: state.clockSettings.copyWith(
                                  showClockBackground:
                                      !state.clockSettings.showClockBackground,
                                ),
                              ),
                          enterCallback:
                              () async => await _saveClockSettings(
                                clockSettings: state.clockSettings.copyWith(
                                  showClockBackground:
                                      defaultSettings.showClockBackground,
                                ),
                              ),
                          valueTitle:
                              state.clockSettings.showClockBackground == true
                                  ? OverlayLocalizations.get('yes')
                                  : OverlayLocalizations.get('no'),
                          title: OverlayLocalizations.get('clockBackground'),
                        ),
                        ColorSelectorWidget(
                          title: OverlayLocalizations.get('backgroundColor'),
                          onTap:
                              () async => await _saveClockSettings(
                                clockSettings: state.clockSettings.copyWith(
                                  backgroundColor:
                                      defaultSettings.backgroundColor,
                                ),
                              ),
                          selectedItem:
                              state.clockSettings.backgroundColor.index,
                          saveResult:
                              (int itemIndex) async => await _saveClockSettings(
                                clockSettings: state.clockSettings.copyWith(
                                  backgroundColor:
                                      ExtendedColors.values[itemIndex],
                                ),
                              ),
                          colorList: ExtendedColors.allColors,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _setClockPosition({
    required int action,
    required ClockSettings clockSettings,
  }) async {
    final index = clockSettings.clockPosition.index;
    final clockPosition = ClockPosition.changeValue(
      index: index,
      direction: action,
    );
    final newSettings = clockSettings.copyWith(clockPosition: clockPosition);
    _saveClockSettings(clockSettings: newSettings);
  }

  Future<void> _saveClockSettings({
    required ClockSettings clockSettings,
  }) async {
    bloc.add(SetClockSettings(clockSettings: clockSettings));
    await controller.saveClockSettings(clockSettings: clockSettings);
  }
}
