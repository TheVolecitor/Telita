import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../../../../../flutter_tv_media3.dart';
import '../../../../media_ui_service/media3_ui_controller.dart';
import '../../widgets/video_info_item.dart';

class InfoStringWidget extends StatelessWidget {
  const InfoStringWidget({super.key, required this.controller});

  final Media3UiController controller;

  @override
  Widget build(BuildContext context) {
    List<AudioTrack>? audioTracks = controller.playerState.audioTracks;
    AudioTrack? audioInfo =
        audioTracks.isNotEmpty
            ? audioTracks.firstWhereOrNull((e) => e.isSelected == true)
            : null;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        if (controller.playerState.isLive == true)
          VideoInfoItem(
            icon: Icons.radio,
            title: OverlayLocalizations.get('liveStatus'),
          ),
        if (audioInfo?.codec != null)
          VideoInfoItem(
            icon: Icons.audiotrack,
            title: StringUtils.simplifyCodec(audioInfo?.codec),
          ),
        if (audioInfo?.mimeType != null)
          VideoInfoItem(
            icon: Icons.multitrack_audio,
            title: StringUtils.simplifyMimeType(audioInfo?.mimeType),
          ),
        if (audioInfo?.bitrate != null)
          VideoInfoItem(
            icon: Icons.equalizer,
            title: StringUtils.formatBitrate(audioInfo?.bitrate),
          ),
        if ((audioInfo?.channelCount ?? 0) > 0)
          VideoInfoItem(
            icon: Icons.surround_sound,
            title: StringUtils.formatChannels(audioInfo?.channelCount),
          ),
        if ((audioInfo?.sampleRate ?? 0) > 0)
          VideoInfoItem(
            icon: Icons.waves,
            title: '${audioInfo!.sampleRate! ~/ 1000} kHz',
          ),
        if (controller.playerState.isLive == false)
          VideoInfoItem(
            icon: Icons.speed,
            title: '${controller.playerState.speed.toStringAsFixed(2)}x',
          ),
        if (controller.playerState.isShuffleModeEnabled)
          VideoInfoItem(icon: Icons.shuffle),
        if (controller.playerState.repeatMode != PlayerRepeatMode.repeatModeOff)
          VideoInfoItem(
            icon:
                controller.playerState.repeatMode ==
                        PlayerRepeatMode.repeatModeOne
                    ? Icons.repeat_one
                    : Icons.repeat,
          ),
      ],
    );
  }
}
