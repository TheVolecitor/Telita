import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tv_media3/flutter_tv_media3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FtvMedia3PlayerController', () {
    test('controller is a singleton', () {
      final controller1 = FlutterTvMedia3.controller;
      final controller2 = FlutterTvMedia3.controller;
      expect(controller1, same(controller2));
    });

    test('initial player state is correct', () {
      final controller = FlutterTvMedia3.controller;
      expect(controller.playerState.activityReady, false);
      expect(controller.playerState.stateValue, StateValue.initial);
      expect(controller.playerState.playlist, isEmpty);
    });

    test('VolumeState fromMap handles null values gracefully', () {
      final volumeState = VolumeState.fromMap({});
      expect(volumeState.current, 0);
      expect(volumeState.max, 0);
      expect(volumeState.isMute, false);
      expect(volumeState.volume, 0.0);
    });

    test('VolumeState toMap creates correct map', () {
      final volumeState = VolumeState(
        current: 10,
        max: 20,
        isMute: true,
        volume: 0.5,
      );
      final map = volumeState.toMap();
      expect(map['current'], 10);
      expect(map['max'], 20);
      expect(map['isMute'], true);
      expect(map['volume'], 0.5);
    });
  });
}
