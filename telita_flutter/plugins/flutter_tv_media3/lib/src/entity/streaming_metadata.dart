import 'dart:convert';
import 'dart:typed_data';

/// Represents an APIC (Attached Picture) frame from ID3 tags.
/// Contains an image embedded in the media file.
class ApicFrame {
  /// The binary data of the image.
  final Uint8List? pictureData;

  /// A description of the image.
  final String? description;

  /// The MIME type of the image (e.g., "image/jpeg").
  final String? mimeType;

  ApicFrame({this.pictureData, this.description, this.mimeType});

  @override
  String toString() {
    return '''ApicFrame{
      pictureData: $pictureData, 
      description: $description, 
      mimeType: $mimeType
    }''';
  }
}

/// Represents a URL frame from ID3 tags.
class UrlFrame {
  /// The URL.
  final String? url;

  /// A description of the link.
  final String? description;

  UrlFrame({this.url, this.description});

  @override
  String toString() {
    return '''UrlFrame{
      url: $url, 
      description: $description
    }''';
  }
}

/// Represents a private (PRIV) frame from ID3 tags.
/// Used for transferring custom data.
class PrivFrame {
  /// The owner of the data.
  final String? owner;

  /// The private binary data.
  final Uint8List? privateData;

  PrivFrame({this.owner, this.privateData});

  @override
  String toString() {
    return '''PrivFrame{
      owner: $owner, 
      privateData: $privateData
    }''';
  }
}

/// Represents an event message in a media stream (e.g., EMSG in DASH).
class EventMessage {
  /// The URI identifying the message scheme.
  final String? schemeIdUri;

  /// The value of the message.
  final String? value;

  /// The duration of the event in milliseconds.
  final int? durationMs;

  /// The ID of the event.
  final int? id;

  /// The binary message data.
  final Uint8List? messageData;

  EventMessage({
    this.schemeIdUri,
    this.value,
    this.durationMs,
    this.id,
    this.messageData,
  });

  /// Returns [messageData] as a JSON map, if possible.
  Map<String, dynamic>? get messageDataAsJson {
    if (messageData == null) return null;
    try {
      return jsonDecode(utf8.decode(messageData!));
    } catch (e) {
      return null;
    }
  }

  @override
  String toString() {
    return '''EventMessage{
      schemeIdUri: $schemeIdUri, 
      value: $value, 
      durationMs: $durationMs, 
      id: $id, 
      messageData: $messageData
    }''';
  }
}

/// Represents an SCTE-35 command for content insertion (e.g., advertising).
class SpliceInsertCommand {
  /// The ID of the splice event.
  final int? eventId;

  /// The presentation timestamp (PTS) for the splice.
  final int? programSplicePts;

  SpliceInsertCommand({this.eventId, this.programSplicePts});

  @override
  String toString() {
    return '''SpliceInsertCommand{
      eventId: $eventId, 
      programSplicePts: $programSplicePts
    }''';
  }
}

/// Represents metadata obtained from streaming media (e.g., internet radio).
///
/// This class is an internal data model for the UI that contains information
/// received directly from the native player from stream metadata,
/// such as ICY (Shoutcast) or ID3 tags embedded in the stream.
///
/// Since this data reflects the player's current state, it can be
/// used to implement external control (e.g., via IP), allowing other
/// systems to get information about what is currently playing in the
/// stream (e.g., the song title on a radio station).
class StreamingMetadata {
  /// The title obtained from ICY headers (often contains "Artist - Title").
  final String? icyTitle;

  /// The URL obtained from ICY headers.
  final String? icyUrl;

  /// The track title from the ID3 tag (TIT2).
  final String? id3Title;

  /// The artist from the ID3 tag (TPE1).
  final String? id3Artist;

  /// The album from the ID3 tag (TALB).
  final String? id3Album;

  const StreamingMetadata({
    this.icyTitle,
    this.icyUrl,
    this.id3Title,
    this.id3Artist,
    this.id3Album,
  });

  factory StreamingMetadata.fromMap(Map<Object?, Object?>? data) {
    if (data == null) {
      return StreamingMetadata();
    }
    final rawMap = Map<String, dynamic>.from(data);
    return StreamingMetadata(
      icyTitle: rawMap['icyTitle'],
      icyUrl: rawMap['icyUrl'],
      id3Title: rawMap['id3_TIT2'],
      id3Artist: rawMap['id3_TPE1'],
      id3Album: rawMap['id3_TALB'],
    );
  }

  @override
  String toString() {
    return '''StreamingMetadata{
      icyTitle: $icyTitle, 
      icyUrl: $icyUrl, 
      id3Title: $id3Title, 
      id3Artist: $id3Artist, 
      id3Album: $id3Album, 
     }''';
  }
}
