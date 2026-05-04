import 'package:camerawesome/pigeon.dart';

/// Container format used when capturing photos.
///
/// Defaults to [jpeg] on every platform — selecting [heic] is a no-op on
/// Android and Web, where capture continues to produce JPEG. On iOS 11+
/// (HEVC-capable devices), [heic] produces genuine HEIF/HEIC files via
/// `AVCapturePhotoOutput`. On older iOS hardware, the plugin gracefully
/// falls back to JPEG.
enum PictureFormat {
  jpeg,
  heic;

  /// File extension (without leading dot) the default path builder uses
  /// for this format.
  String get fileExtension {
    switch (this) {
      case PictureFormat.jpeg:
        return 'jpg';
      case PictureFormat.heic:
        return 'heic';
    }
  }

  PigeonPhotoFormat toPigeon() {
    switch (this) {
      case PictureFormat.jpeg:
        return PigeonPhotoFormat.jpeg;
      case PictureFormat.heic:
        return PigeonPhotoFormat.heic;
    }
  }
}
