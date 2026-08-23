import 'package:fvp/fvp.dart' as fvp;
import 'package:fvp/mdk.dart' as mdk;

void registerVideoPlayerBackend() {
  // Enable verbose logging and route to Dart console
  mdk.setGlobalOption('log', mdk.LogLevel.all);
  mdk.setLogHandler((level, msg) {
    print('[MDK_BACKEND] $msg');
  });

  // Register fvp ONCE at startup with correct lowercase decoder names.
  // Must be called before any VideoPlayerController is created.
  fvp.registerWith(options: {
    'video.decoders': ['d3d11va', 'dxva2', 'avcodec'],
    'global': {
      'log': 6,
    }
  });
}
