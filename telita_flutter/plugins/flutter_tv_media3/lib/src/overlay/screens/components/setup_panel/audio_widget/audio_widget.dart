import 'package:flutter_tv_media3/src/localization/overlay_localizations.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../app_theme/app_theme.dart';
import '../../../../../entity/media_track.dart';
import '../../../../media_ui_service/media3_ui_controller.dart';
import 'audio_item_widget.dart';

class AudioWidget extends StatefulWidget {
  final Media3UiController controller;
  const AudioWidget({super.key, required this.controller});

  @override
  State<AudioWidget> createState() => _AudioWidgetState();
}

class _AudioWidgetState extends State<AudioWidget> {
  late ScrollController _scrollController;
  List<AudioTrack> _audioTracks = [];
  StreamSubscription? _streamSubscription;
  int _selectedIndex = 0;
  final FocusNode _focusNode = FocusNode();
  double get _itemExtent => 85.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _audioTracks = _getProcessedTracks(
      widget.controller.playerState.audioTracks,
    );
    _selectedIndex = _getInitialSelectedIndex();

    _streamSubscription = widget.controller.playerStateStream.listen((
      playerState,
    ) {
      setState(() {
        _audioTracks = _getProcessedTracks(playerState.audioTracks);
        if (_selectedIndex >= _audioTracks.length) {
          _selectedIndex =
              _audioTracks.isNotEmpty ? _audioTracks.length - 1 : 0;
        }
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollToIndex(_selectedIndex);
      }
    });
  }

  List<AudioTrack> _getProcessedTracks(List<AudioTrack> audioTracks) {
    final processedTracks = List<AudioTrack>.from(audioTracks);
    if (processedTracks.isNotEmpty) {
      final isAnySelected = processedTracks.any(
        (element) => element.isSelected,
      );
      AudioTrack autoTrack = AudioTrack(
        id: '-1',
        index: -1,
        groupIndex: -1,
        isSelected: !isAnySelected,
        isExternal: false,
        label: OverlayLocalizations.get('off'),
        trackType: 1,
      );
      processedTracks.insert(0, autoTrack);
    }
    return processedTracks;
  }

  int _getInitialSelectedIndex() {
    final index = _audioTracks.indexWhere((element) => element.isSelected);
    return (index == -1 && _audioTracks.isNotEmpty) ? 0 : index;
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
        _audioTracks.isEmpty ||
        index < 0 ||
        index >= _audioTracks.length) {
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
            if (_audioTracks.isNotEmpty) {
              _selectedIndex =
                  (_selectedIndex - 1 + _audioTracks.length) %
                  _audioTracks.length;
              _scrollToIndex(_selectedIndex);
            }
          }),
      const SingleActivator(LogicalKeyboardKey.arrowDown):
          () => _handleKeyEvent(() {
            if (_audioTracks.isNotEmpty) {
              _selectedIndex = (_selectedIndex + 1) % _audioTracks.length;
              _scrollToIndex(_selectedIndex);
            }
          }),
      const SingleActivator(LogicalKeyboardKey.enter):
          () => _handleKeyEvent(() {
            if (_selectedIndex < _audioTracks.length) {
              widget.controller.selectAudioTrack(
                track: _audioTracks[_selectedIndex],
              );
            }
          }),
      const SingleActivator(LogicalKeyboardKey.select):
          () => _handleKeyEvent(() {
            if (_selectedIndex < _audioTracks.length) {
              widget.controller.selectAudioTrack(
                track: _audioTracks[_selectedIndex],
              );
            }
          }),
    };
  }

  @override
  Widget build(BuildContext context) {
    return _audioTracks.isEmpty
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
                    itemCount: _audioTracks.length,
                    itemExtent: _itemExtent,
                    itemBuilder: (BuildContext context, int index) {
                      final track = _audioTracks[index];
                      return AudioItemWidget(
                        controller: widget.controller,
                        track: track,
                        index: index,
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
