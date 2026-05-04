import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:camerawesome/pigeon.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PictureFormat', () {
    test('exposes the expected file extensions', () {
      expect(PictureFormat.jpeg.fileExtension, 'jpg');
      expect(PictureFormat.heic.fileExtension, 'heic');
    });

    test('maps to the corresponding Pigeon enum', () {
      expect(PictureFormat.jpeg.toPigeon(), PigeonPhotoFormat.jpeg);
      expect(PictureFormat.heic.toPigeon(), PigeonPhotoFormat.heic);
    });
  });

  group('SaveConfig', () {
    test('SaveConfig.photo defaults pictureFormat to jpeg', () {
      final config = SaveConfig.photo();
      expect(config.pictureFormat, PictureFormat.jpeg);
    });

    test('SaveConfig.photo preserves a heic pictureFormat', () {
      final config = SaveConfig.photo(pictureFormat: PictureFormat.heic);
      expect(config.pictureFormat, PictureFormat.heic);
    });

    test('SaveConfig.photoAndVideo defaults pictureFormat to jpeg', () {
      final config = SaveConfig.photoAndVideo();
      expect(config.pictureFormat, PictureFormat.jpeg);
    });

    test('SaveConfig.photoAndVideo preserves a heic pictureFormat', () {
      final config =
          SaveConfig.photoAndVideo(pictureFormat: PictureFormat.heic);
      expect(config.pictureFormat, PictureFormat.heic);
    });

    test('SaveConfig.video always uses jpeg picture format', () {
      // Video-only configurations don't take photos; the field is fixed to
      // jpeg internally so behavior is identical to pre-HEIC versions.
      final config = SaveConfig.video();
      expect(config.pictureFormat, PictureFormat.jpeg);
    });
  });

  group('MediaCapture.isPicture', () {
    MediaCapture buildSingle(String path) {
      return MediaCapture.success(
        captureRequest: SingleCaptureRequest(
          path,
          Sensor.position(SensorPosition.back),
        ),
      );
    }

    test('recognises .jpg paths as pictures', () {
      expect(buildSingle('/tmp/foo.jpg').isPicture, isTrue);
    });

    test('recognises .heic paths as pictures', () {
      expect(buildSingle('/tmp/foo.heic').isPicture, isTrue);
    });

    test('recognises .jpeg paths as pictures', () {
      expect(buildSingle('/tmp/foo.jpeg').isPicture, isTrue);
    });

    test('recognises uppercase .JPG paths as pictures', () {
      expect(buildSingle('/tmp/foo.JPG').isPicture, isTrue);
    });

    test('recognises uppercase .HEIC paths as pictures', () {
      expect(buildSingle('/tmp/foo.HEIC').isPicture, isTrue);
    });

    test('recognises .jpg paths with query parameters as pictures', () {
      expect(buildSingle('/tmp/foo.jpg?version=1').isPicture, isTrue);
    });

    test('does not classify .mp4 as a picture', () {
      expect(buildSingle('/tmp/foo.mp4').isPicture, isFalse);
    });
  });

  // Touch the unused-import preventer. cross_file's XFile is the type the
  // capture-request layer wraps and we want to make sure the export chain is
  // intact so consumers can still build SingleCaptureRequest from a path.
  test('XFile can still be built from a path', () {
    final file = XFile('/tmp/foo.jpg');
    expect(file.path, '/tmp/foo.jpg');
  });
}
