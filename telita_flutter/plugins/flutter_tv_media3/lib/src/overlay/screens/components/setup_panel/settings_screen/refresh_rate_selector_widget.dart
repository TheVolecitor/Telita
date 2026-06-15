import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tv_media3/src/app_theme/app_theme.dart';
import 'package:flutter_tv_media3/src/localization/overlay_localizations.dart';
import 'package:flutter_tv_media3/src/overlay/media_ui_service/media3_ui_controller.dart';

import '../../../../../entity/refresh_rate_info.dart';

class RefreshRateSelectorWidget extends StatefulWidget {
  final Media3UiController controller;

  const RefreshRateSelectorWidget({super.key, required this.controller});

  @override
  State<RefreshRateSelectorWidget> createState() =>
      _RefreshRateSelectorWidgetState();
}

class _RefreshRateSelectorWidgetState extends State<RefreshRateSelectorWidget> {
  final FocusNode _listFocusNode = FocusNode();
  final FocusNode _doneButtonFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  RefreshRateInfo? _refreshRateInfo;
  bool _isLoading = true;
  int _selectedIndex = 0;
  static const double _itemExtent = AppTheme.customListItemExtent;

  @override
  void initState() {
    super.initState();
    _fetchRefreshRates();
  }

  @override
  void dispose() {
    _listFocusNode.dispose();
    _doneButtonFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchRefreshRates() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final info = await widget.controller.getRefreshRateInfo();
      if (mounted) {
        setState(() {
          _refreshRateInfo = info;
          _isLoading = false;
          // Find the index of the active rate to focus it
          final activeRateIndex = info.supportedRates.indexWhere(
            (rate) => (info.activeRate - rate).abs() < 0.1,
          );
          if (activeRateIndex != -1) {
            _selectedIndex = activeRateIndex;
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _listFocusNode.requestFocus();
              _scrollToIndex(_selectedIndex);
            }
          });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _setRate(double rate) async {
    await widget.controller.setManualFrameRate(rate);
    await _fetchRefreshRates(); // Refresh to show the new active rate
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients ||
        !_scrollController.position.hasContentDimensions) {
      return;
    }
    final targetOffset =
        (index * _itemExtent) -
        (_scrollController.position.viewportDimension / 2) +
        (_itemExtent / 2);
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rates = _refreshRateInfo?.supportedRates ?? [];

    final listShortcuts = {
      const SingleActivator(LogicalKeyboardKey.arrowUp): () {
        if (_selectedIndex > 0) {
          setState(() {
            _selectedIndex--;
            _scrollToIndex(_selectedIndex);
          });
        }
      },
      const SingleActivator(LogicalKeyboardKey.arrowDown): () {
        if (_selectedIndex < rates.length - 1) {
          setState(() {
            _selectedIndex++;
            _scrollToIndex(_selectedIndex);
          });
        }
      },
      const SingleActivator(LogicalKeyboardKey.enter): () {
        if (_selectedIndex < rates.length) {
          _setRate(rates[_selectedIndex]);
        }
      },
      const SingleActivator(LogicalKeyboardKey.select): () {
        if (_selectedIndex < rates.length) {
          _setRate(rates[_selectedIndex]);
        }
      },
    };

    return Material(
      color: Colors.transparent,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowRight): () {
            if (mounted) _doneButtonFocusNode.requestFocus();
          },
          const SingleActivator(LogicalKeyboardKey.contextMenu):
              () => Navigator.of(context).pop(),
          const SingleActivator(LogicalKeyboardKey.keyQ):
              () => Navigator.of(context).pop(),
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ListTile(
              leading: const Icon(Icons.settings_display_outlined),
              title: Text(OverlayLocalizations.get('selectRefreshRate')),
              titleTextStyle: Theme.of(context).textTheme.headlineMedium,
            ),
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.white70))
                      : rates.isEmpty
                      ? Center(
                        child: Text(
                          OverlayLocalizations.get('refreshRateNotAvailable'),
                        ),
                      )
                      : CallbackShortcuts(
                        bindings: listShortcuts,
                        child: Focus(
                          focusNode: _listFocusNode,
                          autofocus: true,
                          child: Scrollbar(
                            controller: _scrollController,
                            thumbVisibility: true,
                            trackVisibility: true,
                            radius: const Radius.circular(50),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ListView.builder(
                                controller: _scrollController,
                                itemCount: rates.length,
                                itemExtent: _itemExtent,
                                itemBuilder: (context, index) {
                                  final rate = rates[index];
                                  final isActive =
                                      (_refreshRateInfo!.activeRate - rate)
                                          .abs() <
                                      0.1;
                                  final isFocused = index == _selectedIndex;
                                  return Container(
                                    color:
                                        isFocused
                                            ? AppTheme.focusColor
                                            : Colors.transparent,
                                    child: ListTile(
                                      leading:
                                          isActive
                                              ? const Icon(Icons.check)
                                              : const SizedBox(width: 24),
                                      title: Text(
                                        '${rate.toStringAsFixed(3)} Hz',
                                      ),
                                      onTap: () => _setRate(rate),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

