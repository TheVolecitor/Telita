/// This file defines the [PreviewPlayerError] class, which is used to encapsulate
/// error information originating from the native Media3 preview player.
/// Errors include a texture ID, an error code, and an optional human-readable message.
library;

import 'package:flutter/foundation.dart';

/// Represents an error that occurred during media playback in the native preview player.
///
/// This class holds details about an error, including the associated player's
/// texture ID, a specific error code from the native player, and an optional
/// descriptive error message.
@immutable
class PreviewPlayerError {
  /// The ID of the texture associated with the player that encountered the error.
  final int textureId;

  /// The specific error code from the native player, indicating the type of error.
  final int errorCode;

  /// An optional human-readable error message providing more context about the error.
  final String? errorMessage;

  /// Creates a [PreviewPlayerError] instance.
  ///
  /// - [textureId]: The ID of the Flutter texture where the error occurred.
  /// - [errorCode]: The native error code.
  /// - [errorMessage]: An optional descriptive message for the error.
  const PreviewPlayerError({
    required this.textureId,
    required this.errorCode,
    this.errorMessage,
  });

  @override
  String toString() {
    return 'PreviewPlayerError(textureId: $textureId, errorCode: $errorCode, errorMessage: $errorMessage)';
  }
}
