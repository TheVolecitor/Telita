import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../app_theme/app_theme.dart';

class ColorSelectorWidget extends StatefulWidget {
  final String title;
  final int selectedItem;
  final Function(int) saveResult;
  final bool autofocus;
  final List<Color> colorList;
  final VoidCallback? onTap;
  const ColorSelectorWidget({
    super.key,
    required this.selectedItem,
    required this.saveResult,
    this.autofocus = false,
    required this.colorList,
    required this.title,
    this.onTap,
  });

  @override
  State<ColorSelectorWidget> createState() => _ColorSelectorWidgetState();
}

class _ColorSelectorWidgetState extends State<ColorSelectorWidget> {
  int _selectedIndex = 0;
  bool isFocus = false;
  late ScrollController _scrollController;
  final FocusNode _focusNode = FocusNode();
  static const double _itemExtent = AppTheme.customListItemExtent;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _selectedIndex = widget.selectedItem;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollToIndex(_selectedIndex);
      }
    });
  }

  @override
  void didUpdateWidget(ColorSelectorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedItem != widget.selectedItem) {
      setState(() {
        _selectedIndex = widget.selectedItem;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToIndex(_selectedIndex);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients ||
        widget.colorList.isEmpty ||
        index < 0 ||
        index >= widget.colorList.length) {
      return;
    }

    final viewportWidth = _scrollController.position.viewportDimension;
    final maxScroll = _scrollController.position.maxScrollExtent;

    double targetOffset =
        (index * _itemExtent) - (viewportWidth / 2) + (_itemExtent / 2);
    targetOffset = targetOffset.clamp(0.0, maxScroll);

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft):
            () =>
                _setSelectItem(action: -1, itemCount: widget.colorList.length),
        const SingleActivator(LogicalKeyboardKey.arrowRight):
            () => _setSelectItem(action: 1, itemCount: widget.colorList.length),
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        onFocusChange: (focus) {
          setState(() {
            isFocus = focus;
          });
        },
        child: ListTile(
          title: Text(widget.title),
          onTap: widget.onTap,
          titleTextStyle: Theme.of(context).textTheme.titleLarge,
          focusColor: AppTheme.focusColor,
          subtitle: Material(
            color: Colors.transparent,
            child: SizedBox(
              height: 50,
              width: MediaQuery.of(context).size.width * 0.3,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color:
                        isFocus == true
                            ? AppTheme.fullFocusColor
                            : Theme.of(context).dividerColor,
                    width: 2.0,
                  ),
                  borderRadius: AppTheme.borderRadius,
                ),
                padding: const EdgeInsets.all(3),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: widget.colorList.length,
                  scrollDirection: Axis.horizontal,
                  itemExtent: _itemExtent,
                  itemBuilder: (BuildContext context, int index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3.0),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedIndex = index;
                          });
                          widget.saveResult(index);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: widget.colorList[index],
                            border: Border.all(
                              color:
                                  index == _selectedIndex
                                      ? Colors.white
                                      : Colors.white,
                              width: index == _selectedIndex ? 4 : 1.0,
                            ),
                            borderRadius: const BorderRadius.all(
                              Radius.circular(5.0),
                            ),
                          ),
                          height: 20,
                          width: 20,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _setSelectItem({required int action, required int itemCount}) {
    int newIndex = _selectedIndex + action;
    if (newIndex < 0) {
      newIndex = itemCount - 1;
    } else if (newIndex >= itemCount) {
      newIndex = 0;
    }
    setState(() {
      _selectedIndex = newIndex;
    });
    widget.saveResult(newIndex);
    _scrollToIndex(newIndex);
  }
}
