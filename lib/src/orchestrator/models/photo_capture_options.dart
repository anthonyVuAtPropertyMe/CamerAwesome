import 'dart:ui' show Size;

import 'package:camerawesome/pigeon.dart';

/// How a photo capture trades speed against image processing.
///
/// - iOS: maps to `AVCapturePhotoQualityPrioritization` (`speed`, `balanced`,
///   `quality`).
/// - Android: [quality] selects CameraX `CAPTURE_MODE_MAXIMIZE_QUALITY`
///   (autofocus and flash metering before the shot, slower); [speed] and
///   [balanced] select `CAPTURE_MODE_MINIMIZE_LATENCY`.
enum CapturePriority {
  speed,
  balanced,
  quality,
}

/// Options for [SaveConfig.photo] captures. Every field left null keeps the
/// platform's default.
class PhotoCaptureOptions {
  /// Speed against processing, see [CapturePriority].
  final CapturePriority? priority;

  /// Android only: JPEG quality, from 1 to 100. Ignored on iOS.
  final int? quality;

  /// Android only: the photo size to ask CameraX for, in the sensor's
  /// landscape orientation (for example `Size(1920, 1440)` for 4:3).
  ///
  /// Despite its name it is not a hard maximum. CameraX picks the closest size
  /// the camera offers at or above it, and only if there is none, the closest
  /// below it. A phone whose smallest 4:3 size is 2576x1932 returns that size
  /// for a 1920x1440 request.
  ///
  /// Ignored on iOS, where the 4:3 photo format offers a single size
  /// (4032x3024 on a 12 MP camera).
  final Size? maxPhotoSize;

  const PhotoCaptureOptions({
    this.priority,
    this.quality,
    this.maxPhotoSize,
  }) : assert(
          quality == null || (quality >= 1 && quality <= 100),
          'quality must be between 1 and 100',
        );

  PigeonPhotoCaptureOptions toPigeon() {
    final size = maxPhotoSize;
    final priority = this.priority;
    return PigeonPhotoCaptureOptions(
      priority: priority == null
          ? PigeonCapturePriority.platformDefault
          : PigeonCapturePriority.values.byName(priority.name),
      quality: quality,
      maxPhotoSize: size == null
          ? null
          : PreviewSize(width: size.width, height: size.height),
    );
  }
}
