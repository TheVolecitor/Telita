/// An abstract base class representing a single media track (video, audio, or subtitle).
///
/// This class and its descendants (`VideoTrack`, `AudioTrack`, `SubtitleTrack`) are
/// internal data models for the UI. They contain information about the actually
/// available tracks, which has been received directly from the native player
/// after parsing the media content.
///
/// These objects are not created manually but are sent from the player to reflect
/// the current state. They can be used to implement external control (IP control),
/// allowing remote systems to get the list of available tracks and their
/// current state (e.g., which track is selected).
abstract class MediaTrack {
  /// The internal index of the track within its group, assigned by the player.
  final int index;

  /// The index of the track group to which this track belongs.
  final int groupIndex;

  /// The unique ID of the track, assigned by the player.
  final String id;

  /// The type of the track (2 - video, 1 - audio, 3 - subtitle).
  final int trackType;

  /// A flag indicating whether this track is currently selected for playback.
  final bool isSelected;

  /// A flag indicating whether the track is external (loaded from a separate URL)
  /// rather than embedded in the main media file.
  final bool isExternal;

  /// The track label for display in the UI (e.g., "Ukrainian 5.1" or "1080p").
  final String? label;

  MediaTrack({
    required this.index,
    required this.groupIndex,
    required this.id,
    required this.trackType,
    required this.isSelected,
    required this.isExternal,
    this.label,
  });

  factory MediaTrack.fromMap(Map<String, dynamic> map) {
    final int trackType = map['trackType'];
    switch (trackType) {
      case 2:
        return VideoTrack.fromMap(map);
      case 1:
        return AudioTrack.fromMap(map);
      case 3:
        return SubtitleTrack.fromMap(map);
      default:
        throw UnsupportedError('Unsupported trackType: $trackType');
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'index': index,
      'groupIndex': groupIndex,
      'id': id,
      'trackType': trackType,
      'isSelected': isSelected,
      'isExternal': isExternal,
      'label': label,
    };
  }
}

/// Represents a single video track.
class VideoTrack extends MediaTrack {
  /// The width of the video in pixels.
  final int? width;

  /// The height of the video in pixels.
  final int? height;

  /// The video bitrate.
  final int? bitrate;

  /// The frame rate.
  final double? frameRate;

  /// The sample MIME type.
  final String? sampleMimeType;

  /// Information about the codecs.
  final String? codecs;

  /// Track selection flags.
  final int? selectionFlags;

  /// Track role flags (e.g., main, alternate).
  final int? roleFlags;

  /// The pixel width to height ratio.
  final double? pixelWidthHeightRatio;

  /// The MIME type of the container.
  final String? containerMimeType;

  /// The average bitrate.
  final int? averageBitrate;

  /// The peak bitrate.
  final int? peakBitrate;

  /// The stereo mode.
  final int? stereoMode;

  /// Information about the color.
  final Map<String, dynamic>? colorInfo;

  /// The URL of the external track.
  final String? url;

  VideoTrack({
    required super.index,
    required super.groupIndex,
    required super.id,
    required super.trackType,
    required super.isSelected,
    required super.isExternal,
    super.label,
    this.width,
    this.height,
    this.bitrate,
    this.frameRate,
    this.sampleMimeType,
    this.codecs,
    this.selectionFlags,
    this.roleFlags,
    this.pixelWidthHeightRatio,
    this.containerMimeType,
    this.averageBitrate,
    this.peakBitrate,
    this.stereoMode,
    this.colorInfo,
    this.url,
  });

  factory VideoTrack.fromMap(Map<String, dynamic> map) {
    return VideoTrack(
      index: map['index'],
      groupIndex: map['groupIndex'],
      id: map['id'].toString(),
      trackType: map['trackType'],
      isSelected: map['isSelected'],
      isExternal: map['isExternal'],
      label: map['label'],
      width: map['width'],
      height: map['height'],
      bitrate: map['bitrate'],
      frameRate: (map['frameRate'] as num?)?.toDouble(),
      sampleMimeType: map['sampleMimeType'],
      codecs: map['codecs'],
      selectionFlags: map['selectionFlags'],
      roleFlags: map['roleFlags'],
      pixelWidthHeightRatio: (map['pixelWidthHeightRatio'] as num?)?.toDouble(),
      containerMimeType: map['containerMimeType'],
      averageBitrate: map['averageBitrate'],
      peakBitrate: map['peakBitrate'],
      stereoMode: map['stereoMode'],
      colorInfo:
          map['colorInfo'] != null
              ? Map<String, dynamic>.from(map['colorInfo'])
              : null,
      url: map['url'],
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return super.toMap()..addAll({
      'width': width,
      'height': height,
      'bitrate': bitrate,
      'frameRate': frameRate,
      'sampleMimeType': sampleMimeType,
      'codecs': codecs,
      'selectionFlags': selectionFlags,
      'roleFlags': roleFlags,
      'pixelWidthHeightRatio': pixelWidthHeightRatio,
      'containerMimeType': containerMimeType,
      'averageBitrate': averageBitrate,
      'peakBitrate': peakBitrate,
      'stereoMode': stereoMode,
      'colorInfo': colorInfo,
      'url': url,
    });
  }

  @override
  String toString() {
    return '''VideoTrack{
        index: $index, 
        groupIndex: $groupIndex,
        id: $id, 
        trackType: $trackType, 
        isSelected: $isSelected, 
        isExternal: $isExternal, 
        label: $label,
        width: $width, 
        height: $height, 
        bitrate: $bitrate, 
        frameRate: $frameRate, 
        sampleMimeType: $sampleMimeType, 
        codecs: $codecs, 
        selectionFlags: $selectionFlags, 
        roleFlags: $roleFlags, 
        pixelWidthHeightRatio: $pixelWidthHeightRatio, 
        containerMimeType: $containerMimeType, 
        averageBitrate: $averageBitrate, 
        peakBitrate: $peakBitrate, 
        stereoMode: $stereoMode, 
        colorInfo: $colorInfo, 
        url: $url
      }''';
  }
}

/// Represents a single audio track.
class AudioTrack extends MediaTrack {
  /// The language code of the track (e.g., "de", "en").
  final String? language;

  /// The name of the codec.
  final String? codec;

  /// The MIME type.
  final String? mimeType;

  /// The audio bitrate.
  final int? bitrate;

  /// The average bitrate.
  final int? averageBitrate;

  /// The peak bitrate.
  final int? peakBitrate;

  /// The sample rate.
  final int? sampleRate;

  /// The number of audio channels.
  final int? channelCount;

  /// Track selection flags.
  final int? selectionFlags;

  /// Track role flags.
  final int? roleFlags;

  AudioTrack({
    required super.index,
    required super.groupIndex,
    required super.id,
    required super.trackType,
    required super.isSelected,
    required super.isExternal,
    super.label,
    this.language,
    this.codec,
    this.mimeType,
    this.bitrate,
    this.averageBitrate,
    this.peakBitrate,
    this.sampleRate,
    this.channelCount,
    this.selectionFlags,
    this.roleFlags,
  });

  factory AudioTrack.fromMap(Map<String, dynamic> map) {
    return AudioTrack(
      index: map['index'],
      groupIndex: map['groupIndex'],
      id: map['id'].toString(),
      trackType: map['trackType'],
      isSelected: map['isSelected'],
      isExternal: map['isExternal'],
      label: map['label'],
      language: map['language'],
      codec: map['codec'] ?? map['codecs'],
      mimeType: map['mimeType'] ?? map['sampleMimeType'],
      bitrate: map['bitrate'],
      averageBitrate: map['averageBitrate'],
      peakBitrate: map['peakBitrate'],
      sampleRate: map['sampleRate'],
      channelCount: map['channelCount'],
      selectionFlags: map['selectionFlags'],
      roleFlags: map['roleFlags'],
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return super.toMap()..addAll({
      'language': language,
      'codec': codec,
      'mimeType': mimeType,
      'bitrate': bitrate,
      'averageBitrate': averageBitrate,
      'peakBitrate': peakBitrate,
      'sampleRate': sampleRate,
      'channelCount': channelCount,
      'selectionFlags': selectionFlags,
      'roleFlags': roleFlags,
    });
  }

  @override
  String toString() {
    return '''AudioTrack{
      index: $index, 
      groupIndex: $groupIndex,
      id: $id, 
      trackType: $trackType, 
      isSelected: $isSelected, 
      isExternal: $isExternal, 
      label: $label,
      language: $language, 
      codec: $codec, 
      mimeType: $mimeType, 
      bitrate: $bitrate, 
      averageBitrate: $averageBitrate, 
      peakBitrate: $peakBitrate, 
      sampleRate: $sampleRate, 
      channelCount: $channelCount, 
      selectionFlags: $selectionFlags, 
      roleFlags: $roleFlags
    }''';
  }
}

/// Represents a single subtitle track.
class SubtitleTrack extends MediaTrack {
  /// The language code of the track (e.g., "de", "en").
  final String? language;

  /// Track selection flags.
  final int? selectionFlags;

  /// Track role flags (e.g., "forced", "commentary").
  final int? roleFlags;

  /// Information about the codecs.
  final String? codecs;

  /// The MIME type of the container.
  final String? containerMimeType;

  /// The sample MIME type.
  final String? sampleMimeType;

  SubtitleTrack({
    required super.index,
    required super.groupIndex,
    required super.id,
    required super.trackType,
    required super.isSelected,
    required super.isExternal,
    super.label,
    this.language,
    this.selectionFlags,
    this.roleFlags,
    this.codecs,
    this.containerMimeType,
    this.sampleMimeType,
  });

  factory SubtitleTrack.fromMap(Map<String, dynamic> map) {
    return SubtitleTrack(
      index: map['index'],
      groupIndex: map['groupIndex'],
      id: map['id'].toString(),
      trackType: map['trackType'],
      isSelected: map['isSelected'],
      isExternal: map['isExternal'],
      label: map['label'],
      language: map['language'],
      selectionFlags: map['selectionFlags'],
      roleFlags: map['roleFlags'],
      codecs: map['codecs'],
      containerMimeType: map['containerMimeType'],
      sampleMimeType: map['sampleMimeType'],
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return super.toMap()..addAll({
      'language': language,
      'selectionFlags': selectionFlags,
      'roleFlags': roleFlags,
      'codecs': codecs,
      'containerMimeType': containerMimeType,
      'sampleMimeType': sampleMimeType,
    });
  }

  @override
  String toString() {
    return '''SubtitleTrack{
      index: $index, 
      groupIndex: $groupIndex,
      id: $id, 
      trackType: $trackType, 
      isSelected: $isSelected, 
      isExternal: $isExternal, 
      label: $label,
      language: $language,
      selectionFlags: $selectionFlags,
      roleFlags: $roleFlags,
      codecs: $codecs,
      containerMimeType: $containerMimeType,
      sampleMimeType: $sampleMimeType
    }''';
  }
}
