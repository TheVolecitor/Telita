import 'package:flutter_tv_media3/src/localization/overlay_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../app_theme/app_theme.dart';
import '../../../../../entity/epg_channel.dart';
import '../bloc/epg_bloc.dart';
import 'channel_logo_widget.dart';
import 'custom_list_widget.dart';
import 'program_list_item.dart';

class ProgramsListView extends StatefulWidget {
  final FocusNode focusNode;
  final bool hasFocus;
  final ValueChanged<bool> onScrollUpChanged;
  final ValueChanged<bool> onScrollDownChanged;

  const ProgramsListView({
    super.key,
    required this.focusNode,
    required this.hasFocus,
    required this.onScrollUpChanged,
    required this.onScrollDownChanged,
  });

  @override
  State<ProgramsListView> createState() => _ProgramsListViewState();
}

class _ProgramsListViewState extends State<ProgramsListView> {
  final GlobalKey<CustomListWidgetState<EpgProgram>> _listKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EpgBloc>().state;
    final bloc = context.read<EpgBloc>();
    final programs = state.selectedChannel?.programs ?? [];
    final selectedChannel = state.selectedChannel;

    if (selectedChannel == null) {
      return Center(child: Text(OverlayLocalizations.get('selectChannel')));
    }

    return BlocListener<EpgBloc, EpgState>(
      listenWhen:
          (previous, current) =>
              previous.programIndexToScroll != current.programIndexToScroll &&
              current.programIndexToScroll != null,
      listener: (context, state) {
        if (state.programIndexToScroll != null) {
          _listKey.currentState?.scrollToIndex(state.programIndexToScroll!);
          bloc.add(EpgScrolled());
        }
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              spacing: 8,
              children: [
                ChannelLogoWidget(
                  logoUrl: selectedChannel.logoUrl,
                  dimension: 40,
                ),
                Expanded(
                  child: Text(
                    selectedChannel.name,
                    style: AppTheme.programsChannelNameStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                programs.isEmpty
                    ? Center(
                      child: Text(
                        OverlayLocalizations.get('live'),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.merge(AppTheme.boldTextStyle),
                      ),
                    )
                    : CustomListWidget<EpgProgram>(
                      key: _listKey,
                      focusNode: widget.focusNode,
                      items: programs,
                      initialIndex: state.selectedProgramIndex,
                      hasFocus: widget.hasFocus,
                      onSelectedIndexChanged: (newIndex) {
                        bloc.add(EpgProgramSelected(newIndex));
                      },
                      onScrollUpChanged: widget.onScrollUpChanged,
                      onScrollDownChanged: widget.onScrollDownChanged,
                      itemBuilder: (program, index, isSelected, isFocused) {
                        return ProgramListItem(
                          program: program,
                          isSelected: isSelected,
                          isTheActiveProgram: index == state.activeProgramIndex,
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
