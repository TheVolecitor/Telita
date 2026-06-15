import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tv_media3/src/overlay/bloc/overlay_ui_bloc.dart';

import '../../../../../app_theme/app_theme.dart';
import '../../../../../localization/overlay_localizations.dart';
import '../bloc/epg_bloc.dart';

class EpgDateSelector extends StatefulWidget {
  final List<DateTime> dates;
  final int selectedIndex;
  final VoidCallback? onPreviousDay;
  final VoidCallback? onNextDay;
  final OverlayUiBloc bloc;
  const EpgDateSelector({
    super.key,
    required this.dates,
    required this.selectedIndex,
    this.onPreviousDay,
    this.onNextDay,
    required this.bloc,
  });

  @override
  State<EpgDateSelector> createState() => _EpgDateSelectorState();
}

class _EpgDateSelectorState extends State<EpgDateSelector> {
  late ScrollController _scrollController;
  static const double _itemWidth = 80.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCenter(widget.selectedIndex);
    });
  }

  @override
  void didUpdateWidget(covariant EpgDateSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _scrollToCenter(widget.selectedIndex);
    }
  }

  void _scrollToCenter(int index) {
    if (!mounted || !_scrollController.hasClients) return;

    final listViewWidth = _scrollController.position.viewportDimension;
    final targetOffset =
        (index * _itemWidth) - (listViewWidth / 2) + (_itemWidth / 2);

    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<EpgBloc>();

    return SizedBox(
      height: 48.0,
      child:
          widget.dates.isEmpty
              ? Center(child: Text(OverlayLocalizations.get('epgNoDates')))
              : Row(
                children: [
                  if (widget.bloc.state.isTouch)
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                      onPressed: widget.onPreviousDay,
                    ),
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.dates.length,
                      controller: _scrollController,
                      itemBuilder: (context, index) {
                        final date = widget.dates[index];
                        final isSelected = index == widget.selectedIndex;
                        return GestureDetector(
                          onTap: () => bloc.add(EpgDateChanged(index)),
                          child: Container(
                            width: 80.0,
                            alignment: Alignment.center,
                            decoration:
                                isSelected
                                    ? BoxDecoration(
                                      color: AppTheme.focusColor.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: AppTheme.borderRadius,
                                    )
                                    : null,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  OverlayLocalizations.dayFormat(
                                    date: date,
                                  ).toUpperCase(),
                                  style:
                                      isSelected
                                          ? AppTheme
                                              .dateSelectorSelectedDayStyle
                                          : AppTheme
                                              .dateSelectorUnselectedDayStyle,
                                ),
                                Text(
                                  OverlayLocalizations.dateFormat(date: date),
                                  style: TextStyle(
                                    color:
                                        isSelected
                                            ? AppTheme.colorPrimary
                                            : AppTheme.colorSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (widget.bloc.state.isTouch)
                    IconButton(
                      icon: const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                      ),
                      onPressed: widget.onNextDay,
                    ),
                ],
              ),
    );
  }
}
