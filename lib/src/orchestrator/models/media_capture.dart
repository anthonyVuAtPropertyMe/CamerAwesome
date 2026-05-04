import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/foundation.dart';

enum MediaCaptureStatus {
  capturing,
  success,
  failure,
}

enum VideoState {
  started,
  paused,
  resumed,
  stopped,
  error,
}

class MediaCapture {
  final Exception? exception;
  final CaptureRequest captureRequest;
  final MediaCaptureStatus status;
  final VideoState? videoState;

  MediaCapture.capturing({
    this.exception,
    required this.captureRequest,
    this.videoState,
  }) : status = MediaCaptureStatus.capturing;

  MediaCapture.success({
    this.exception,
    required this.captureRequest,
  })  : status = MediaCaptureStatus.success,
        videoState = VideoState.stopped;

  MediaCapture.failure({
    this.exception,
    required this.captureRequest,
  })  : status = MediaCaptureStatus.failure,
        videoState = VideoState.error;

  /// Returns true if the capture has either a mimeType with "image" inside or
  /// if the file path ends with a still-image extension (`jpg` or `heic`).
  /// On Web, returns always true.
  bool get isPicture => kIsWeb
      ? true
      : captureRequest.when(
          single: (singleCaptureRequest) =>
              _isPicturePath(singleCaptureRequest.file?.path) ||
              singleCaptureRequest.file?.mimeType?.contains("image") == true,
          multiple: (multipleCaptureRequest) =>
              _isPicturePath(
                  multipleCaptureRequest.fileBySensor.values.first?.path) ||
              multipleCaptureRequest.fileBySensor.values.first?.mimeType
                      ?.contains("image") ==
                  true,
        );

  static bool _isPicturePath(String? path) {
    if (path == null) return false;
    final normalized = path.trim().toLowerCase().split('?').first.split('#').first;
    return normalized.endsWith('.jpg') ||
        normalized.endsWith('.jpeg') ||
        normalized.endsWith('.heic');
  }

  bool get isVideo => !isPicture;

  bool get isRecordingVideo =>
      isVideo && status == MediaCaptureStatus.capturing;
}
