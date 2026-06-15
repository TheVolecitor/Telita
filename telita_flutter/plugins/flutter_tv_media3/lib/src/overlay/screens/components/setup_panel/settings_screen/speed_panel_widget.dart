import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../../flutter_tv_media3.dart';
import '../../../../bloc/overlay_ui_bloc.dart';
import '../../../../media_ui_service/media3_ui_controller.dart';

class SpeedPanelWidget extends StatelessWidget {
  const SpeedPanelWidget({
    super.key,
    required this.controller,
    required this.bloc,
  });
  final Media3UiController controller;
  final OverlayUiBloc bloc;
  @override
  Widget build(BuildContext context) {
    final List<double> speedList = [0.25, 0.50, 0.75, 1, 1.25, 1.50, 1.75, 2];
    return BlocSelector<OverlayUiBloc, OverlayUiState, bool>(
      bloc: bloc,
      selector: (state) => state.isTouch,
      builder: (context, isTouch) {
        return StreamBuilder<PlayerState>(
          stream: controller.playerStateStream,
          initialData: controller.playerState,
          builder: (context, snapshot) {
            if (snapshot.hasData == false) {
              return SizedBox.shrink();
            }
            final currentSpeed = snapshot.data?.speed;
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
                          : const Icon(Icons.speed),
                  trailing:
                      isTouch
                          ? IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(Icons.close),
                          )
                          : null,
                  title: Text(OverlayLocalizations.get('speed')),
                  titleTextStyle: Theme.of(context).textTheme.headlineMedium,
                ),
                Expanded(
                  child: CallbackShortcuts(
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
                      children:
                          speedList
                              .map(
                                (e) => Material(
                                  color: Colors.transparent,
                                  child: ListTile(
                                    selected: e == currentSpeed,
                                    autofocus: e == currentSpeed,
                                    focusColor: AppTheme.focusColor,
                                    title: Text('${e}x'),
                                    onTap:
                                        () async =>
                                            await controller.setSpeed(speed: e),
                                    titleTextStyle:
                                        Theme.of(context).textTheme.titleLarge,
                                    leading:
                                        e == currentSpeed
                                            ? const Icon(Icons.check)
                                            : null,
                                  ),
                                ),
                              )
                              .toList(),
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

  void _returnToMenu({required BuildContext context}) {
    Navigator.pop(context);
    bloc.add(const SetActivePanel(playerPanel: PlayerPanel.setup));
  }
}
