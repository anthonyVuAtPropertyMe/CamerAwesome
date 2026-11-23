//
//  CameraPicture.m
//  camerawesome
//
//  Created by Dimitri Dessus on 24/07/2020.
//

#import "CameraPictureController.h"
#import "ExifContainer.h"
#import "NSData+Exif.h"

@implementation CameraPictureController {
  CameraPictureController *selfReference;
}

- (instancetype)initWithPath:(NSString *)path
                     orientation:(NSInteger)orientation
                  sensorPosition:(PigeonSensorPosition)sensorPosition
                 saveGPSLocation:(bool)saveGPSLocation
               mirrorFrontCamera:(bool)mirrorFrontCamera
                     aspectRatio:(AspectRatio)aspectRatio
                      completion:(nonnull void (^)(NSNumber * _Nullable, FlutterError * _Nullable))completion
                        callback:(OnPictureTaken)callback {
  self = [super init];
  NSAssert(self, @"super init cannot be nil");
  _path = path;
  _completion = completion;
  _orientation = orientation;
  _completionBlock = callback;
  _sensorPosition = sensorPosition;
  _saveGPSLocation = saveGPSLocation;
  _aspectRatioType = aspectRatio;
  _mirrorFrontCamera = mirrorFrontCamera;
  
  if (aspectRatio == Ratio4_3) {
    _aspectRatio = 4.0/3.0;
  } else if(aspectRatio == Ratio16_9) {
    _aspectRatio = 16.0/9.0;
  } else {
    _aspectRatio = 1;
  }
  
  selfReference = self;
  return self;
}

- (NSData *)writeMetadataIntoImageData:(NSData *)imageData metadata:(NSMutableDictionary *)metadata {
  // create an imagesourceref
  CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef) imageData, NULL);
  
  // this is the type of image (e.g., public.jpeg)
  CFStringRef UTI = CGImageSourceGetType(source);
  
  // create a new data object and write the new image into it
  NSMutableData *dest_data = [NSMutableData data];
  CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)dest_data, UTI, 1, NULL);
  if (!destination) {
    NSLog(@"Error: Could not create image destination");
  }
  // add the image contained in the image source to the destination, overidding the old metadata with our modified metadata
  CGImageDestinationAddImageFromSource(destination, source, 0, (__bridge CFDictionaryRef) metadata);
  BOOL success = NO;
  success = CGImageDestinationFinalize(destination);
  if (!success) {
    NSLog(@"Error: Could not create data from image destination");
  }
  CFRelease(destination);
  CFRelease(source);
  return dest_data;
}

+ (dispatch_queue_t)ioQueue {
  static dispatch_queue_t queue;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    queue = dispatch_queue_create("com.apparence.camerawesome.photo-io", DISPATCH_QUEUE_SERIAL);
  });
  return queue;
}

- (void)captureOutput:(AVCapturePhotoOutput *)output
didFinishProcessingPhoto:(AVCapturePhoto *)photo
                error:(NSError *)error {
  selfReference = nil;
  if (error) {
    _completion(nil, [FlutterError errorWithCode:@"CAPTURE ERROR" message:error.description details:@""]);
    return;
  }

  if ([self canWriteDirectly:photo]) {
    NSData *directData = _saveGPSLocation
        ? [photo fileDataRepresentationWithCustomizer:self]
        : [photo fileDataRepresentation];
    if (directData != nil) {
      [self writeDirectly:directData];
      return;
    }
  }

  NSData *data = [photo fileDataRepresentation];
  if (data == nil) {
    _completion(nil, [FlutterError errorWithCode:@"CAPTURE ERROR" message:@"no photo data" details:@""]);
    return;
  }
  [self cropAndWrite:data];
}

/// The camera's own file can be written as it is when the preview set the photo connection's
/// orientation (so the file carries the right EXIF Orientation) and the photo already has the
/// requested aspect ratio. Anything else (front camera, another ratio) goes through the crop.
- (BOOL)canWriteDirectly:(AVCapturePhoto *)photo {
  if (!_writesPhotoDirectly || _sensorPosition != PigeonSensorPositionBack) {
    return NO;
  }
  CMVideoDimensions dimensions = photo.resolvedSettings.photoDimensions;
  double longEdge = MAX(dimensions.width, dimensions.height);
  double shortEdge = MAX(1, MIN(dimensions.width, dimensions.height));
  return fabs(longEdge / shortEdge - _aspectRatio) <= 0.01;
}

- (void)writeDirectly:(NSData *)data {
  dispatch_async([CameraPictureController ioQueue], ^{
    if (![data writeToFile:self->_path options:NSDataWritingAtomic error:nil]) {
      self->_completion(nil, [FlutterError errorWithCode:@"IOError" message:@"unable to write file" details:nil]);
      return;
    }
    self->_completionBlock();
  });
}

/// Adds GPS to the camera's own metadata; only used when `saveGPSLocation` is true.
- (NSDictionary<NSString *, id> *)replacementMetadataForPhoto:(AVCapturePhoto *)photo {
  NSMutableDictionary<NSString *, id> *metadata = [photo.metadata mutableCopy];
  CLLocation *location = [[CLLocationManager new] location];
  if (location != nil) {
    ExifContainer *container = [[ExifContainer alloc] init];
    [container addLocation:location];
    metadata[(NSString *)kCGImagePropertyGPSDictionary] =
        container.exifData[(NSString *)kCGImagePropertyGPSDictionary];
  }
  return metadata;
}

- (void)applyOrientationToPhotoConnectionOf:(AVCapturePhotoOutput *)output {
  AVCaptureConnection *connection = [output connectionWithMediaType:AVMediaTypeVideo];
  if (connection == nil) {
    return;
  }
  // The same orientation the crop path stamps on its image, so both paths write the same EXIF
  // Orientation for the back camera.
  AVCaptureVideoOrientation videoOrientation;
  CGFloat angle;
  switch ([self getJpegOrientation]) {
    case UIImageOrientationLeft:
      videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
      angle = 270;
      break;
    case UIImageOrientationDown:
      videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
      angle = 180;
      break;
    case UIImageOrientationUp:
      videoOrientation = AVCaptureVideoOrientationLandscapeRight;
      angle = 0;
      break;
    default:
      videoOrientation = AVCaptureVideoOrientationPortrait;
      angle = 90;
      break;
  }
  if (@available(iOS 17.0, *)) {
    if ([connection isVideoRotationAngleSupported:angle]) {
      connection.videoRotationAngle = angle;
      return;
    }
  }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  if (connection.isVideoOrientationSupported) {
    connection.videoOrientation = videoOrientation;
  }
#pragma clang diagnostic pop
}

- (void)cropAndWrite:(NSData *)data {
  // Add exif data
  ExifContainer *container = [[ExifContainer alloc] init];
  [container addCreationDate:[NSDate date]];
  
  // Save GPS location only if provided
  if (_saveGPSLocation) {
    CLLocationManager *locationManager = [CLLocationManager new];
    CLLocation *location = [locationManager location];
    [container addLocation:location];
  }
  
  UIImage *image = [UIImage imageWithCGImage:[UIImage imageWithData:data].CGImage
                                       scale:1.0
                                 orientation:[self getJpegOrientation]];
  float originalWidth = image.size.width;
  float originalHeight = image.size.height;
  
  float originalImageAspectRatio = originalWidth / originalHeight;
  
  float outputWidth = originalWidth;
  float outputHeight = originalHeight;
  if (originalImageAspectRatio != _aspectRatio) {
    if (originalImageAspectRatio > _aspectRatio) {
      outputWidth = originalHeight * _aspectRatio;
    } else if (originalImageAspectRatio < _aspectRatio) {
      outputHeight = originalWidth / _aspectRatio;
    }
  }
  
  UIImage *imageConverted = [self imageByCroppingImage:image toSize:CGSizeMake(outputWidth, outputHeight)];
  
  image = [UIImage imageWithCGImage:[imageConverted CGImage] scale:0.0 orientation:[self getJpegOrientation]];

  NSData *imageWithExif = [UIImageJPEGRepresentation(image, 1.0) addExif:container];
  
  bool success = [imageWithExif writeToFile:_path atomically:YES];
  if (!success) {
    _completion(nil, [FlutterError errorWithCode:@"IOError" message:@"unable to write file" details:nil]);
    return;
  }
  _completionBlock();
  
}

- (UIImage *)imageByCroppingImage:(UIImage *)image toSize:(CGSize)size {
  double newCropWidth, newCropHeight;

  if(image.size.width < image.size.height) {
    if (image.size.width < size.width) {
      newCropWidth = size.width;
    } else {
      newCropWidth = image.size.width;
    }
    newCropHeight = (newCropWidth * size.height)/size.width;
  } else {
    if (image.size.height < size.height) {
      newCropHeight = size.height;
    } else {
      newCropHeight = image.size.height;
    }
    newCropWidth = (newCropHeight * size.width)/size.height;
  }
  
  double imageHeightDivided = image.size.height/2.0;
  double imageWidthDivided = image.size.width/2.0;
  
  double x = imageWidthDivided - newCropWidth/2.0;
  double y = imageHeightDivided - newCropHeight/2.0;
  
  CGRect cropRect;
  if (UIDeviceOrientationIsLandscape(_orientation)) {
    cropRect = CGRectMake(x, y, newCropWidth, newCropHeight);
  } else {
    if (_aspectRatioType == Ratio16_9) {
      cropRect = CGRectMake(0, 0, image.size.height, image.size.width);
    } else {
      if (_aspectRatioType == Ratio4_3) {
        double localX = imageHeightDivided - (imageHeightDivided / _aspectRatio);
        cropRect = CGRectMake(localX, 0, image.size.height / _aspectRatio, image.size.width);
      } else {
        cropRect = CGRectMake(y, x, newCropWidth, newCropHeight);
      }
    }
  }
  
  CGImageRef imageRef = CGImageCreateWithImageInRect([image CGImage], cropRect);
  
  UIImage *cropped = [UIImage imageWithCGImage:imageRef];
  CGImageRelease(imageRef);
  
  return cropped;
}

// Helper #1: map a “known” UIDeviceOrientation → UIImageOrientation
- (UIImageOrientation)imageOrientationFromDeviceOrientation:(UIDeviceOrientation)devOrient {
    switch (devOrient) {
        case UIDeviceOrientationPortrait:
            return (self.sensorPosition == PigeonSensorPositionFront && _mirrorFrontCamera)
                ? UIImageOrientationLeftMirrored
                : UIImageOrientationRight;
        case UIDeviceOrientationPortraitUpsideDown:
            return UIImageOrientationLeft;
        case UIDeviceOrientationLandscapeLeft:
            return (self.sensorPosition == PigeonSensorPositionBack)
                ? UIImageOrientationDown
                : UIImageOrientationUp;
        case UIDeviceOrientationLandscapeRight:
            return (self.sensorPosition == PigeonSensorPositionBack)
                ? UIImageOrientationUp
                : UIImageOrientationDown;
        default:
            return UIImageOrientationUp;
    }
}

// Helper #2: map a UIInterfaceOrientation → UIImageOrientation
- (UIImageOrientation)imageOrientationFromInterfaceOrientation:(UIInterfaceOrientation)uiOrient {
    switch (uiOrient) {
        case UIInterfaceOrientationPortrait:
            return (self.sensorPosition == PigeonSensorPositionFront && _mirrorFrontCamera)
                ? UIImageOrientationLeftMirrored
                : UIImageOrientationRight;
        case UIInterfaceOrientationPortraitUpsideDown:
            return UIImageOrientationLeft;
        case UIInterfaceOrientationLandscapeLeft:
            return (self.sensorPosition == PigeonSensorPositionBack)
                ? UIImageOrientationDown
                : UIImageOrientationUp;
        case UIInterfaceOrientationLandscapeRight:
            return (self.sensorPosition == PigeonSensorPositionBack)
                ? UIImageOrientationUp
                : UIImageOrientationDown;
        default:
            return UIImageOrientationUp;
    }
}

- (UIImageOrientation)getJpegOrientation {
    UIDeviceOrientation devOrient = _orientation;
    // Check if _orientation is one of the ones we handle directly
    if (devOrient != UIDeviceOrientationUnknown) {
        return [self imageOrientationFromDeviceOrientation:devOrient];
    }

    // Fallback: pull the UI orientation
    UIInterfaceOrientation uiOrient;
    if (@available(iOS 13.0, *)) {
        uiOrient = UIApplication.sharedApplication
                        .windows.firstObject.windowScene.interfaceOrientation;
    } else {
        uiOrient = UIApplication.sharedApplication.statusBarOrientation;
    }
    return [self imageOrientationFromInterfaceOrientation:uiOrient];
}

@end
