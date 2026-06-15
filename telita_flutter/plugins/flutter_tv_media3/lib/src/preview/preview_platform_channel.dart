import 'dart:async';
import 'package:flutter/services.dart';
import 'preview_player_error.dart';
import 'preview_player_event.dart';

/// A singleton class that manages communication between Flutter and the native
/// Android platform for preview player functionality.
///
/// It uses a [MethodChannel] to send commands to the native side and receives
/// events (including errors) back via a stream.
class PreviewPlatformChannel {
  PreviewPlatformChannel._();

  /// The singleton instance of [PreviewPlatformChannel].
  static final PreviewPlatformChannel instance = PreviewPlatformChannel._();

  static const MethodChannel _channel = MethodChannel(
    'flutter_tv_media3/preview',
  );

  final StreamController<PreviewPlayerEvent> _eventController =
      StreamController<PreviewPlayerEvent>.broadcast();

  bool _initialized = false;

  /// A stream of all events originating from the native preview players.
  Stream<PreviewPlayerEvent> get events => _eventController.stream;

  /// A convenience stream that filters [events] to only include [PreviewPlayerError]s.
  ///
  /// This is provided for backward compatibility or if only error listening is needed.
  Stream<PreviewPlayerError> get errors => events
      .where((e) => e.isError)
      .map(
        (e) => PreviewPlayerError(
          textureId: e.textureId,
          errorCode: e.data?['errorCode'] as int? ?? 0,
          errorMessage: e.data?['errorMessage'] as String?,
        ),
      );

  /// Initializes the platform channel. This should be called once.
  /// Sets up the [MethodChannel] to handle incoming method calls from the native side.
  void init() {
    if (_initialized) return;
    _channel.setMethodCallHandler(_handleMethodCall);
    _initialized = true;
  }

  /// Disposes of the resources used by the platform channel.
  /// This should be called when the application no longer needs the preview player functionality.
  Future<void> dispose() async {
    if (!_initialized) return;
    _initialized = false;
    await _eventController.close();
  }

  /// Handles incoming method calls from the native platform.
  ///
  /// Specifically, it processes the 'onPlayerEvent' method, extracting the event
  /// data and adding it to the [_eventController] stream.
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onPlayerEvent':
        final args = call.arguments as Map;
        final textureId = args['textureId'] as int;
        final eventType = args['event'] as String;

        _eventController.add(
          PreviewPlayerEvent(textureId: textureId, type: eventType, data: args),
        );
        return null;
      default:
        throw MissingPluginException();
    }
  }

  /// Invokes a method on the native platform with optional arguments.
  ///
  /// Returns a [Future] that completes with the result of the native method call.
  Future<T?> invoke<T>(String method, [Map<String, dynamic>? arguments]) {
    return _channel.invokeMethod<T>(method, arguments);
  }
}
