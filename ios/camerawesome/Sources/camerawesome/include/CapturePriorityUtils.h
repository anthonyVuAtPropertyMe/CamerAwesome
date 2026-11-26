//
//  CapturePriorityUtils.h
//  camerawesome
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "Pigeon.h"

NS_ASSUME_NONNULL_BEGIN

/// Maps the capture priority requested from Dart to AVCapturePhotoQualityPrioritization (iOS 13+).
@interface CapturePriorityUtils : NSObject

/// Lets the output accept every prioritization. The default maximum is `balanced`, and a capture
/// that asks for more than the output's maximum raises an exception.
+ (void)allowAllPrioritizationsOnOutput:(AVCapturePhotoOutput *)output;

/// Sets the requested prioritization on the settings of one capture, never above the output's
/// maximum. `platformDefault` leaves the settings as they are.
+ (void)applyPriority:(PigeonCapturePriority)priority
           toSettings:(AVCapturePhotoSettings *)settings
               output:(AVCapturePhotoOutput *)output;

@end

NS_ASSUME_NONNULL_END
