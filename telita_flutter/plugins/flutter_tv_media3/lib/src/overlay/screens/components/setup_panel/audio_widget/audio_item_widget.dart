import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../app_theme/app_theme.dart';
import '../../../../../entity/media_track.dart';
import '../../../../../utils/string_utils.dart';
import '../../../../bloc/overlay_ui_bloc.dart';
import '../../../../media_ui_service/media3_ui_controller.dart';
import '../../widgets/marquee_title_widget.dart';
import '../../widgets/video_info_item.dart';

class AudioItemWidget extends StatelessWidget {
  const AudioItemWidget({
    super.key,
    required this.controller,
    required this.track,
    required this.index,
    required this.isFocused,
  });

  final Media3UiController controller;
  final AudioTrack track;
  final int index;
  final bool isFocused;

  @override
  Widget build(BuildContext context) {
    final trackLabel = StringUtils.getAudioTrackLabel(track: track, index: index);
    final fullText = '${trackLabel.toLowerCase()} ${track.codec?.toLowerCase() ?? ''} ${track.mimeType?.toLowerCase() ?? ''}';

    final hasAtmos = fullText.contains("atmos");
    final hasDDP = fullText.contains("ddp") || fullText.contains("dd+") || fullText.contains("eac3");
    final hasDTS = fullText.contains("dts");
    final has51 = !hasAtmos && !hasDDP && !hasDTS && (fullText.contains("5.1") || track.channelCount == 6);

    final bool isSelected = track.isSelected == true;
    final Color backgroundColor =
        isFocused
            ? Colors.white.withOpacity(0.15)
            : isSelected
            ? AppTheme.focusColor.withOpacity(0.15)
            : Colors.white.withOpacity(0.02);

    return AnimatedScale(
      scale: isFocused ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFocused ? Colors.white : (isSelected ? AppTheme.focusColor : Colors.transparent),
            width: 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final bloc = context.read<OverlayUiBloc>();
          await controller.selectAudioTrack(track: track);
          bloc.add(SetActivePanel(playerPanel: PlayerPanel.none));
        },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            spacing: 16,
            children: [
              Icon(
                _getIcon(track),
                size: 40,
                color: isFocused || isSelected ? Colors.white : Colors.white70,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    MarqueeWidget(
                      text: trackLabel,
                      focus: isFocused,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            isFocused || isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                        color:
                            isFocused ? Colors.white : (isSelected ? AppTheme.focusColor : Colors.white70),
                      ),
                    ),
                    if (hasAtmos || hasDDP || hasDTS || has51) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (hasAtmos) const _AudioBadge(text: 'ATMOS', isDolby: true),
                          if (hasDDP) const _AudioBadge(text: 'DDP 5.1', isDolby: true),
                          if (hasDTS) const _AudioBadge(text: 'DTS', isDts: true),
                          if (has51) const _AudioBadge(text: '5.1'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (track.codec != null)
                    VideoInfoItem(
                      icon: Icons.audiotrack,
                      title: StringUtils.simplifyCodec(track.codec),
                    ),
                  if (track.mimeType != null)
                    VideoInfoItem(
                      icon: Icons.multitrack_audio,
                      title: StringUtils.simplifyMimeType(track.mimeType),
                    ),
                  if (track.bitrate != null)
                    VideoInfoItem(
                      icon: Icons.equalizer,
                      title: StringUtils.formatBitrate(track.bitrate),
                    ),
                  if ((track.channelCount ?? 0) > 0)
                    VideoInfoItem(
                      icon: Icons.surround_sound,
                      title: StringUtils.formatChannels(track.channelCount),
                    ),
                  if ((track.sampleRate ?? 0) > 0)
                    VideoInfoItem(
                      icon: Icons.waves,
                      title: '${track.sampleRate! ~/ 1000} kHz',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    ),
    );
  }

  IconData _getIcon(AudioTrack track) {
    if (track.index == -1) {
      return Icons.close;
    }
    return track.isSelected == true
        ? Icons.audiotrack
        : Icons.audiotrack_outlined;
  }
}

class _AudioBadge extends StatelessWidget {
  final String text;
  final bool isDolby;
  final bool isDts;
  const _AudioBadge({required this.text, this.isDolby = false, this.isDts = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: isDts || isDolby ? const Color(0xFFF8FAFC) : const Color(0xFF475569)), 
        borderRadius: BorderRadius.circular(3)
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isDolby) const Text('◗◖', style: TextStyle(color: Color(0xFFF8FAFC), fontSize: 16, letterSpacing: -1)),
          if (isDolby) const SizedBox(width: 3),
          Text(text, style: TextStyle(color: isDts || isDolby ? const Color(0xFFF8FAFC) : const Color(0xFF94A3B8), fontWeight: FontWeight.w800, fontSize: 10)),
        ],
      ),
    );
  }
}
