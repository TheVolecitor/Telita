import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tv_media3/src/app_theme/app_theme.dart';
import 'package:flutter_tv_media3/src/localization/overlay_localizations.dart';
import '../../../../../entity/media_track.dart';
import '../../../../media_ui_service/media3_ui_controller.dart';
import 'video_item_widget.dart';

class VideoWidget extends StatefulWidget {
  final Media3UiController controller;
  const VideoWidget({super.key, required this.controller});

  @override
  State<VideoWidget> createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<VideoWidget> {
  late ScrollController _scrollController;
  List<VideoTrack> _videoTracks = [];
  StreamSubscription? _streamSubscription;
  int _selectedIndex = 0;
  final FocusNode _focusNode = FocusNode();
  static const double _itemExtent = AppTheme.customListItemExtent;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _videoTracks = _getProcessedTracks(
      widget.controller.playerState.videoTracks,
    );
    _selectedIndex = _getInitialSelectedIndex();

    _streamSubscription = widget.controller.playerStateStream.listen((
      playerState,
    ) {
      setState(() {
        _videoTracks = _getProcessedTracks(playerState.videoTracks);

        if (_selectedIndex >= _videoTracks.length) {
          _selectedIndex =
              _videoTracks.isNotEmpty ? _videoTracks.length - 1 : 0;
        }
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollToIndex(_selectedIndex);
      }
    });
  }

  List<VideoTrack> _getProcessedTracks(List<VideoTrack> videoTracks) {
    final processedTracks = List<VideoTrack>.from(videoTracks);
    final hasExternalTracks = processedTracks.any(
      (track) => track.isExternal == true,
    );
    if (!hasExternalTracks && processedTracks.isNotEmpty) {
      final isAnySelected = processedTracks.any((t) => t.isSelected);
      VideoTrack autoTrack = VideoTrack(
        id: '-1',
        index: -1,
        groupIndex: -1,
        isSelected: !isAnySelected,
        isExternal: false,
        label: OverlayLocalizations.get('auto'),
        trackType: 2,
      );
      processedTracks.insert(0, autoTrack);
    }
    return processedTracks;
  }

  int _getInitialSelectedIndex() {
    final index = _videoTracks.indexWhere((element) => element.isSelected);
    return (index == -1 && _videoTracks.isNotEmpty) ? 0 : index;
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients ||
        _videoTracks.isEmpty ||
        index < 0 ||
        index >= _videoTracks.length) {
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

  Map<ShortcutActivator, VoidCallback> _getShortcuts() {
    return {
      const SingleActivator(LogicalKeyboardKey.arrowUp):
          () => _handleKeyEvent(() {
            if (_videoTracks.isNotEmpty) {
              _selectedIndex =
                  (_selectedIndex - 1 + _videoTracks.length) %
                  _videoTracks.length;
              _scrollToIndex(_selectedIndex);
            }
          }),
      const SingleActivator(LogicalKeyboardKey.arrowDown):
          () => _handleKeyEvent(() {
            if (_videoTracks.isNotEmpty) {
              _selectedIndex = (_selectedIndex + 1) % _videoTracks.length;
              _scrollToIndex(_selectedIndex);
            }
          }),
      const SingleActivator(LogicalKeyboardKey.enter):
          () => _handleKeyEvent(() {
            if (_selectedIndex < _videoTracks.length) {
              widget.controller.selectVideoTrack(
                track: _videoTracks[_selectedIndex],
              );
            }
          }),
      const SingleActivator(LogicalKeyboardKey.select):
          () => _handleKeyEvent(() {
            if (_selectedIndex < _videoTracks.length) {
              widget.controller.selectVideoTrack(
                track: _videoTracks[_selectedIndex],
              );
            }
          }),
    };
  }

  @override
  Widget build(BuildContext context) {
    return _videoTracks.isEmpty
        ? const Focus(autofocus: true, child: SizedBox.shrink())
        : CallbackShortcuts(
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
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _videoTracks.length,
                    itemExtent: _itemExtent,
                    itemBuilder: (BuildContext context, int index) {
                      final track = _videoTracks[index];
                      return VideoItemWidget(
                        controller: widget.controller,
                        track: track,
                        isFocused: index == _selectedIndex,
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
