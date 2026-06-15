import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tv_media3/src/app_theme/app_theme.dart';
import 'package:flutter_tv_media3/src/overlay/bloc/overlay_ui_bloc.dart';

/// A reusable scaffold for panels that need a title and conditional touch controls.
///
/// This widget provides a consistent layout with a title bar that shows
/// back and close buttons in touch mode, or a simple icon and title otherwise.
class TitledPanelScaffold extends StatelessWidget {
  const TitledPanelScaffold({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  /// The title to be displayed in the header.
  final String title;

  /// The icon to be displayed in non-touch mode.
  final IconData icon;

  /// The main content of the panel.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<OverlayUiBloc>();

    return Container(
      color: AppTheme.backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Material(
          color: Colors.transparent,
          child: BlocSelector<OverlayUiBloc, OverlayUiState, bool>(
            selector: (state) => state.isTouch,
            builder: (context, isTouch) {
              return Column(
                children: [
                  ListTile(
                    leading:
                        isTouch
                            ? IconButton(
                              // In touch mode, 'back' returns to the main touch overlay.
                              onPressed: () {
                                bloc.add(
                                  const SetActivePanel(
                                    playerPanel: PlayerPanel.touchOverlay,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.arrow_back),
                            )
                            : Icon(
                              icon,
                            ), // In D-pad mode, show the panel's icon.
                    trailing:
                        isTouch
                            ? IconButton(
                              // The 'close' button hides all panels.
                              onPressed:
                                  () => bloc.add(
                                    const SetActivePanel(
                                      playerPanel: PlayerPanel.none,
                                    ),
                                  ),
                              icon: const Icon(Icons.close),
                            )
                            : null,
                    title: Text(title),
                    titleTextStyle: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Expanded(child: child),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
