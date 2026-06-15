import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tv_media3/flutter_tv_media3.dart';
import 'package:sprintf/sprintf.dart';

import '../../../bloc/overlay_ui_bloc.dart';
import '../../../media_ui_service/media3_ui_controller.dart';
import 'video_info_item.dart';

class VideoInfoWidget extends StatelessWidget {
  const VideoInfoWidget({
    super.key,
    required this.controller,
    required this.state,
  });
  final Media3UiController controller;
  final OverlayUiState state;

  @override
  Widget build(BuildContext context) {
    final mediaInfo = controller.playerState;
    List<VideoTrack> videoTracks = controller.playerState.videoTracks;
    List<AudioTrack>? audioTracks = controller.playerState.audioTracks;
    VideoTrack? videoInfo =
        videoTracks.isNotEmpty
            ? videoTracks.firstWhereOrNull((e) => e.isSelected == true)
            : null;
    AudioTrack? audioInfo =
        audioTracks.isNotEmpty
            ? audioTracks.firstWhereOrNull((e) => e.isSelected == true)
            : null;
    int subtitleCount = controller.playerState.subtitleTracks.length;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        if (videoInfo?.containerMimeType != null)
          VideoInfoItem(
            icon: Icons.video_collection,
            title: StringUtils.simplifyMimeType(videoInfo?.containerMimeType),
          ),
        if (videoInfo?.width != null && videoInfo?.height != null)
          VideoInfoItem(
            icon: StringUtils.getVideoQuality(width: videoInfo?.width),
            title: '${videoInfo?.width}x${videoInfo?.height}',
          ),
        if (videoInfo?.frameRate != null && videoInfo?.frameRate != 1.0)
          VideoInfoItem(
            icon: Icons.video_label,
            title: '${videoInfo?.frameRate!.toStringAsFixed(1)} fps',
          ),
        if (videoInfo?.bitrate != null)
          VideoInfoItem(
            icon: Icons.speed,
            title: StringUtils.formatBitrate(videoInfo?.bitrate),
          ),
        if (videoInfo?.sampleMimeType != null)
          VideoInfoItem(
            icon: Icons.video_file,
            title: StringUtils.simplifyMimeType(videoInfo?.sampleMimeType),
          ),
        if (videoInfo?.codecs != null)
          VideoInfoItem(
            icon: Icons.personal_video,
            title: StringUtils.simplifyCodec(videoInfo?.codecs),
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
            title: sprintf(OverlayLocalizations.get('sampleRateInKHz'), [
              audioInfo!.sampleRate! ~/ 1000,
            ]),
          ),

        if (subtitleCount > 0)
          VideoInfoItem(
            icon: Icons.subtitles,
            title: sprintf(OverlayLocalizations.get('subtitles'), [
              subtitleCount,
            ]),
          ),

        VideoInfoItem(
          icon: Icons.speed,
          title: '${controller.playerState.speed.toStringAsFixed(2)}x',
        ),
        if (mediaInfo.isLive)
          VideoInfoItem(
            icon: Icons.live_tv,
            title: OverlayLocalizations.get('live'),
          ),
        if (!mediaInfo.isLive && videoInfo != null)
          VideoInfoItem(
            icon: Icons.ondemand_video,
            title: OverlayLocalizations.get('vod'),
          ),
        if (controller.playerState.isShuffleModeEnabled)
          const VideoInfoItem(icon: Icons.shuffle),
        if (controller.playerState.repeatMode != PlayerRepeatMode.repeatModeOff)
          VideoInfoItem(
            icon:
                controller.playerState.repeatMode ==
                        PlayerRepeatMode.repeatModeOne
                    ? Icons.repeat_one
                    : Icons.repeat,
          ),
        if (videoInfo?.width != null && videoInfo?.height != null)
          VideoInfoItem(icon: Icons.zoom_in, title: mediaInfo.zoom.nativeValue),
        if ((controller.playItem.programs ?? []).isNotEmpty)
          VideoInfoItem(
            icon: Icons.insert_invitation,
            title: OverlayLocalizations.get('epg'),
          ),
      ],
    );
  }
}
