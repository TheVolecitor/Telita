import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../flutter_tv_media3.dart';
import '../../bloc/overlay_ui_bloc.dart';
import '../../media_ui_service/media3_ui_controller.dart';
import 'setup_panel/audio_widget/audio_widget.dart';
import 'setup_panel/playlist_widget/playlist_widget.dart';
import 'setup_panel/settings_screen/settings_screen.dart';
import 'setup_panel/subtitle_widget/subtitle_widget.dart';
import 'setup_panel/video_widget/video_widget.dart';
import 'time_line_panel.dart';

class SetupPanel extends StatefulWidget {
  final Media3UiController controller;
  final int selSettingsTab;
  const SetupPanel({
    super.key,
    required this.controller,
    required this.selSettingsTab,
  });

  @override
  State<SetupPanel> createState() => _SetupPanelState();
}

class _SetupPanelState extends State<SetupPanel> with TickerProviderStateMixin {
  late TabController _tabController;
  late Map<String, IconData> tabs;
  late List<StatefulWidget> screens;

  @override
  void initState() {
    super.initState();

    tabs = {
      OverlayLocalizations.get('playlist'): Icons.playlist_play_sharp,
      OverlayLocalizations.get('video'): Icons.personal_video_outlined,
      OverlayLocalizations.get('audio'): Icons.audiotrack_rounded,
      OverlayLocalizations.get('subtitle'): Icons.subtitles,
      OverlayLocalizations.get('settings'): Icons.settings,
    };

    screens = [
      PlaylistWidget(controller: widget.controller),
      VideoWidget(controller: widget.controller),
      AudioWidget(controller: widget.controller),
      SubtitleWidget(controller: widget.controller),
      SettingsScreen(controller: widget.controller),
    ];

    if (widget.controller.playerState.videoTracks.isEmpty) {
      tabs.remove(OverlayLocalizations.get('video'));
      tabs.remove(OverlayLocalizations.get('subtitle'));
      screens.removeAt(1);
      screens.removeAt(2);
    }
    if (widget.controller.playerState.playlist.length <= 1) {
      tabs.remove(OverlayLocalizations.get('playlist'));
      screens.removeAt(0);
    }
    _tabController = TabController(
      length: screens.length,
      vsync: this,
      initialIndex: widget.selSettingsTab,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight):
            () => _arrowFunction(action: 1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft):
            () => _arrowFunction(action: -1),
        const SingleActivator(LogicalKeyboardKey.contextMenu):
            () => _closeSetupPanel(context),
        const SingleActivator(LogicalKeyboardKey.keyQ):
            () => _closeSetupPanel(context),
      },
      child: Stack(
        children: [
          BlocBuilder<OverlayUiBloc, OverlayUiState>(
            buildWhen:
                (oldState, newState) =>
                    oldState.playIndex != newState.playIndex,
            builder: (context, state) {
              return Material(
                color: AppTheme.backgroundColor,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.backgroundColor),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TabBar(
                        indicatorColor: Colors.blue,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicatorWeight: 2,
                        dividerHeight: 2,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white38,
                        labelStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        unselectedLabelStyle: TextStyle(fontSize: 14),
                        controller: _tabController,
                        tabs:
                            tabs.entries
                                .map(
                                  (e) => Tab(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(e.value),
                                        const SizedBox(width: 8),
                                        Text(e.key),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: screens,
                        ),
                      ),
                      Divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4.0,
                          vertical: 8,
                        ),
                        child: TimeLinePanel(controller: widget.controller),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _closeSetupPanel(BuildContext context) {
    final bloc = context.read<OverlayUiBloc>();
    widget.controller.playerState.stateValue == StateValue.initial
        ? bloc.add(SetActivePanel(playerPanel: PlayerPanel.placeholder))
        : bloc.add(const SetActivePanel(playerPanel: PlayerPanel.none));
  }

  void _arrowFunction({required int action}) {
    final value =
        _tabController.index + action < 0
            ? _tabController.length - 1
            : _tabController.index + action == _tabController.length
            ? 0
            : _tabController.index + action;
    context.read<OverlayUiBloc>().add(SetSetupTabIndex(tabIndex: value));
    _tabController.animateTo(value);
    FocusScopeNode currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus) {
      currentFocus.focusedChild?.unfocus();
    }
  }
}
