import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:camerawesome/pigeon.dart';
import 'package:camerawesome/src/orchestrator/file/content/file_content.dart';
import 'package:image/image.dart' as img;
import 'package:camerawesome/camerawesome_plugin.dart';

class FilterHandler {
  Isolate? photoFilterIsolate;

  Future<void> apply({
    required CaptureRequest captureRequest,
    required AwesomeFilter filter,
    PictureFormat pictureFormat = PictureFormat.jpeg,
  }) async {
    if (Platform.isIOS && filter.id != AwesomeFilter.None.id) {
      photoFilterIsolate?.kill(priority: Isolate.immediate);

      // Platform channels are unavailable inside a spawned Isolate, so
      // HEIC→JPEG conversion must happen here on the main isolate first.
      Map<String, Uint8List> preloadedBytes = {};
      if (pictureFormat == PictureFormat.heic) {
        final files = captureRequest.when(
          single: (single) => [single.file],
          multiple: (multiple) => multiple.fileBySensor.values.toList(),
        );
        final conversions = await Future.wait(
          files.nonNulls.map((f) async {
            final bytes = await CameraInterface().convertHeicToJpeg(f.path);
            return MapEntry(f.path, bytes);
          }),
        );
        preloadedBytes = Map.fromEntries(conversions);
      }

      ReceivePort port = ReceivePort();
      photoFilterIsolate = await Isolate.spawn<PhotoFilterModel>(
        applyFilter,
        PhotoFilterModel(captureRequest, filter.output,
            pictureFormat: pictureFormat, preloadedBytes: preloadedBytes),
        onExit: port.sendPort,
      );
      await port.first;

      photoFilterIsolate?.kill(priority: Isolate.immediate);
    }
  }
}

Future<CaptureRequest> applyFilter(PhotoFilterModel model) async {
  final files = model.captureRequest.when(
    single: (single) => [single.file],
    multiple: (multiple) => multiple.fileBySensor.values.toList(),
  );
  final fileContent = FileContent();
  for (final f in files) {
    // f is expected to not be null since the picture should have already been taken
    final Uint8List? rawBytes =
        model.preloadedBytes[f!.path] ?? await fileContent.read(f);
    if (rawBytes == null) {
      throw Exception('Could not read image ${f.path}');
    }
    final img.Image? image = img.decodeImage(rawBytes);
    if (image == null) {
      throw Exception('Could not decode image ${f.path}');
    }

    final pixels = image.getBytes();
    model.filter.apply(pixels, image.width, image.height);
    final img.Image out = img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: pixels.buffer,
    );

    // The image package has no HEIC encoder. Filtered output is always JPEG,
    // so a .heic capture file will contain JPEG bytes after this point.
    final Uint8List encodedImage = img.encodeJpg(out);
    await fileContent.write(f, encodedImage);
  }
  return model.captureRequest;
}
