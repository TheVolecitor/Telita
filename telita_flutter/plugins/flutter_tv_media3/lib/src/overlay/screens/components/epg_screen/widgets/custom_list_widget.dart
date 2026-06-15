import 'package:flutter_tv_media3/src/localization/overlay_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../app_theme/app_theme.dart';

class CustomListWidget<T> extends StatefulWidget {
  final List<T> items;
  final bool hasFocus;
  final int initialIndex;
  final ValueChanged<T>? onItemSelected;
  final ValueChanged<T>? onContextMenuRequested;
  final ValueChanged<int> onSelectedIndexChanged;
  final Widget Function(T item, int index, bool isSelected, bool isFocused)
  itemBuilder;
  final FocusNode? focusNode;
  final ValueChanged<bool>? onScrollUpChanged;
  final ValueChanged<bool>? onScrollDownChanged;

  const CustomListWidget({
    super.key,
    required this.items,
    required this.hasFocus,
    required this.initialIndex,
    required this.onSelectedIndexChanged,
    required this.itemBuilder,
    this.onItemSelected,
    this.onContextMenuRequested,
    this.focusNode,
    this.onScrollUpChanged,
    this.onScrollDownChanged,
  });

  @override
  State<CustomListWidget<T>> createState() => CustomListWidgetState<T>();
}

class CustomListWidgetState<T> extends State<CustomListWidget<T>> {
  late ScrollController _scrollController;
  late FocusNode _focusNode;
  late int _selectedIndex;
  static const double _itemExtent = AppTheme.customListItemExtent;

  bool _canScrollUp = false;
  bool _canScrollDown = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_updateScrollability);

    _focusNode = widget.focusNode ?? FocusNode();
    _selectedIndex = widget.initialIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        scrollToIndex(_selectedIndex);
        _updateScrollability();

        if (widget.hasFocus) {
          _focusNode.requestFocus();
        }
      }
    });
  }

  @override
  void didUpdateWidget(CustomListWidget<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.hasFocus && !_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }

    if (widget.initialIndex != _selectedIndex &&
        widget.initialIndex != oldWidget.initialIndex) {
      setState(() {
        _selectedIndex = widget.initialIndex;
      });
    }

    if ((widget.hasFocus && !oldWidget.hasFocus) ||
        (widget.initialIndex != oldWidget.initialIndex)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          scrollToIndex(_selectedIndex);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollability);
    _scrollController.dispose();

    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _updateScrollability() {
    if (!mounted) return;

    final newCanScrollUp = _selectedIndex > 0;
    final newCanScrollDown = _selectedIndex < widget.items.length - 1;

    if (newCanScrollUp != _canScrollUp) {
      setState(() {
        _canScrollUp = newCanScrollUp;
      });
      widget.onScrollUpChanged?.call(newCanScrollUp);
    }
    if (newCanScrollDown != _canScrollDown) {
      setState(() {
        _canScrollDown = newCanScrollDown;
      });
      widget.onScrollDownChanged?.call(newCanScrollDown);
    }
  }

  void scrollToIndex(int index) {
    if (!_scrollController.hasClients ||
        widget.items.isEmpty ||
        index < 0 ||
        index >= widget.items.length) {
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
    if (widget.hasFocus) {
      setState(() {
        action();
      });
    }
  }

  Map<ShortcutActivator, VoidCallback> _getShortcuts() {
    return {
      const SingleActivator(LogicalKeyboardKey.arrowUp):
          () => _handleKeyEvent(() {
            if (_selectedIndex > 0) {
              _selectedIndex--;
              widget.onSelectedIndexChanged(_selectedIndex);
              scrollToIndex(_selectedIndex);
              _updateScrollability();
            }
          }),
      const SingleActivator(LogicalKeyboardKey.arrowDown):
          () => _handleKeyEvent(() {
            if (_selectedIndex < widget.items.length - 1) {
              _selectedIndex++;
              widget.onSelectedIndexChanged(_selectedIndex);
              scrollToIndex(_selectedIndex);
              _updateScrollability();
            }
          }),
      const SingleActivator(LogicalKeyboardKey.enter):
          () => _handleKeyEvent(() {
            if (widget.onItemSelected != null &&
                _selectedIndex < widget.items.length) {
              widget.onItemSelected!(widget.items[_selectedIndex]);
            }
          }),
      const SingleActivator(LogicalKeyboardKey.select):
          () => _handleKeyEvent(() {
            if (widget.onItemSelected != null &&
                _selectedIndex < widget.items.length) {
              widget.onItemSelected!(widget.items[_selectedIndex]);
            }
          }),
      const SingleActivator(LogicalKeyboardKey.space):
          () => _handleKeyEvent(() {
            if (widget.onItemSelected != null &&
                _selectedIndex < widget.items.length) {
              widget.onItemSelected!(widget.items[_selectedIndex]);
            }
          }),
      const SingleActivator(LogicalKeyboardKey.contextMenu):
          () => _handleKeyEvent(() {
            if (widget.onContextMenuRequested != null &&
                _selectedIndex < widget.items.length) {
              widget.onContextMenuRequested!(widget.items[_selectedIndex]);
            }
          }),
      const SingleActivator(LogicalKeyboardKey.keyQ):
          () => _handleKeyEvent(() {
            if (widget.onContextMenuRequested != null &&
                _selectedIndex < widget.items.length) {
              widget.onContextMenuRequested!(widget.items[_selectedIndex]);
            }
          }),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Center(
        child: Text(
          OverlayLocalizations.get('noData'),
          style: AppTheme.noDataTextStyle,
        ),
      );
    }
    return CallbackShortcuts(
      bindings: _getShortcuts(),
      child: Focus(
        focusNode: _focusNode,
        autofocus: widget.hasFocus,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: widget.items.length,
          itemBuilder: (context, index) {
            final isSelected = index == _selectedIndex;
            final item = widget.items[index];
            return InkWell(
              onTap: () {
                if (_selectedIndex != index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                  widget.onSelectedIndexChanged(index);
                  _updateScrollability();
                }
                // Trigger the action associated with the item
                if (widget.onItemSelected != null) {
                  widget.onItemSelected!(item);
                }
              },
              child: Container(
                height: _itemExtent,
                color:
                    widget.hasFocus && isSelected
                        ? AppTheme.focusColor
                        : Colors.transparent,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: DefaultTextStyle.merge(
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color:
                          widget.hasFocus && isSelected
                              ? AppTheme.fullFocusColor
                              : AppTheme.divider,
                    ),
                    child: widget.itemBuilder(
                      item,
                      index,
                      isSelected,
                      widget.hasFocus,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
