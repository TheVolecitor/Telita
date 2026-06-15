import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tv_media3/src/app_theme/app_theme.dart';
import 'package:flutter_tv_media3/src/entity/find_subtitles_state.dart';
import 'package:flutter_tv_media3/src/localization/overlay_localizations.dart';
import 'package:flutter_tv_media3/src/overlay/screens/components/widgets/player_notification_widget.dart';

import '../../../../../entity/media_track.dart';
import '../../../../bloc/overlay_ui_bloc.dart';
import '../../../../media_ui_service/media3_ui_controller.dart';
import 'subtitle_item_widget.dart';

class SubtitleWidget extends StatefulWidget {
  final Media3UiController controller;
  const SubtitleWidget({super.key, required this.controller});

  @override
  State<SubtitleWidget> createState() => _SubtitleWidgetState();
}

class _SubtitleWidgetState extends State<SubtitleWidget> {
  late ScrollController _scrollController;
  List<SubtitleTrack> _subtitleTracks = [];
  StreamSubscription? _streamSubscription;
  int _selectedIndex = -1;
  final FocusNode _focusNode = FocusNode();
  double get _itemExtent => 85.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    widget.controller.findSubtitlesStateNotifier.addListener(
      _onFindSubtitlesStateChanged,
    );
    _streamSubscription = widget.controller.playerStateStream.listen(
      (_) => _updateState(),
    );

    _updateState(isInitial: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollToIndex(_selectedIndex);
      }
    });
  }

  FindSubtitlesState? _previousFindSubtitlesState;

  void _onFindSubtitlesStateChanged() {
    final newState = widget.controller.findSubtitlesStateNotifier.value;
    if (mounted) {
      // Show error messages immediately from the search state.
      if (newState.status == SubtitleSearchStatus.error &&
          _previousFindSubtitlesState?.status != SubtitleSearchStatus.error) {
        if (newState.errorMessage != null) {
          _showOverlayNotification(
            message: newState.errorMessage!,
            type: NotificationType.error,
          );
        }
      }
    }
    _previousFindSubtitlesState = newState;
    // We call _updateState which will handle the UI changes, including the success notification.
    _updateState();
  }

  void _showOverlayNotification({
    required String message,
    required NotificationType type,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder:
          (context) => Positioned(
            bottom: 50.0,
            left: 0,
            right: 0,
            child: Center(
              child: PlayerNotificationWidget(message: message, type: type),
            ),
          ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 4)).then((_) {
      overlayEntry.remove();
    });
  }

  void _updateState({bool isInitial = false}) {
    if (!mounted) return;

    String? focusedTrackId;
    if (!isInitial &&
        _selectedIndex >= 0 &&
        _selectedIndex < _subtitleTracks.length) {
      focusedTrackId = _subtitleTracks[_selectedIndex].id;
    }

    final oldTracksCount =
        _subtitleTracks.where((t) => t.id != '-1' && t.id != '-2').length;

    setState(() {
      _subtitleTracks = _getProcessedTracks(
        widget.controller.playerState.subtitleTracks,
        widget.controller.findSubtitlesStateNotifier.value,
      );

      final newTracksCount =
          _subtitleTracks.where((t) => t.id != '-1' && t.id != '-2').length;
      final bool newTracksAdded = !isInitial && newTracksCount > oldTracksCount;

      if (newTracksAdded) {
        _showOverlayNotification(
          message: OverlayLocalizations.get('subtitles_found_and_added'),
          type: NotificationType.success,
        );
      }

      if (focusedTrackId != null && !newTracksAdded) {
        final newIndex = _subtitleTracks.indexWhere(
          (t) => t.id == focusedTrackId,
        );
        if (newIndex != -1) {
          _selectedIndex = newIndex;
        } else {
          _selectedIndex = _getInitialSelectedIndex();
        }
      } else {
        _selectedIndex = _getInitialSelectedIndex();
      }

      if (newTracksAdded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _scrollToIndex(_selectedIndex);
          }
        });
      }
    });
  }

  List<SubtitleTrack> _getProcessedTracks(
    List<SubtitleTrack> subtitleTracks,
    FindSubtitlesState findState,
  ) {
    final processedTracks = <SubtitleTrack>[];

    if (findState.isVisible) {
      // Use the label from the state, or fall back to the default localized string.
      final String buttonLabel =
          findState.label ?? OverlayLocalizations.get('find_subtitle');

      processedTracks.add(
        SubtitleTrack(
          id: '-2',
          index: -2,
          groupIndex: -2,
          isSelected: false,
          isExternal: false,
          label: buttonLabel,
          trackType: 3,
        ),
      );
    }

    final isAnySelected = subtitleTracks.any((element) => element.isSelected);
    processedTracks.add(
      SubtitleTrack(
        id: '-1',
        index: -1,
        groupIndex: -1,
        isSelected: !isAnySelected && subtitleTracks.isNotEmpty,
        isExternal: false,
        label: OverlayLocalizations.get('off'),
        trackType: 3,
      ),
    );

    processedTracks.addAll(subtitleTracks);
    return processedTracks;
  }

  int _getInitialSelectedIndex() {
    final index = _subtitleTracks.indexWhere((element) => element.isSelected);
    return (index == -1 && _subtitleTracks.isNotEmpty) ? 0 : index;
  }

  @override
  void dispose() {
    widget.controller.findSubtitlesStateNotifier.removeListener(
      _onFindSubtitlesStateChanged,
    );
    _streamSubscription?.cancel();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients ||
        _subtitleTracks.isEmpty ||
        index < 0 ||
        index >= _subtitleTracks.length) {
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
    setState(() {
      action();
    });
  }

  void _findSubtitles() {
    widget.controller.findSubtitles();
  }

  void _handleSelect(SubtitleTrack track) {
    final bloc = context.read<OverlayUiBloc>();
    if (track.id == '-2') {
      // Prevent starting a new search if one is already in progress.
      if (widget.controller.findSubtitlesStateNotifier.value.status ==
          SubtitleSearchStatus.loading) {
        return;
      }
      _findSubtitles();
    } else {
      widget.controller.selectSubtitleTrack(track: track);
      bloc.add(const SetActivePanel(playerPanel: PlayerPanel.none));
    }
  }

  Map<ShortcutActivator, VoidCallback> _getShortcuts() {
    return {
      const SingleActivator(LogicalKeyboardKey.arrowUp):
          () => _handleKeyEvent(() {
            if (_subtitleTracks.isEmpty) return;
            _selectedIndex =
                (_selectedIndex - 1 + _subtitleTracks.length) %
                _subtitleTracks.length;
            _scrollToIndex(_selectedIndex);
          }),
      const SingleActivator(LogicalKeyboardKey.arrowDown):
          () => _handleKeyEvent(() {
            if (_subtitleTracks.isEmpty) return;
            _selectedIndex = (_selectedIndex + 1) % _subtitleTracks.length;
            _scrollToIndex(_selectedIndex);
          }),
      const SingleActivator(LogicalKeyboardKey.enter):
          () => _handleKeyEvent(() {
            if (_selectedIndex < _subtitleTracks.length) {
              _handleSelect(_subtitleTracks[_selectedIndex]);
            }
          }),
      const SingleActivator(LogicalKeyboardKey.select):
          () => _handleKeyEvent(() {
            if (_selectedIndex < _subtitleTracks.length) {
              _handleSelect(_subtitleTracks[_selectedIndex]);
            }
          }),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_subtitleTracks.isEmpty) {
      return const Focus(autofocus: true, child: SizedBox.shrink());
    }

    return CallbackShortcuts(
      bindings: _getShortcuts(),
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            trackVisibility: true,
            radius: const Radius.circular(50),
            child: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ValueListenableBuilder<FindSubtitlesState>(
                valueListenable: widget.controller.findSubtitlesStateNotifier,
                builder: (context, findState, child) {
                  return ListView.builder(
                    controller: _scrollController,
                    itemCount: _subtitleTracks.length,
                    itemExtent: _itemExtent,
                    itemBuilder: (BuildContext context, int index) {
                      final track = _subtitleTracks[index];
                      return SubtitleItemWidget(
                        track: track,
                        index: index,
                        isFocused: index == _selectedIndex,
                        searchStatus:
                            track.id == '-2'
                                ? findState.status
                                : SubtitleSearchStatus.idle,
                        stateInfoLabel:
                            track.id == '-2' ? findState.stateInfoLabel : null,
                        onTap: () {
                          setState(() {
                            _selectedIndex = index;
                          });
                          _handleSelect(track);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
