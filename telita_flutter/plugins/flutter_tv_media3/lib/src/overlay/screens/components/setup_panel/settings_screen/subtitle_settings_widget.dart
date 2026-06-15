import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../../flutter_tv_media3.dart';
import '../../../../bloc/overlay_ui_bloc.dart';
import '../../../../media_ui_service/media3_ui_controller.dart';
import 'color_selector_widget.dart';
import 'string_settings_widget.dart';

class SubtitleSettingsWidget extends StatelessWidget {
  final Media3UiController controller;
  final OverlayUiBloc bloc;
  const SubtitleSettingsWidget({
    super.key,
    required this.controller,
    required this.bloc,
  });

  @override
  Widget build(BuildContext context) {
    final defaultSubtitleStyle = SubtitleStyle();
    return BlocSelector<OverlayUiBloc, OverlayUiState, bool>(
      bloc: bloc,
      selector: (state) => state.isTouch,
      builder: (context, isTouch) {
        return StreamBuilder<PlayerState>(
          initialData: controller.playerState,
          stream: controller.playerStateStream,
          builder: (context, snapshot) {
            if (snapshot.hasData == false) {
              return SizedBox.shrink();
            }
            final subtitleStyle = snapshot.data!.subtitleStyle;
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
                          : const Icon(Icons.subtitles_outlined),
                  trailing:
                      isTouch
                          ? IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(Icons.close),
                          )
                          : null,
                  title: Text(OverlayLocalizations.get('subtitleSettings')),
                  titleTextStyle: Theme.of(context).textTheme.headlineMedium,
                ),
                Expanded(
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
                          ColorSelectorWidget(
                            title: OverlayLocalizations.get('fontColor'),
                            onTap: () {
                              controller.updateSubtitleStyle(
                                subtitleStyle: subtitleStyle.copyWith(
                                  foregroundColor:
                                      defaultSubtitleStyle.foregroundColor,
                                ),
                              );
                            },
                            selectedItem:
                                subtitleStyle.foregroundColor?.index ?? 0,
                            saveResult: (int itemIndex) async {
                              controller.updateSubtitleStyle(
                                subtitleStyle: subtitleStyle.copyWith(
                                  foregroundColor:
                                      BasicColors.values[itemIndex],
                                ),
                              );
                            },
                            autofocus: true,
                            colorList: BasicColors.allColors,
                          ),
                          ColorSelectorWidget(
                            title: OverlayLocalizations.get('windowColor'),
                            onTap: () {
                              controller.updateSubtitleStyle(
                                subtitleStyle: subtitleStyle.copyWith(
                                  windowColor: defaultSubtitleStyle.windowColor,
                                ),
                              );
                            },
                            selectedItem: subtitleStyle.windowColor?.index ?? 0,
                            saveResult: (int itemIndex) async {
                              controller.updateSubtitleStyle(
                                subtitleStyle: subtitleStyle.copyWith(
                                  windowColor: ExtendedColors.values[itemIndex],
                                ),
                              );
                            },
                            colorList: ExtendedColors.allColors,
                          ),
                          StringSettingsWidget(
                            bloc: bloc,
                            leftCallback:
                                () async => await _setFontSize(
                                  action: -0.1,
                                  subtitleStyle: subtitleStyle,
                                ),
                            rightCallback:
                                () async => await _setFontSize(
                                  action: 0.1,
                                  subtitleStyle: subtitleStyle,
                                ),
                            enterCallback:
                                () async =>
                                    await controller.updateSubtitleStyle(
                                      subtitleStyle: subtitleStyle.copyWith(
                                        textSizeFraction:
                                            defaultSubtitleStyle
                                                .textSizeFraction,
                                      ),
                                    ),
                            valueTitle:
                                '${((subtitleStyle.textSizeFraction ?? 1) * 100).toStringAsFixed(1)} %',
                            title: OverlayLocalizations.get('fontSize'),
                          ),
                          StringSettingsWidget(
                            bloc: bloc,
                            leftCallback:
                                () async =>
                                    await controller.updateSubtitleStyle(
                                      subtitleStyle: subtitleStyle.copyWith(
                                        applyEmbeddedStyles:
                                            !(subtitleStyle
                                                    .applyEmbeddedStyles ??
                                                true),
                                      ),
                                    ),
                            rightCallback:
                                () async =>
                                    await controller.updateSubtitleStyle(
                                      subtitleStyle: subtitleStyle.copyWith(
                                        applyEmbeddedStyles:
                                            !(subtitleStyle
                                                    .applyEmbeddedStyles ??
                                                true),
                                      ),
                                    ),
                            enterCallback:
                                () async =>
                                    await controller.updateSubtitleStyle(
                                      subtitleStyle: subtitleStyle.copyWith(
                                        applyEmbeddedStyles:
                                            defaultSubtitleStyle
                                                .applyEmbeddedStyles,
                                      ),
                                    ),
                            valueTitle:
                                subtitleStyle.applyEmbeddedStyles == true
                                    ? OverlayLocalizations.get('yes')
                                    : OverlayLocalizations.get('no'),
                            title: OverlayLocalizations.get(
                              'applyEmbeddedStyles',
                            ),
                          ),
                          StringSettingsWidget(
                            bloc: bloc,
                            leftCallback:
                                () async => await _setPadding(
                                  action: -1,
                                  subtitleStyle: subtitleStyle,
                                  side: Side.bottom,
                                ),
                            rightCallback:
                                () async => await _setPadding(
                                  action: 1,
                                  subtitleStyle: subtitleStyle,
                                  side: Side.bottom,
                                ),
                            enterCallback:
                                () async =>
                                    await controller.updateSubtitleStyle(
                                      subtitleStyle: subtitleStyle.copyWith(
                                        bottomPadding:
                                            defaultSubtitleStyle.bottomPadding,
                                      ),
                                    ),
                            valueTitle:
                                '${subtitleStyle.bottomPadding ?? 0} px',
                            title: OverlayLocalizations.get('bottomPadding'),
                          ),
                          StringSettingsWidget(
                            bloc: bloc,
                            leftCallback:
                                () async => await _setPadding(
                                  action: -1,
                                  subtitleStyle: subtitleStyle,
                                  side: Side.left,
                                ),
                            rightCallback:
                                () async => await _setPadding(
                                  action: 1,
                                  subtitleStyle: subtitleStyle,
                                  side: Side.left,
                                ),
                            enterCallback:
                                () async =>
                                    await controller.updateSubtitleStyle(
                                      subtitleStyle: subtitleStyle.copyWith(
                                        leftPadding:
                                            defaultSubtitleStyle.leftPadding,
                                      ),
                                    ),
                            valueTitle: '${subtitleStyle.leftPadding ?? 0} px',
                            title: OverlayLocalizations.get('leftPadding'),
                          ),
                          StringSettingsWidget(
                            bloc: bloc,
                            leftCallback:
                                () async => await _setPadding(
                                  action: -1,
                                  subtitleStyle: subtitleStyle,
                                  side: Side.right,
                                ),
                            rightCallback:
                                () async => await _setPadding(
                                  action: 1,
                                  subtitleStyle: subtitleStyle,
                                  side: Side.right,
                                ),
                            enterCallback:
                                () async =>
                                    await controller.updateSubtitleStyle(
                                      subtitleStyle: subtitleStyle.copyWith(
                                        rightPadding:
                                            defaultSubtitleStyle.rightPadding,
                                      ),
                                    ),
                            valueTitle: '${subtitleStyle.rightPadding ?? 0} px',
                            title: OverlayLocalizations.get('rightPadding'),
                          ),
                          StringSettingsWidget(
                            bloc: bloc,
                            leftCallback:
                                () async => await _setPadding(
                                  action: -1,
                                  subtitleStyle: subtitleStyle,
                                  side: Side.top,
                                ),
                            rightCallback:
                                () async => await _setPadding(
                                  action: 1,
                                  subtitleStyle: subtitleStyle,
                                  side: Side.top,
                                ),
                            enterCallback:
                                () async =>
                                    await controller.updateSubtitleStyle(
                                      subtitleStyle: subtitleStyle.copyWith(
                                        topPadding:
                                            defaultSubtitleStyle.topPadding,
                                      ),
                                    ),
                            valueTitle: '${subtitleStyle.topPadding ?? 0} px',
                            title: OverlayLocalizations.get('topPadding'),
                          ),
                          StringSettingsWidget(
                            bloc: bloc,
                            leftCallback:
                                () async => await _setEdgeType(
                                  action: -1,
                                  subtitleStyle: subtitleStyle,
                                ),
                            rightCallback:
                                () async => await _setEdgeType(
                                  action: 1,
                                  subtitleStyle: subtitleStyle,
                                ),
                            enterCallback:
                                () async =>
                                    await controller.updateSubtitleStyle(
                                      subtitleStyle: subtitleStyle.copyWith(
                                        edgeType: defaultSubtitleStyle.edgeType,
                                      ),
                                    ),
                            valueTitle:
                                (subtitleStyle.edgeType?.name ??
                                        SubtitleEdgeType.dropShadow.name)
                                    .toUpperCase(),
                            title: OverlayLocalizations.get('edgeType'),
                          ),
                          ColorSelectorWidget(
                            title: OverlayLocalizations.get('edgeColor'),
                            onTap: () {
                              controller.updateSubtitleStyle(
                                subtitleStyle: subtitleStyle.copyWith(
                                  edgeColor: defaultSubtitleStyle.edgeColor,
                                ),
                              );
                            },
                            selectedItem: subtitleStyle.edgeColor?.index ?? 0,
                            saveResult: (int itemIndex) async {
                              controller.updateSubtitleStyle(
                                subtitleStyle: subtitleStyle.copyWith(
                                  edgeColor: BasicColors.values[itemIndex],
                                ),
                              );
                            },
                            colorList: BasicColors.allColors,
                          ),
                          ColorSelectorWidget(
                            title: OverlayLocalizations.get('backgroundColor'),
                            onTap: () {
                              controller.updateSubtitleStyle(
                                subtitleStyle: subtitleStyle.copyWith(
                                  backgroundColor:
                                      defaultSubtitleStyle.backgroundColor,
                                ),
                              );
                            },
                            selectedItem:
                                subtitleStyle.backgroundColor?.index ?? 0,
                            saveResult: (int itemIndex) async {
                              controller.updateSubtitleStyle(
                                subtitleStyle: subtitleStyle.copyWith(
                                  backgroundColor:
                                      ExtendedColors.values[itemIndex],
                                ),
                              );
                            },
                            colorList: ExtendedColors.allColors,
                          ),
                          ListTile(
                            onTap:
                                () => controller.updateSubtitleStyle(
                                  subtitleStyle: defaultSubtitleStyle,
                                ),
                            title: Text(
                              OverlayLocalizations.get('resetAllToDefault'),
                            ),
                            focusColor: AppTheme.focusColor,
                            titleTextStyle:
                                Theme.of(context).textTheme.titleLarge,
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

  Future<void> _setEdgeType({
    required SubtitleStyle subtitleStyle,
    required int action,
  }) async {
    final index = subtitleStyle.edgeType?.index ?? 0;
    final edgeType = SubtitleEdgeType.changeValue(
      index: index,
      direction: action,
    );
    await controller.updateSubtitleStyle(
      subtitleStyle: subtitleStyle.copyWith(edgeType: edgeType),
    );
  }

  Future<void> _setPadding({
    required SubtitleStyle subtitleStyle,
    required int action,
    required Side side,
  }) async {
    final currentPadding = switch (side) {
      Side.bottom => subtitleStyle.bottomPadding ?? 0,
      Side.top => subtitleStyle.topPadding ?? 0,
      Side.left => subtitleStyle.leftPadding ?? 0,
      Side.right => subtitleStyle.rightPadding ?? 0,
    };

    final newPadding =
        currentPadding + action > 200
            ? 0
            : currentPadding + action < 0
            ? 200
            : currentPadding + action;

    final newStyle = switch (side) {
      Side.bottom => subtitleStyle.copyWith(bottomPadding: newPadding),
      Side.top => subtitleStyle.copyWith(topPadding: newPadding),
      Side.left => subtitleStyle.copyWith(leftPadding: newPadding),
      Side.right => subtitleStyle.copyWith(rightPadding: newPadding),
    };

    await controller.updateSubtitleStyle(subtitleStyle: newStyle);
  }

  Future<void> _setFontSize({
    required SubtitleStyle subtitleStyle,
    required double action,
  }) async {
    final textSizeFraction = subtitleStyle.textSizeFraction ?? 1;
    final fontSize = double.parse(
      (textSizeFraction + action > 3.0
              ? 0.1
              : textSizeFraction < 0.1
              ? 3.0
              : textSizeFraction + action)
          .toStringAsFixed(1),
    );
    await controller.updateSubtitleStyle(
      subtitleStyle: subtitleStyle.copyWith(textSizeFraction: fontSize),
    );
  }
}

enum Side { left, right, bottom, top }
