import 'package:flutter_tv_media3/src/localization/overlay_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../app_theme/app_theme.dart';
import '../../../../../const/iso_language_list.dart';
import '../../../../bloc/overlay_ui_bloc.dart';
import '../../../../media_ui_service/media3_ui_controller.dart';
import '../../widgets/edit_text_form_widget.dart';
import '../../widgets/show_side_sheet.dart';
import 'player_settings_widget.dart';

class MultiLanguageSelector extends StatefulWidget {
  final String title;
  final List<String> initiallySelected;
  final void Function(List<String> selectedCodes) onChanged;
  final Media3UiController controller;
  final OverlayUiBloc bloc;
  const MultiLanguageSelector({
    super.key,
    required this.initiallySelected,
    required this.onChanged,
    required this.title,
    required this.bloc,
    required this.controller,
  });

  @override
  State<MultiLanguageSelector> createState() => _MultiLanguageSelectorState();
}

class _MultiLanguageSelectorState extends State<MultiLanguageSelector> {
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _listFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  String _searchString = '';
  late Set<String> _selectedCodes;
  int _selectedIndex = 0;
  static const double _itemExtent = AppTheme.customListItemExtent;

  @override
  void initState() {
    super.initState();
    _selectedCodes = widget.initiallySelected.toSet();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _listFocusNode.requestFocus();
      final code =
          widget.initiallySelected.isNotEmpty
              ? widget.initiallySelected.first
              : null;
      if (code != null) {
        final initialIndex = languageList.keys.toList().indexOf(code);
        if (initialIndex != -1) {
          setState(() {
            _selectedIndex = initialIndex;
          });
          _scrollToIndex(initialIndex);
        }
      }
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _listFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleSelection(String code) {
    setState(() {
      if (_selectedCodes.contains(code)) {
        _selectedCodes.remove(code);
      } else {
        _selectedCodes.add(code);
      }
      widget.onChanged(_selectedCodes.toList());
    });
  }

  void _clearAll() {
    setState(() {
      _selectedCodes.clear();
      widget.onChanged([]);
    });
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients ||
        !_scrollController.position.hasContentDimensions) {
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

  @override
  Widget build(BuildContext context) {
    final filteredLanguageList =
        _searchString.isEmpty
            ? languageList
            : Map.fromEntries(
              languageList.entries.where((entry) {
                final name = entry.value['name']?.toLowerCase() ?? '';
                final native = entry.value['nativeName']?.toLowerCase() ?? '';
                final code = entry.key.toLowerCase();
                return name.contains(_searchString.toLowerCase()) ||
                    native.contains(_searchString.toLowerCase()) ||
                    code.contains(_searchString.toLowerCase());
              }),
            );

    final filteredKeys = filteredLanguageList.keys.toList();

    void handleListKeyEvent(Function action) {
      if (!mounted) return;
      setState(() {
        action();
      });
    }

    final listShortcuts = {
      const SingleActivator(LogicalKeyboardKey.arrowUp):
          () => handleListKeyEvent(() {
            if (_selectedIndex > 0) {
              _selectedIndex--;
              _scrollToIndex(_selectedIndex);
            }
          }),
      const SingleActivator(LogicalKeyboardKey.arrowDown):
          () => handleListKeyEvent(() {
            if (_selectedIndex < filteredKeys.length - 1) {
              _selectedIndex++;
              _scrollToIndex(_selectedIndex);
            }
          }),
      const SingleActivator(LogicalKeyboardKey.enter):
          () => handleListKeyEvent(() {
            if (_selectedIndex < filteredKeys.length) {
              _toggleSelection(filteredKeys[_selectedIndex]);
            }
          }),
      const SingleActivator(LogicalKeyboardKey.select):
          () => handleListKeyEvent(() {
            if (_selectedIndex < filteredKeys.length) {
              _toggleSelection(filteredKeys[_selectedIndex]);
            }
          }),
    };

    return Material(
      color: Colors.transparent,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
            if (!mounted) return;
            showSideSheet(
              context: context,
              bloc: widget.bloc,
              widthFactor: 0.35,
              body: PlayerSettingsWidget(
                controller: widget.controller,
                bloc: widget.bloc,
              ),
            );
          },
          const SingleActivator(LogicalKeyboardKey.arrowRight): () {
            if (mounted) _searchFocusNode.requestFocus();
          },
          const SingleActivator(LogicalKeyboardKey.contextMenu):
              () => Navigator.of(context).pop(),
          const SingleActivator(LogicalKeyboardKey.keyQ):
              () => Navigator.of(context).pop(),
        },
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(widget.title),
              titleTextStyle: Theme.of(context).textTheme.titleLarge,
              subtitle: Text(
                _selectedCodes.join(', '),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.fullFocusColor,
                ),
              ),
            ),
            ListTile(
              title: Text(OverlayLocalizations.get('clearAll')),
              titleTextStyle: Theme.of(context).textTheme.titleLarge,
              focusColor: AppTheme.focusColor,
              onTap: _selectedCodes.isEmpty ? null : _clearAll,
            ),
            EditTextFormWidget(
              focusNode: _searchFocusNode,
              title: OverlayLocalizations.get('searchLanguage'),
              defaultValue: '',
              hintText: OverlayLocalizations.get('search'),
              saveValue: (String result) {
                if (!mounted) return;
                setState(() {
                  _searchString = result;
                  _selectedIndex = 0;
                  _scrollToIndex(0);
                });
              },
              onChanged: (String result) {
                if (!mounted) return;
                setState(() {
                  _searchString = result;
                  _selectedIndex = 0;
                  _scrollToIndex(0);
                });
              },
            ),
            Expanded(
              child: CallbackShortcuts(
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
                        itemCount: filteredKeys.length,
                        itemExtent: _itemExtent,
                        itemBuilder: (context, index) {
                          final code = filteredKeys[index];
                          final data = filteredLanguageList[code];
                          final displayName =
                              data?['nativeName'] ?? data?['name'] ?? code;
                          final name = data?['name'] ?? code;
                          final isSelected = _selectedCodes.contains(code);
                          final isFocused = index == _selectedIndex;

                          return Container(
                            color:
                                isFocused
                                    ? AppTheme.focusColor
                                    : Colors.transparent,
                            child: ListTile(
                              title: Text(displayName.toString()),
                              subtitle: Text(name),
                              trailing:
                                  isSelected
                                      ? Icon(
                                        Icons.check_circle,
                                        color: AppTheme.fullFocusColor,
                                      )
                                      : Text(
                                        code,
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                      ),
                              selected: isSelected,
                              selectedTileColor: AppTheme.fullFocusColor
                                  .withValues(alpha: 0.3),
                              onTap: () => _toggleSelection(code),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.arrow_left, color: AppTheme.fullFocusColor),
                Text(OverlayLocalizations.get('goBack')),
                const Spacer(),
                Text(OverlayLocalizations.get('goSearch')),
                Icon(Icons.arrow_right, color: AppTheme.fullFocusColor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
