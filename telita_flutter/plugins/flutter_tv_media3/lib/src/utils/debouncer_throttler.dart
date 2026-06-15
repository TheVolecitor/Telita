import 'dart:async';

class DebouncerThrottler {
  Timer? _debounceTimer;
  Timer? _throttleTimer;
  bool _isThrottling = false;
  bool _isProcessing = false;

  void debounce(Duration duration, Function callback) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(duration, () {
      callback();
    });
  }

  Future<void> throttle(
    Duration duration,
    Future<void> Function() callback,
  ) async {
    if (!_isThrottling && !_isProcessing) {
      _isThrottling = true;
      _isProcessing = true;

      try {
        await callback();
      } finally {
        _isProcessing = false;
        _throttleTimer = Timer(duration, () {
          _isThrottling = false;
        });
      }
    }
  }

  void cancel() {
    _debounceTimer?.cancel();
    _throttleTimer?.cancel();
    _isThrottling = false;
    _isProcessing = false;
  }
}
