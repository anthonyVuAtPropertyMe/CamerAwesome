import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:camerawesome/pigeon.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PhotoCaptureOptions.toPigeon', () {
    test('defaults keep the platform defaults', () {
      final pigeon = const PhotoCaptureOptions().toPigeon();

      // A null priority must not reach iOS as a null enum: Pigeon 9.2.5 decodes
      // that as the first value, so it is sent as platformDefault.
      expect(pigeon.priority, PigeonCapturePriority.platformDefault);
      expect(pigeon.quality, isNull);
      expect(pigeon.maxPhotoSize, isNull);
    });

    test('maps every priority to the Pigeon priority of the same name', () {
      for (final priority in CapturePriority.values) {
        expect(
          PhotoCaptureOptions(priority: priority).toPigeon().priority.name,
          priority.name,
        );
      }
    });

    test('maps quality and the photo size', () {
      final pigeon = const PhotoCaptureOptions(
        priority: CapturePriority.quality,
        quality: 95,
        maxPhotoSize: Size(1920, 1440),
      ).toPigeon();

      expect(pigeon.priority, PigeonCapturePriority.quality);
      expect(pigeon.quality, 95);
      expect(pigeon.maxPhotoSize?.width, 1920);
      expect(pigeon.maxPhotoSize?.height, 1440);
    });

    test('rejects a JPEG quality outside 1 to 100', () {
      // Not const on purpose: a const constructor evaluates the assert at compile time.
      // ignore: prefer_const_constructors
      expect(() => PhotoCaptureOptions(quality: 0), throwsAssertionError);
      // ignore: prefer_const_constructors
      expect(() => PhotoCaptureOptions(quality: 101), throwsAssertionError);
      expect(const PhotoCaptureOptions(quality: 1).quality, 1);
      expect(const PhotoCaptureOptions(quality: 100).quality, 100);
    });
  });

  group('SaveConfig.photoCaptureOptions', () {
    test('is empty by default for every constructor', () {
      for (final config in [
        SaveConfig.photo(),
        SaveConfig.video(),
        SaveConfig.photoAndVideo(),
      ]) {
        expect(config.photoCaptureOptions.priority, isNull);
        expect(config.photoCaptureOptions.quality, isNull);
        expect(config.photoCaptureOptions.maxPhotoSize, isNull);
      }
    });

    test('SaveConfig.photo keeps the options it is given', () {
      const options = PhotoCaptureOptions(
        priority: CapturePriority.speed,
        quality: 80,
        maxPhotoSize: Size(1920, 1440),
      );

      expect(
        SaveConfig.photo(photoCaptureOptions: options).photoCaptureOptions,
        same(options),
      );
    });
  });

  group('CamerawesomePlugin.setPhotoCaptureOptions', () {
    const channelName = 'dev.flutter.pigeon.CameraInterface.setPhotoCaptureOptions';
    late List<PigeonPhotoCaptureOptions> sent;

    setUp(() {
      sent = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(channelName, (ByteData? message) async {
        final arguments =
            CameraInterface.codec.decodeMessage(message) as List<Object?>;
        sent.add(arguments.single! as PigeonPhotoCaptureOptions);
        return CameraInterface.codec.encodeMessage(<Object?>[true]);
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(channelName, null);
    });

    test('sends the options through the Pigeon channel', () async {
      final applied = await CamerawesomePlugin.setPhotoCaptureOptions(
        const PhotoCaptureOptions(
          priority: CapturePriority.balanced,
          quality: 90,
          maxPhotoSize: Size(1920, 1440),
        ),
      );

      expect(applied, isTrue);
      expect(sent, hasLength(1));
      expect(sent.single.priority, PigeonCapturePriority.balanced);
      expect(sent.single.quality, 90);
      expect(sent.single.maxPhotoSize?.width, 1920);
      expect(sent.single.maxPhotoSize?.height, 1440);
    });

    test('sends the defaults as platformDefault with null fields', () async {
      await CamerawesomePlugin.setPhotoCaptureOptions(
        const PhotoCaptureOptions(),
      );

      expect(sent.single.priority, PigeonCapturePriority.platformDefault);
      expect(sent.single.quality, isNull);
      expect(sent.single.maxPhotoSize, isNull);
    });
  });
}
