import 'dart:typed_data';

import 'streaming_metadata.dart';

/// Represents the metadata of the currently playing media item.
///
/// This class is an internal data model for the UI, containing information
/// received directly from the native Media3 player. It aggregates data
/// such as title, artist, album information, and streaming metadata.
///
/// Since this data reflects the current state of the player, it can be
/// used to implement external control (e.g., via IP), allowing other
/// devices or parts of the application to get information about what is
/// currently playing.
class MediaMetadata {
  /// The title of the track, movie, or TV show.
  final String? title;

  /// The name of the artist.
  final String? artist;

  /// The title of the album.
  final String? albumTitle;

  /// The name of the album artist.
  final String? albumArtist;

  /// The music or TV genre.
  final String? genre;

  /// The year of release.
  final int? year;

  /// The track number within the album.
  final int? trackNumber;

  /// The URI for the album art or poster.
  final String? artworkUri;

  /// The binary artwork data as a [Uint8List].
  final Uint8List? artworkData;

  /// Additional metadata specific to streaming (e.g., from ICY headers).
  /// See [StreamingMetadata].
  final StreamingMetadata? streamingMetadata;

  const MediaMetadata({
    this.title,
    this.artist,
    this.albumTitle,
    this.albumArtist,
    this.genre,
    this.year,
    this.trackNumber,
    this.artworkUri,
    this.artworkData,
    this.streamingMetadata,
  });

  factory MediaMetadata.fromMap(Map<Object?, Object?>? data) {
    if (data == null) return MediaMetadata();
    final rawMap = Map<String, dynamic>.from(data);
    final streamingMap = rawMap['streamingMetadata'];
    final parsedStreamingMetadata =
        streamingMap is Map ? StreamingMetadata.fromMap(streamingMap) : null;

    return MediaMetadata(
      title: rawMap['title'],
      artist: rawMap['artist'],
      albumTitle: rawMap['albumTitle'],
      albumArtist: rawMap['albumArtist'],
      genre: rawMap['genre'],
      year: rawMap['year'],
      trackNumber: rawMap['trackNumber'],
      artworkUri: rawMap['artworkUri'],
      artworkData: rawMap['artworkData'] as Uint8List?,
      streamingMetadata: parsedStreamingMetadata,
    );
  }

  MediaMetadata copyWith({
    String? title,
    String? artist,
    String? albumTitle,
    String? albumArtist,
    String? genre,
    int? year,
    int? trackNumber,
    String? artworkUri,
    Uint8List? artworkData,
    StreamingMetadata? streamingMetadata,
    Map<String, dynamic>? rawData,
  }) {
    return MediaMetadata(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      albumTitle: albumTitle ?? this.albumTitle,
      albumArtist: albumArtist ?? this.albumArtist,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      trackNumber: trackNumber ?? this.trackNumber,
      artworkUri: artworkUri ?? this.artworkUri,
      artworkData: artworkData ?? this.artworkData,
      streamingMetadata: streamingMetadata ?? this.streamingMetadata,
    );
  }

  @override
  String toString() {
    return '''MediaMetadata{
      title: $title, 
      artist: $artist, 
      albumTitle: $albumTitle, 
      albumArtist: $albumArtist, 
      genre: $genre, 
      year: $year, 
      trackNumber: $trackNumber, 
      artworkUri: $artworkUri, 
      artworkData: $artworkData,
      streamingMetadata: $streamingMetadata, 
    }''';
  }
}
