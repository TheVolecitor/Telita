import 'package:flutter_tv_media3/src/app_theme/app_theme.dart';
import 'package:flutter_tv_media3/src/localization/overlay_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tv_media3/src/entity/player_state.dart';
import 'package:flutter_tv_media3/src/overlay/bloc/overlay_ui_bloc.dart';
import 'package:flutter_tv_media3/src/overlay/media_ui_service/media3_ui_controller.dart';
import 'package:flutter_tv_media3/src/overlay/screens/components/setup_panel/settings_screen/clock_settings_widget.dart';
import 'package:flutter_tv_media3/src/overlay/screens/components/setup_panel/settings_screen/player_settings_widget.dart';
import 'package:flutter_tv_media3/src/overlay/screens/components/setup_panel/settings_screen/sleep_timer_widget.dart';
import 'package:flutter_tv_media3/src/overlay/screens/components/setup_panel/settings_screen/speed_panel_widget.dart';
import 'package:flutter_tv_media3/src/overlay/screens/components/setup_panel/settings_screen/subtitle_settings_widget.dart';
import 'package:flutter_tv_media3/src/overlay/screens/components/setup_panel/settings_screen/zoom_panel_widget.dart';
import 'package:flutter_tv_media3/src/overlay/screens/components/widgets/show_side_sheet.dart';
import 'package:flutter_tv_media3/src/utils/string_utils.dart';

class SettingsScreen extends StatefulWidget {
  final Media3UiController controller;
  const SettingsScreen({super.key, required this.controller});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final ScrollController _scrollController;
  final FocusNode _focusNode = FocusNode();
  int _selectedIndex = 0;
  static const double _itemExtent = AppTheme.customListItemExtent;

  late final List<SettingsItem> items;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    final bloc = context.read<OverlayUiBloc>();
    items = _getSettingsItems(bloc: bloc);
    _selectedIndex = bloc.state.settingsItemIndex;
    if (_selectedIndex >= items.length) {
      _selectedIndex = 0;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollToIndex(_selectedIndex);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients ||
        !_scrollController.position.hasContentDimensions ||
        items.isEmpty ||
        index < 0 ||
        index >= items.length) {
      return;
    }

    final viewportHeight = _scrollController.position.viewportDimension;
    final maxScroll = _scrollController.position.maxScrollExtent;

    double targetOffset =
        (index * _itemExtent) - (viewportHeight / 2) + (_itemExtent / 2);
    targetOffset = targetOffset.clamp(0.0, maxScroll);

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  void _handleKeyEvent(Function action) {
    if (!mounted) return;
    setState(() {
      action();
    });
  }

  Map<ShortcutActivator, VoidCallback> _getShortcuts() {
    return {
      const SingleActivator(LogicalKeyboardKey.arrowUp):
          () => _handleKeyEvent(() {
            if (_selectedIndex > 0) {
              _selectedIndex--;
              _scrollToIndex(_selectedIndex);
              context.read<OverlayUiBloc>().add(
                SetSettingsItemIndex(index: _selectedIndex),
              );
            } else {
              _selectedIndex = items.length - 1;
              _scrollToIndex(_selectedIndex);
              context.read<OverlayUiBloc>().add(
                SetSettingsItemIndex(index: _selectedIndex),
              );
            }
          }),
      const SingleActivator(LogicalKeyboardKey.arrowDown):
          () => _handleKeyEvent(() {
            if (_selectedIndex < items.length - 1) {
              _selectedIndex++;
              _scrollToIndex(_selectedIndex);
              context.read<OverlayUiBloc>().add(
                SetSettingsItemIndex(index: _selectedIndex),
              );
            } else {
              _selectedIndex = 0;
              _scrollToIndex(_selectedIndex);
              context.read<OverlayUiBloc>().add(
                SetSettingsItemIndex(index: _selectedIndex),
              );
            }
          }),
      const SingleActivator(LogicalKeyboardKey.enter):
          () => _handleKeyEvent(() {
            if (_selectedIndex < items.length) {
              items[_selectedIndex].onTap?.call(context);
              if (items[_selectedIndex].onPlayerTap != null) {
                items[_selectedIndex].onPlayerTap!(
                  context,
                  widget.controller.playerState,
                );
              }
            }
          }),
      const SingleActivator(LogicalKeyboardKey.select):
          () => _handleKeyEvent(() {
            if (_selectedIndex < items.length) {
              items[_selectedIndex].onTap?.call(context);
              if (items[_selectedIndex].onPlayerTap != null) {
                items[_selectedIndex].onPlayerTap!(
                  context,
                  widget.controller.playerState,
                );
              }
            }
          }),
    };
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: _getShortcuts(),
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: Material(
          color: Colors.transparent,
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            trackVisibility: true,
            radius: const Radius.circular(50),
            child: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: items.length,
                itemExtent: _itemExtent,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return item.build(
                    context,
                    isFocused: index == _selectedIndex,
                    controller: widget.controller,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<SettingsItem> _getSettingsItems({required OverlayUiBloc bloc}) => [
    SettingsItem(
      icon: Icons.settings_applications_outlined,
      title: OverlayLocalizations.get('playerSettings'),
      onTap: (context) {
        bloc.add(const SetActivePanel(playerPanel: PlayerPanel.none));
        showSideSheet(
          context: context,
          bloc: bloc,
          widthFactor: 0.35,
          body: PlayerSettingsWidget(controller: widget.controller, bloc: bloc),
        );
      },
    ),
    SettingsItem(
      icon: Icons.timelapse,
      title: OverlayLocalizations.get('sleepTimer'),
      trailingBuilder:
          (context) => BlocBuilder<OverlayUiBloc, OverlayUiState>(
            bloc: bloc,
            buildWhen:
                (old, now) =>
                    old.sleepTime != now.sleepTime ||
                    old.sleepAfter != now.sleepAfter,
            builder: (context, state) {
              final textTheme = Theme.of(context).textTheme.headlineSmall!;
              if (state.sleepTime != Duration.zero) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 5,
                  children: [
                    const Icon(
                      Icons.access_time_filled_outlined,
                      color: Colors.grey,
                    ),
                    Text(
                      state.sleepTime.toString().durationClear(),
                      style: textTheme,
                    ),
                  ],
                );
              }
              if (state.sleepAfter) {
                return Text(
                  state.sleepAfterNext == true
                      ? OverlayLocalizations.get('afterNextFile')
                      : OverlayLocalizations.get('afterThisFile'),
                  style: textTheme,
                );
              }
              return Text(OverlayLocalizations.get('off'), style: textTheme);
            },
          ),
      onTap: (context) {
        final bloc = context.read<OverlayUiBloc>();
        bloc.add(const SetActivePanel(playerPanel: PlayerPanel.none));
        showSideSheet(
          context: context,
          bloc: bloc,
          body: SleepTimerWidget(bloc: bloc),
        );
      },
    ),
    SettingsItem(
      icon: Icons.zoom_in,
      title: OverlayLocalizations.get('zoom'),
      trailingBuilder:
          (context) => Text(
            widget.controller.playerState.zoom.nativeValue,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
      onTap: (context) {
        bloc.add(const SetActivePanel(playerPanel: PlayerPanel.none));
        showSideSheet(
          context: context,
          bloc: bloc,
          body: ZoomPanelWidget(controller: widget.controller, bloc: bloc),
        );
      },
    ),
    SettingsItem(
      icon: Icons.speed,
      title: OverlayLocalizations.get('speed'),
      trailingBuilder:
          (context) => Text(
            '${widget.controller.playerState.speed}x',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
      onTap: (context) {
        bloc.add(const SetActivePanel(playerPanel: PlayerPanel.none));
        showSideSheet(
          context: context,
          bloc: bloc,
          body: SpeedPanelWidget(controller: widget.controller, bloc: bloc),
        );
      },
    ),
    SettingsItem(
      iconStreamBuilder:
          (context, playerState) =>
              playerState.repeatMode == PlayerRepeatMode.repeatModeOne
                  ? const Icon(Icons.repeat_one)
                  : playerState.repeatMode == PlayerRepeatMode.repeatModeAll
                  ? const Icon(Icons.repeat)
                  : const Icon(Icons.repeat_on),
      title: OverlayLocalizations.get('repeat'),
      trailingStreamBuilder:
          (context, playerState) => Text(
            playerState.repeatMode.nativeValue.replaceAll('REPEAT_MODE_', ''),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
      onPlayerTap: (context, playerState) {
        widget.controller.setRepeatMode(
          repeatMode: PlayerRepeatMode.nextValue(playerState.repeatMode.index),
        );
      },
    ),
    SettingsItem(
      iconStreamBuilder:
          (context, playerState) =>
              playerState.isShuffleModeEnabled
                  ? const Icon(Icons.shuffle)
                  : const Icon(Icons.list),
      title: OverlayLocalizations.get('random'),
      trailingStreamBuilder:
          (context, playerState) => Text(
            playerState.isShuffleModeEnabled
                ? OverlayLocalizations.get('on')
                : OverlayLocalizations.get('off'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
      onPlayerTap: (context, playerState) {
        widget.controller.setShuffleMode(!playerState.isShuffleModeEnabled);
      },
    ),
    SettingsItem(
      icon: Icons.subtitles_outlined,
      title: OverlayLocalizations.get('subtitleSettings'),
      onTap: (context) {
        bloc.add(const SetActivePanel(playerPanel: PlayerPanel.none));
        showSideSheet(
          context: context,
          bloc: bloc,
          barrierColor: Colors.transparent,
          widthFactor: 0.35,
          body: SubtitleSettingsWidget(
            controller: widget.controller,
            bloc: bloc,
          ),
        );
      },
    ),
    SettingsItem(
      icon: Icons.access_time,
      title: OverlayLocalizations.get('clock'),
      onTap: (context) {
        bloc.add(const SetActivePanel(playerPanel: PlayerPanel.none));
        showSideSheet(
          context: context,
          bloc: bloc,
          barrierColor: Colors.transparent,
          widthFactor: 0.38,
          body: ClockSettingsWidget(controller: widget.controller, bloc: bloc),
        );
      },
    ),
  ];
}

class SettingsItem {
  final IconData? icon;
  final String title;
  final Widget Function(BuildContext context)? trailingBuilder;
  final Icon Function(BuildContext context, PlayerState)? iconStreamBuilder;
  final Widget Function(BuildContext context, PlayerState)?
  trailingStreamBuilder;
  final void Function(BuildContext context)? onTap;
  final void Function(BuildContext context, PlayerState)? onPlayerTap;

  SettingsItem({
    this.icon,
    this.iconStreamBuilder,
    required this.title,
    this.trailingBuilder,
    this.trailingStreamBuilder,
    this.onTap,
    this.onPlayerTap,
  });

  Widget build(
    BuildContext context, {
    required bool isFocused,
    required Media3UiController controller,
  }) {
    final textStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      color: isFocused ? Colors.white : Colors.white70,
    );
    final iconColor = isFocused ? Colors.white : Colors.white70;

    void handleTap() {
      if (onTap != null) {
        onTap!(context);
      } else if (onPlayerTap != null) {
        onPlayerTap!(context, controller.playerState);
      }
    }

    if (iconStreamBuilder != null || trailingStreamBuilder != null) {
      return StreamBuilder<PlayerState>(
        initialData: controller.playerState,
        stream: controller.playerStateStream,
        builder: (context, snapshot) {
          final playerState = snapshot.data;
          if (playerState == null) return const SizedBox.shrink();
          return ListTile(
            focusColor: AppTheme.focusColor,
            tileColor: isFocused ? AppTheme.focusColor : Colors.transparent,
            leading:
                iconStreamBuilder != null
                    ? IconTheme(
                      data: IconThemeData(color: iconColor),
                      child: iconStreamBuilder!.call(context, playerState),
                    )
                    : null,
            trailing: trailingStreamBuilder?.call(context, playerState),
            title: Text(title, style: textStyle),
            onTap: handleTap,
          );
        },
      );
    }

    return ListTile(
      focusColor: AppTheme.focusColor,
      tileColor: isFocused ? AppTheme.focusColor : Colors.transparent,
      leading: icon != null ? Icon(icon, color: iconColor) : null,
      trailing: trailingBuilder?.call(context),
      title: Text(title, style: textStyle),
      onTap: handleTap,
    );
  }
}
