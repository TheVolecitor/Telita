import 'package:flutter/material.dart';

import '../const/iso_language_list.dart';
import '../entity/media_track.dart';

class StringUtils {
  StringUtils();

  static String formatDuration({int? seconds}) {
    if (seconds == null) return '--:--';
    final d = Duration(seconds: seconds);
    return d.toString().split('.').first.padLeft(8, "0");
  }

  static double getPercentage({int? duration, int? position}) =>
      (duration != null && position != null && duration > 0)
          ? (position / duration).clamp(0.0, 1.0)
          : 0.0;

  static String getTimeLeft({
    int? position,
    int? duration,
    bool seconds = true,
  }) {
    if (position == null || duration == null) return '--:--';
    final d = Duration(seconds: duration - position);
    String timeLeft = d.toString().split('.').first.padLeft(8, "0");
    if (seconds == false) timeLeft = timeLeft.substring(0, timeLeft.length - 3);
    return timeLeft;
  }

  static String simplifyMimeType(String? mimeType) {
    if (mimeType == null) return '';

    if (mimeType.contains('video/mp4')) return 'MP4';
    if (mimeType.contains('video/webm')) return 'WebM';
    if (mimeType.contains('video/mp2t')) return 'MPEG-TS';
    if (mimeType.contains('video/3gpp')) return '3GP';
    if (mimeType.contains('video/x-matroska')) return 'MKV';
    if (mimeType.contains('video/x-ms-wmv')) return 'WMV';
    if (mimeType.contains('video/x-flv')) return 'FLV';
    if (mimeType.contains('video/avi')) return 'AVI';

    if (mimeType.contains('application/x-mpegURL')) return 'HLS';
    if (mimeType.contains('application/dash+xml')) return 'DASH';
    if (mimeType.contains('application/vnd.ms-sstr+xml')) {
      return 'SmoothStreaming';
    }

    if (mimeType.contains('audio/mpeg')) return 'MP3';
    if (mimeType.contains('audio/aac')) return 'AAC';
    if (mimeType.contains('audio/ogg')) return 'Ogg';
    if (mimeType.contains('audio/wav')) return 'WAV';
    if (mimeType.contains('audio/x-flac')) return 'FLAC';
    if (mimeType.contains('audio/amr')) return 'AMR';
    if (mimeType.contains('audio/ac3')) return 'AC-3';
    if (mimeType.contains('audio/eac3')) return 'E-AC-3';
    if (mimeType.contains('audio/x-ms-wma')) return 'WMA';
    if (mimeType.contains('audio/alac')) return 'ALAC';
    if (mimeType.contains('audio/x-aiff')) return 'AIFF';
    if (mimeType.contains('audio/dts')) return 'DTS';

    return mimeType.split('/').last.toUpperCase();
  }

  static String simplifyCodec(String? codec) {
    if (codec == null) return '';

    if (codec.contains('avc') || codec.contains('h264')) return 'H.264';
    if (codec.contains('hevc') || codec.contains('h265')) return 'H.265';
    if (codec.contains('vp8')) return 'VP8';
    if (codec.contains('vp9')) return 'VP9';
    if (codec.contains('av1')) return 'AV1';
    if (codec.contains('mpeg4')) return 'MPEG-4';
    if (codec.contains('mpeg2')) return 'MPEG-2';
    if (codec.contains('wmv')) return 'WMV';
    if (codec.contains('divx')) return 'DivX';
    if (codec.contains('xvid')) return 'Xvid';

    if (codec.contains('mp3')) return 'MP3';
    if (codec.contains('mp4a') || codec.contains('aac')) return 'AAC';
    if (codec.contains('vorbis')) return 'Vorbis';
    if (codec.contains('opus')) return 'Opus';
    if (codec.contains('flac')) return 'FLAC';
    if (codec.contains('ac3')) return 'AC-3';
    if (codec.contains('eac3')) return 'E-AC-3';
    if (codec.contains('dts')) return 'DTS';
    if (codec.contains('alac')) return 'ALAC';
    if (codec.contains('amr')) return 'AMR';
    if (codec.contains('pcm')) return 'PCM';
    if (codec.contains('wma')) return 'WMA';
    if (codec.contains('aiff')) return 'AIFF';

    return codec.toUpperCase();
  }

  static String formatChannels(int? channelCount) {
    switch (channelCount) {
      case 1:
        return 'Mono';
      case 2:
        return 'Stereo';
      case 6:
        return '5.1';
      case 8:
        return '7.1';
      default:
        if (channelCount != null && channelCount >= 3 && channelCount <= 8) {
          return '$channelCount ch';
        }
        return '';
    }
  }

  static String getVideoTrackLabel(VideoTrack track) {
    final label = track.label != null ? track.label?.trim() : '';

    final width = track.width ?? 0;
    final resolutionName = () {
      if (width >= 7600) return '8K';
      if (width >= 2000) return 'UHD';
      if (width >= 1000) return 'FHD';
      if (width >= 700) return 'HD';
      if (width > 0) return 'SD';
      if (width <= 0) return '';
    }();

    final resolution =
        track.width != null && track.height != null
            ? '${track.width}x${track.height}'
            : '';

    final fps =
        (track.frameRate != null && track.frameRate! > 0)
            ? '@${track.frameRate!.toInt()}fps'
            : '';

    final bitrate =
        (track.bitrate != null && track.bitrate! > 0)
            ? ' (${formatBitrate(track.bitrate!)})'
            : '';

    return '$label $resolutionName $resolution$fps $bitrate'.trim();
  }

  static String formatBitrate(int? bitrate) {
    if (bitrate == null) return '';
    if (bitrate >= 1000000) {
      return '${(bitrate / 1000000).toStringAsFixed(1)} Mbps';
    }
    return '${bitrate ~/ 1000} kbps';
  }

  static String getAudioTrackLabel({
    required AudioTrack track,
    required int index,
  }) {
    final parts = <String>[];

    if (track.language?.isNotEmpty == true) {
      parts.add(
        _getLanguageName(track.language!).replaceAll('UND', 'Unspecified'),
      );
    }

    if (track.label?.isNotEmpty == true) {
      parts.add(track.label!);
    }

    if (parts.isEmpty) {
      parts.add('Track ${index + 1}');
    }

    return parts.join(' • ');
  }

  static String getSubtitleTrackLabel({
    required SubtitleTrack track,
    required int index,
  }) {
    final String suffix;
    final int flags = track.roleFlags ?? 0;

    if ((flags & 0x400) != 0) {
      suffix = ' (SDH)';
    } else if ((flags & 0x200) != 0) {
      suffix = ' (Forced)';
    } else {
      suffix = '';
    }
    String mainLabel = '';
    if ((track.language ?? '').isNotEmpty) {
      mainLabel = '${_getLanguageName(track.language!)}, ';
    }

    if (track.label?.isNotEmpty == true) {
      mainLabel = '$mainLabel${track.label!}';
    } else if (track.codecs?.isNotEmpty == true) {
      mainLabel = '$mainLabel${track.codecs} Subtitle $index';
    }
    if (mainLabel.isEmpty) {
      mainLabel = 'Subtitle $index';
    }
    return '$mainLabel$suffix'.trim();
  }

  static String _getLanguageName(String languageCode) {
    return languageList[languageCode]?['nativeName'] ??
        (languageCode.length > 2
            ? '${languageCode[0].toUpperCase()}${languageCode.substring(2)}'
            : languageCode);
  }

  static IconData getVideoQuality({int? width}) {
    if (width == null) return Icons.help_outline;
    if (width < 1280) {
      return Icons.sd;
    } else if (width < 1920) {
      return Icons.hd;
    } else if (width < 2560) {
      return Icons.high_quality;
    } else if (width < 7680) {
      return Icons.four_k;
    } else {
      return Icons.eight_k;
    }
  }
}

extension StringCasingExtension on String {
  String durationClear() =>
      RegExp(
        r'((^0*[1-9]\d*:)?\d{2}:\d{2})\.\d+$',
      ).firstMatch(toString())?.group(1) ??
      toString();
}

List<T> distinctByIndex<T extends MediaTrack>(List<T> tracks) {
  final seenIndexes = <int>{};
  return tracks.where((track) => seenIndexes.add(track.index)).toList();
}
