import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../app_theme/app_theme.dart';
import '../../../../../entity/epg_channel.dart';
import '../../widgets/marquee_title_widget.dart';
import '../bloc/epg_bloc.dart';
import 'channel_logo_widget.dart';
import 'custom_list_widget.dart';

class ChannelsListView extends StatelessWidget {
  final FocusNode focusNode;
  final bool hasFocus;
  final ValueChanged<EpgChannel> onChannelLaunch;
  final ValueChanged<bool> onScrollUpChanged;
  final ValueChanged<bool> onScrollDownChanged;

  const ChannelsListView({
    super.key,
    required this.focusNode,
    required this.hasFocus,
    required this.onChannelLaunch,
    required this.onScrollUpChanged,
    required this.onScrollDownChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<EpgBloc>();

    return BlocBuilder<EpgBloc, EpgState>(
      buildWhen:
          (prev, current) =>
              prev.allChannels != current.allChannels ||
              prev.selectedChannelIndex != current.selectedChannelIndex,
      builder: (context, state) {
        return CustomListWidget<EpgChannel>(
          focusNode: focusNode,
          items: state.allChannels,
          initialIndex: state.selectedChannelIndex,
          hasFocus: hasFocus,
          onSelectedIndexChanged: (newIndex) {
            bloc.add(EpgChannelSelected(newIndex));
          },
          onItemSelected: onChannelLaunch,
          onScrollUpChanged: onScrollUpChanged,
          onScrollDownChanged: onScrollDownChanged,
          itemBuilder: (channel, index, isSelected, isFocused) {
            return ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 4),
              tileColor: isSelected && !hasFocus ? AppTheme.focusColor : null,
              leading: ChannelLogoWidget(
                logoUrl: channel.logoUrl,
                dimension: 50,
              ),
              title: MarqueeWidget(
                text: channel.name,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: Colors.white,
                ),
                focus: isSelected && hasFocus,
              ),
            );
          },
        );
      },
    );
  }
}
