import 'package:flutter_tv_media3/src/localization/overlay_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../app_theme/app_theme.dart';
import '../bloc/epg_bloc.dart';
import 'channel_logo_widget.dart';
import 'program_timeline.dart';

class ProgramDetailsView extends StatefulWidget {
  final FocusNode focusNode;
  final bool hasFocus;
  final ValueChanged<bool> onScrollUpChanged;
  final ValueChanged<bool> onScrollDownChanged;

  const ProgramDetailsView({
    super.key,
    required this.focusNode,
    required this.hasFocus,
    required this.onScrollUpChanged,
    required this.onScrollDownChanged,
  });

  @override
  State<ProgramDetailsView> createState() => _ProgramDetailsViewState();
}

class _ProgramDetailsViewState extends State<ProgramDetailsView> {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollUp = false;
  bool _canScrollDown = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollability);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollability());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollability);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateScrollability() {
    if (!_scrollController.hasClients) return;

    final canScrollUp =
        _scrollController.position.pixels >
        _scrollController.position.minScrollExtent;
    final canScrollDown =
        _scrollController.position.pixels <
        _scrollController.position.maxScrollExtent;

    if (canScrollUp != _canScrollUp) {
      setState(() {
        _canScrollUp = canScrollUp;
      });
      widget.onScrollUpChanged(canScrollUp);
    }
    if (canScrollDown != _canScrollDown) {
      setState(() {
        _canScrollDown = canScrollDown;
      });
      widget.onScrollDownChanged(canScrollDown);
    }
  }

  void _scroll(double offset) {
    _scrollController.animateTo(
      _scrollController.offset + offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EpgBloc>().state;
    final channel = state.selectedChannel;
    final program = state.selectedProgram;

    if (channel == null || program == null) {
      return Center(
        child: Text(OverlayLocalizations.get("program_not_selected")),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollability());

    final bool isTheActiveProgram =
        state.activeProgramIndex == state.selectedProgramIndex;

    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.hasFocus,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _scroll(-100);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _scroll(100);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          spacing: 16,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              spacing: 8,
              children: [
                ChannelLogoWidget(logoUrl: channel.logoUrl, dimension: 24),
                Expanded(
                  child: Text(
                    channel.name,
                    style: AppTheme.detailsChannelNameStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            ClipRRect(
              borderRadius: AppTheme.borderRadius,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (program.posterUrl != null)
                      Image.network(
                        program.posterUrl!,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (context, error, stackTrace) =>
                                Container(color: AppTheme.backgroundColor),
                      ),
                    Container(
                      decoration: AppTheme.programDetailsGradientDecoration,
                    ),
                    Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: Text(
                        program.title,
                        style: AppTheme.detailsProgramTitleStyle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  OverlayLocalizations.dateFormat(date: program.startTime),
                  style: AppTheme.detailsProgramTimeStyle.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                isTheActiveProgram
                    ? ProgramTimelineWidget(
                      startTime: program.startTime,
                      endTime: program.endTime,
                    )
                    : Text(
                      OverlayLocalizations.formatShortTimeRange(
                        program.startTime,
                        program.endTime,
                      ),
                      style: AppTheme.detailsProgramTimeStyle,
                    ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Text(
                  program.description ?? '',
                  style: AppTheme.detailsProgramDescriptionStyle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
