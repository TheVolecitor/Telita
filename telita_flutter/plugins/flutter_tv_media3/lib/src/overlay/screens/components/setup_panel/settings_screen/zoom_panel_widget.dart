import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tv_media3/src/localization/overlay_localizations.dart';
import '../../../../../app_theme/app_theme.dart';
import '../../../../../entity/player_state.dart';
import '../../../../bloc/overlay_ui_bloc.dart';
import '../../../../media_ui_service/media3_ui_controller.dart';

class ZoomPanelWidget extends StatefulWidget {
  const ZoomPanelWidget({
    super.key,
    required this.controller,
    required this.bloc,
  });
  final Media3UiController controller;
  final OverlayUiBloc bloc;

  @override
  State<ZoomPanelWidget> createState() => _ZoomPanelWidgetState();
}

class _ZoomPanelWidgetState extends State<ZoomPanelWidget> {
  bool isEditScale = false;
  double scaleX = 1;
  double scaleY = 1;
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocSelector<OverlayUiBloc, OverlayUiState, bool>(
      bloc: widget.bloc,
      selector: (state) => state.isTouch,
      builder: (context, isTouch) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ListTile(
              leading:
                  isTouch == true
                      ? IconButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.bloc.add(
                            SetActivePanel(playerPanel: PlayerPanel.settings),
                          );
                        },
                        icon: Icon(Icons.arrow_back),
                      )
                      : const Icon(Icons.subtitles_outlined),
              trailing:
                  isTouch == true
                      ? IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.zoom_in),
                      )
                      : null,
              title: Text(OverlayLocalizations.get('zoom')),
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
              child: StreamBuilder<PlayerState>(
                initialData: widget.controller.playerState,
                stream: widget.controller.playerStateStream,
                builder: (context, snapshot) {
                  if (snapshot.hasData == false) {
                    return const SizedBox.shrink();
                  }
                  return ListView(
                    shrinkWrap: true,
                    children:
                        PlayerZoom.values
                            .map(
                              (e) =>
                                  e == PlayerZoom.scale
                                      ? CallbackShortcuts(
                                        bindings:
                                            isEditScale == true
                                                ? {
                                                  const SingleActivator(
                                                        LogicalKeyboardKey
                                                            .arrowLeft,
                                                      ):
                                                      () => _updateScale(
                                                        dx: -0.1,
                                                      ),
                                                  const SingleActivator(
                                                        LogicalKeyboardKey
                                                            .arrowRight,
                                                      ):
                                                      () =>
                                                          _updateScale(dx: 0.1),
                                                  const SingleActivator(
                                                    LogicalKeyboardKey.arrowUp,
                                                  ): () =>
                                                          _updateScale(dy: 0.1),
                                                  const SingleActivator(
                                                        LogicalKeyboardKey
                                                            .arrowDown,
                                                      ):
                                                      () => _updateScale(
                                                        dy: -0.1,
                                                      ),
                                                }
                                                : {},
                                        child: Material(
                                          color: Colors.transparent,
                                          child: ListTile(
                                            selected: e == snapshot.data!.zoom,
                                            autofocus: e == snapshot.data!.zoom,
                                            focusColor: AppTheme.focusColor,
                                            title: Text(
                                              '${e.nativeValue.replaceAll('_', ' ')}: X${scaleX.toStringAsFixed(1)}, Y${scaleY.toStringAsFixed(1)}',
                                            ),
                                            subtitle:
                                                isEditScale == false
                                                    ? Text(
                                                      OverlayLocalizations.get(
                                                        'enterToEdit',
                                                      ),
                                                    )
                                                    : Text(
                                                      OverlayLocalizations.get(
                                                        'enterToSaveAndExit',
                                                      ),
                                                    ),
                                            trailing:
                                                isEditScale == true
                                                    ? const Icon(
                                                      Icons.control_camera,
                                                    )
                                                    : null,
                                            onTap:
                                                () async => setState(() {
                                                  isEditScale = !isEditScale;
                                                  if (isEditScale == false) {
                                                    Navigator.pop(context);
                                                  }
                                                }),
                                            titleTextStyle:
                                                Theme.of(
                                                  context,
                                                ).textTheme.titleLarge,
                                            leading:
                                                isEditScale == true ||
                                                        e == snapshot.data!.zoom
                                                    ? const Icon(Icons.check)
                                                    : null,
                                          ),
                                        ),
                                      )
                                      : Material(
                                        color: Colors.transparent,
                                        child: ListTile(
                                          selected: e == snapshot.data!.zoom,
                                          autofocus: e == snapshot.data!.zoom,
                                          focusColor: AppTheme.focusColor,
                                          title: Text(
                                            e.nativeValue.replaceAll('_', ' '),
                                          ),
                                          onTap:
                                              () async => await widget
                                                  .controller
                                                  .setZoom(zoom: e),
                                          titleTextStyle:
                                              Theme.of(
                                                context,
                                              ).textTheme.titleLarge,
                                          leading:
                                              e == snapshot.data!.zoom &&
                                                      isEditScale == false
                                                  ? const Icon(Icons.check)
                                                  : null,
                                        ),
                                      ),
                            )
                            .toList(),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _returnToMenu({required BuildContext context}) {
    Navigator.pop(context);
    widget.bloc.add(const SetActivePanel(playerPanel: PlayerPanel.setup));
  }

  void _updateScale({double dx = 0.0, double dy = 0.0}) {
    final newScaleX = scaleX + dx;
    final newScaleY = scaleY + dy;
    setState(() {
      scaleX = newScaleX.clamp(0.0, 3.0);
      scaleY = newScaleY.clamp(0.0, 3.0);
      widget.controller.setScale(scaleX: scaleX, scaleY: scaleY);
    });
  }
}
