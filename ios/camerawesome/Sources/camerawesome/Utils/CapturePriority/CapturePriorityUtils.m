//
//  CapturePriorityUtils.m
//  camerawesome
//

#import "CapturePriorityUtils.h"

@implementation CapturePriorityUtils

+ (void)allowAllPrioritizationsOnOutput:(AVCapturePhotoOutput *)output {
  if (@available(iOS 13.0, *)) {
    output.maxPhotoQualityPrioritization = AVCapturePhotoQualityPrioritizationQuality;
  }
}

+ (void)applyPriority:(PigeonCapturePriority)priority
           toSettings:(AVCapturePhotoSettings *)settings
               output:(AVCapturePhotoOutput *)output {
  if (@available(iOS 13.0, *)) {
    AVCapturePhotoQualityPrioritization requested;
    switch (priority) {
      case PigeonCapturePrioritySpeed:
        requested = AVCapturePhotoQualityPrioritizationSpeed;
        break;
      case PigeonCapturePriorityBalanced:
        requested = AVCapturePhotoQualityPrioritizationBalanced;
        break;
      case PigeonCapturePriorityQuality:
        requested = AVCapturePhotoQualityPrioritizationQuality;
        break;
      default:
        return;
    }
    settings.photoQualityPrioritization = MIN(requested, output.maxPhotoQualityPrioritization);
  }
}

@end
