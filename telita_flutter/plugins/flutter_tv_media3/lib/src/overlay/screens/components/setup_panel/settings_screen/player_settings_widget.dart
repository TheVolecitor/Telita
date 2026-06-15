import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../../flutter_tv_media3.dart';
import '../../../../bloc/overlay_ui_bloc.dart';
import '../../../../media_ui_service/media3_ui_controller.dart';
import '../../widgets/show_side_sheet.dart';
import 'multi_language_selector.dart';
import 'refresh_rate_selector_widget.dart';
import 'string_settings_widget.dart';

class PlayerSettingsWidget extends StatelessWidget {
  final Media3UiController controller;
  final OverlayUiBloc bloc;
  const PlayerSettingsWidget({
    super.key,
    required this.controller,
    required this.bloc,
  });

  @override
  Widget build(BuildContext context) {
    final defaultPlayerSettings = PlayerSettings();
    return BlocSelector<OverlayUiBloc, OverlayUiState, bool>(
      bloc: bloc,
      selector: (state) => state.isTouch,
      builder: (context, isTouch) {
        return StreamBuilder<PlayerState>(
          initialData: controller.playerState,
          stream: controller.playerStateStream,
          builder: (context, snapshot) {
            if (snapshot.hasData == false) return SizedBox.shrink();
            final playerSettings = snapshot.data!.playerSettings;
            return Column(
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
                          : const Icon(Icons.settings_applications_outlined),
                  trailing:
                      isTouch
                          ? IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(Icons.close),
                          )
                          : null,
                  title: Text(OverlayLocalizations.get('playerSettings')),
                  titleTextStyle: Theme.of(context).textTheme.headlineMedium,
                ),
                Flexible(
                  child: CallbackShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.arrowLeft):
                          () => Navigator.of(context).pop(),
                      const SingleActivator(LogicalKeyboardKey.arrowRight):
                          () => Navigator.of(context).pop(),
                      const SingleActivator(LogicalKeyboardKey.contextMenu):
                          () => Navigator.of(context).pop(),
                      const SingleActivator(LogicalKeyboardKey.keyQ):
                          () => Navigator.of(context).pop(),
                    },
                    child: Scrollbar(
                      thumbVisibility: true,
                      trackVisibility: true,
                      radius: Radius.circular(50),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          StringSettingsWidget(
                            autofocus: true,
                            leftCallback:
                                () async => await _setVideoQuality(
                                  action: -1,
                                  playerSettings: playerSettings,
                                ),
                            rightCallback:
                                () async => await _setVideoQuality(
                                  action: 1,
                                  playerSettings: playerSettings,
                                ),
                            enterCallback:
                                () async => await controller.savePlayerSettings(
                                  playerSettings: playerSettings.copyWith(
                                    videoQuality:
                                        defaultPlayerSettings.videoQuality,
                                  ),
                                ),
                            valueTitle:
                                (playerSettings.videoQuality.name)
                                    .toUpperCase(),
                            title: OverlayLocalizations.get('videoQuality'),
                            bloc: bloc,
                          ),
                          StringSettingsWidget(
                            bloc: bloc,
                            leftCallback:
                                () async => await controller.savePlayerSettings(
                                  playerSettings: playerSettings.copyWith(
                                    forceHighestBitrate:
                                        !playerSettings.forceHighestBitrate,
                                  ),
                                ),
                            rightCallback:
                                () async => await controller.savePlayerSettings(
                                  playerSettings: playerSettings.copyWith(
                                    forceHighestBitrate:
                                        !playerSettings.forceHighestBitrate,
                                  ),
                                ),
                            enterCallback:
                                () async => await controller.savePlayerSettings(
                                  playerSettings: playerSettings.copyWith(
                                    forceHighestBitrate:
                                        defaultPlayerSettings
                                            .forceHighestBitrate,
                                  ),
                                ),
                            valueTitle:
                                playerSettings.forceHighestBitrate == true
                                    ? OverlayLocalizations.get('on')
                                    : OverlayLocalizations.get('off'),
                            title: OverlayLocalizations.get(
                              'forceHighestBitrate',
                            ),
                          ),
                          StringSettingsWidget(
                            bloc: bloc,
                            leftCallback:
                                () async => await controller.savePlayerSettings(
                                  playerSettings: playerSettings.copyWith(
                                    isAfrEnabled: !playerSettings.isAfrEnabled,
                                  ),
                                ),
                            rightCallback:
                                () async => await controller.savePlayerSettings(
                                  playerSettings: playerSettings.copyWith(
                                    isAfrEnabled: !playerSettings.isAfrEnabled,
                                  ),
                                ),
                            enterCallback:
                                () async => await controller.savePlayerSettings(
                                  playerSettings: playerSettings.copyWith(
                                    isAfrEnabled:
                                        defaultPlayerSettings.isAfrEnabled,
                                  ),
                                ),
                            valueTitle:
                                playerSettings.isAfrEnabled == true
                                    ? OverlayLocalizations.get('on')
                                    : OverlayLocalizations.get('off'),
                            title: OverlayLocalizations.get('afr'),
                          ),
                          ListTile(
                            enabled: playerSettings.isAfrEnabled == false,
                            title: Text(
                              OverlayLocalizations.get('manualFrameRate'),
                            ),
                            titleTextStyle:
                                Theme.of(context).textTheme.titleLarge,
                            focusColor: AppTheme.focusColor,
                            subtitle: Text(
                              playerSettings.isAfrEnabled == false
                                  ? OverlayLocalizations.get('pressToSelect')
                                  : OverlayLocalizations.get('afrIsEnabled'),
                            ),
                            onTap: () {
                              if (playerSettings.isAfrEnabled == false) {
                                showSideSheet(
                                  context: context,
                                  bloc: bloc,
                                  widthFactor: 0.35,
                                  body: RefreshRateSelectorWidget(
                                    controller: controller,
                                  ),
                                );
                              }
                            },
                          ),
                          StringSettingsWidget(
                            bloc: bloc,
                            leftCallback:
                                () async => await controller.savePlayerSettings(
                                  playerSettings: playerSettings.copyWith(
                                    forcedAutoEnable:
                                        !playerSettings.forcedAutoEnable,
                                  ),
                                ),
                            rightCallback:
                                () async => await controller.savePlayerSettings(
                                  playerSettings: playerSettings.copyWith(
                                    forcedAutoEnable:
                                        !playerSettings.forcedAutoEnable,
                                  ),
                                ),
                            enterCallback:
                                () async => await controller.savePlayerSettings(
                                  playerSettings: playerSettings.copyWith(
                                    forcedAutoEnable:
                                        defaultPlayerSettings.forcedAutoEnable,
                                  ),
                                ),
                            valueTitle:
                                playerSettings.forcedAutoEnable == true
                                    ? OverlayLocalizations.get('yes')
                                    : OverlayLocalizations.get('no'),
                            title: OverlayLocalizations.get(
                              'autoEnableSubtitle',
                            ),
                          ),
                          ListTile(
                            title: Text(
                              OverlayLocalizations.get(
                                'preferredAudioLanguages',
                              ),
                            ),
                            titleTextStyle:
                                Theme.of(context).textTheme.titleLarge,
                            focusColor: AppTheme.focusColor,
                            subtitle: Text(
                              (playerSettings.preferredAudioLanguages ?? [])
                                  .join(', '),
                            ),
                            onTap: () {
                              showSideSheet(
                                context: context,
                                bloc: bloc,
                                widthFactor: 0.35,
                                body: MultiLanguageSelector(
                                  title: OverlayLocalizations.get(
                                    'preferredAudioLanguages',
                                  ),
                                  initiallySelected:
                                      playerSettings.preferredAudioLanguages ??
                                      [],
                                  onChanged: (
                                    List<String> selectedCodes,
                                  ) async {
                                    await controller.savePlayerSettings(
                                      playerSettings: playerSettings.copyWith(
                                        preferredAudioLanguages: selectedCodes,
                                      ),
                                    );
                                  },
                                  bloc: bloc,
                                  controller: controller,
                                ),
                              );
                            },
                          ),
                          ListTile(
                            title: Text(
                              OverlayLocalizations.get(
                                'preferredSubtitleLanguages',
                              ),
                            ),
                            titleTextStyle:
                                Theme.of(context).textTheme.titleLarge,
                            focusColor: AppTheme.focusColor,
                            subtitle: Text(
                              (playerSettings.preferredTextLanguages ?? [])
                                  .join(', '),
                            ),
                            onTap: () {
                              showSideSheet(
                                context: context,
                                bloc: bloc,
                                widthFactor: 0.35,
                                body: MultiLanguageSelector(
                                  title: OverlayLocalizations.get(
                                    'preferredSubtitleLanguages',
                                  ),
                                  initiallySelected:
                                      playerSettings.preferredTextLanguages ??
                                      [],
                                  onChanged: (
                                    List<String> selectedCodes,
                                  ) async {
                                    await controller.savePlayerSettings(
                                      playerSettings: playerSettings.copyWith(
                                        preferredTextLanguages: selectedCodes,
                                      ),
                                    );
                                  },
                                  controller: controller,
                                  bloc: bloc,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _setVideoQuality({
    required PlayerSettings playerSettings,
    required int action,
  }) async {
    final index = playerSettings.videoQuality.index;
    final videoQuality = VideoQuality.changeValue(
      index: index,
      direction: action,
    );
    await controller.savePlayerSettings(
      playerSettings: playerSettings.copyWith(videoQuality: videoQuality),
    );
  }
}
