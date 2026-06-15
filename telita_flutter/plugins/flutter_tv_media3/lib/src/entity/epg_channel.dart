import 'playlist_media_item.dart';

/// Defines the signature for a callback function that is used in the UI
/// to open (switch to) a specific TV channel from the EPG.
///
/// This callback is set and used internally by the UI components,
/// so developers do not need to set it manually.
typedef OpenChannel = Future<void> Function({required EpgChannel epgChannel});

/// Represents a single television program in the Electronic Program Guide (EPG).
///
/// This class is a data model that holds all the information about a specific
/// broadcast, movie, or show on a TV channel, including its title,
/// description, and broadcast time.
class EpgProgram {
  /// The title of the program (e.g., "News" or "Star Wars: A New Hope").
  final String title;

  /// A detailed description of the program.
  final String? description;

  /// The URL for a poster or image representing the program.
  final String? posterUrl;

  /// The start time of the program in UTC.
  final DateTime startTime;

  /// The end time of the program in UTC.
  final DateTime endTime;

  EpgProgram({
    required this.title,
    required this.description,
    this.posterUrl,
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'posterUrl': posterUrl,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
    };
  }

  factory EpgProgram.fromMap(Map<String, dynamic> map) {
    return EpgProgram(
      title: map['title'] as String,
      description: map['description'] as String?,
      posterUrl: map['posterUrl'] as String?,
      startTime: DateTime.parse(map['startTime']),
      endTime: DateTime.parse(map['endTime']),
    );
  }
}

/// Represents a single TV channel in the Electronic Program Guide (EPG).
///
/// This class is a data model used in the UI to display information
/// about a channel and its list of TV programs.
///
/// `EpgChannel` objects are created automatically from a [PlaylistMediaItem]
/// using the `EpgChannel.fromPlaylistMediaItem` factory constructor
/// and do not need to be manually created by the developer.
class EpgChannel {
  /// The unique identifier of the channel.
  final String id;

  /// The sequential index of the channel in the playlist.
  final int index;

  /// The name of the TV channel.
  final String name;

  /// The URL for the channel's logo.
  final String? logoUrl;

  /// The list of programs broadcast on this channel.
  final List<EpgProgram> programs;

  EpgChannel({
    required this.id,
    required this.index,
    required this.name,
    this.logoUrl,
    required this.programs,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'index': index,
      'name': name,
      'logoUrl': logoUrl,
      'programs': programs,
    };
  }

  factory EpgChannel.fromMap(Map<String, dynamic> map) {
    return EpgChannel(
      id: map['id'] as String,
      index: map['index'] as int,
      name: map['name'] as String,
      logoUrl: map['logoUrl'] as String,
      programs: map['programs'] as List<EpgProgram>,
    );
  }

  factory EpgChannel.fromPlaylistMediaItem({
    required PlaylistMediaItem item,
    required int index,
  }) {
    return EpgChannel(
      id: item.id,
      index: index,
      name: item.title ?? item.label ?? '',
      logoUrl: item.coverImg,
      programs: item.programs ?? [],
    );
  }
}
