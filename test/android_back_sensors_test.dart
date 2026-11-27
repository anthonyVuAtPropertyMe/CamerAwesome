import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:camerawesome/pigeon.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

PigeonSensorTypeDevice _device(
  PigeonSensorType type,
  String uid, {
  double? intrinsicZoomRatio,
  bool flashAvailable = true,
}) {
  return PigeonSensorTypeDevice(
    sensorType: type,
    name: 'camera $uid',
    iso: 0,
    flashAvailable: flashAvailable,
    uid: uid,
    intrinsicZoomRatio: intrinsicZoomRatio,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const backChannel = 'dev.flutter.pigeon.CameraInterface.getBackSensors';
  const frontChannel = 'dev.flutter.pigeon.CameraInterface.getFrontSensors';
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void answer(
    String channel,
    List<PigeonSensorTypeDevice> devices,
  ) {
    messenger.setMockMessageHandler(channel, (ByteData? message) async {
      return CameraInterface.codec.encodeMessage(<Object?>[devices]);
    });
  }

  tearDown(() {
    messenger.setMockMessageHandler(backChannel, null);
    messenger.setMockMessageHandler(frontChannel, null);
  });

  group('CamerawesomePlugin.getSensors', () {
    test('lists the ultra-wide, wide and telephoto back cameras by Camera2 id',
        () async {
      answer(backChannel, [
        _device(PigeonSensorType.ultraWideAngle, '2', intrinsicZoomRatio: 0.6),
        _device(PigeonSensorType.wideAngle, '0', intrinsicZoomRatio: 1.0),
        _device(PigeonSensorType.telephoto, '3', intrinsicZoomRatio: 3.0),
      ]);
      answer(frontChannel, [
        _device(PigeonSensorType.wideAngle, '1', intrinsicZoomRatio: 1.0),
      ]);

      final data = await CamerawesomePlugin.getSensors();

      expect(data.ultraWideAngle?.uid, '2');
      expect(data.ultraWideAngle?.intrinsicZoomRatio, 0.6);
      expect(data.wideAngle?.uid, '0');
      expect(data.wideAngle?.intrinsicZoomRatio, 1.0);
      expect(data.telephoto?.uid, '3');
      expect(data.telephoto?.intrinsicZoomRatio, 3.0);
      expect(data.availableSensors, hasLength(3));
    });

    test('lists a back camera that has no ultra-wide or telephoto alone',
        () async {
      answer(backChannel, [
        _device(PigeonSensorType.wideAngle, '0', intrinsicZoomRatio: 1.0),
      ]);
      answer(frontChannel, []);

      final data = await CamerawesomePlugin.getSensors();

      expect(data.wideAngle?.uid, '0');
      expect(data.ultraWideAngle, isNull);
      expect(data.telephoto, isNull);
    });

    test('keeps the name, ISO and flash availability of each camera', () async {
      answer(backChannel, [
        _device(
          PigeonSensorType.ultraWideAngle,
          '2',
          intrinsicZoomRatio: 0.6,
          flashAvailable: false,
        ),
      ]);
      answer(frontChannel, []);

      final data = await CamerawesomePlugin.getSensors();

      expect(data.ultraWideAngle?.name, 'camera 2');
      expect(data.ultraWideAngle?.iso, 0);
      expect(data.ultraWideAngle?.flashAvailable, isFalse);
    });

    test('leaves the intrinsic zoom ratio null when the platform sends none',
        () async {
      // iOS does not set it.
      answer(backChannel, [_device(PigeonSensorType.wideAngle, 'back-uid')]);
      answer(frontChannel, [_device(PigeonSensorType.trueDepth, 'front-uid')]);

      final data = await CamerawesomePlugin.getSensors();

      expect(data.wideAngle?.uid, 'back-uid');
      expect(data.wideAngle?.intrinsicZoomRatio, isNull);
      expect(data.trueDepth?.uid, 'front-uid');
    });

    test('returns no sensors when the platform lists none', () async {
      answer(backChannel, []);
      answer(frontChannel, []);

      final data = await CamerawesomePlugin.getSensors();

      expect(data.availableSensors, isEmpty);
    });
  });

  group('PigeonSensorTypeDevice', () {
    test('keeps a null intrinsic zoom ratio null through the codec', () {
      final decoded = CameraInterface.codec.decodeMessage(
        CameraInterface.codec.encodeMessage(
          _device(PigeonSensorType.wideAngle, '0'),
        ),
      )! as PigeonSensorTypeDevice;

      expect(decoded.intrinsicZoomRatio, isNull);
    });

    test('carries the intrinsic zoom ratio through the codec', () {
      final decoded = CameraInterface.codec.decodeMessage(
        CameraInterface.codec.encodeMessage(
          _device(PigeonSensorType.ultraWideAngle, '2', intrinsicZoomRatio: 0.6),
        ),
      )! as PigeonSensorTypeDevice;

      expect(decoded.intrinsicZoomRatio, 0.6);
      expect(decoded.sensorType, PigeonSensorType.ultraWideAngle);
    });
  });
}
