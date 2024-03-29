#import "RnVideoEditor.h"
#import <React/RCTLog.h>

@implementation RnVideoEditor

RCT_EXPORT_MODULE()

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

RCT_EXPORT_METHOD(mergeVideos:(NSArray *)filePaths
                  saveToDirectoryName:(NSString *)saveToDirectoryName
                  fileName:(NSString *)fileName
                  :(RCTResponseSenderBlock)failureCallback
                  :(RCTResponseSenderBlock)successCallback) {

    [self MergeVideos:filePaths saveToDirectoryName:saveToDirectoryName fileName:fileName successCallback:successCallback];
}

-(void)MergeVideos:
                (NSArray *)filePaths
                saveToDirectoryName:(NSString *)saveToDirectoryName
                fileName:(NSString *)fileName
                successCallback:(RCTResponseSenderBlock)success
{

    CGFloat totalDuration;
    totalDuration = 0;

    AVMutableComposition *mixComposition = [[AVMutableComposition alloc] init];

    AVMutableCompositionTrack *videoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                        preferredTrackID:kCMPersistentTrackID_Invalid];

    AVMutableCompositionTrack *audioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio
                                                                        preferredTrackID:kCMPersistentTrackID_Invalid];

    CMTime insertTime = kCMTimeZero;
    CGAffineTransform originalTransform;

    for (id path in filePaths)
    {
        NSLog(path);
        AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:path]];
        
        NSLog(@"Asset count: %lu", (unsigned long)[asset tracks].count);
        CMTimeRange timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration);

        NSArray<AVAssetTrack *> *videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
        [videoTrack insertTimeRange:timeRange
                            ofTrack:[videoTracks objectAtIndex:0]
                             atTime:insertTime
                              error:nil];

        NSArray<AVAssetTrack *> *audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
        [audioTrack insertTimeRange:timeRange
                            ofTrack:[audioTracks objectAtIndex:0]
                             atTime:insertTime
                              error:nil];

        insertTime = CMTimeAdd(insertTime,asset.duration);

        // Get the first track from the asset and its transform.
        NSArray* tracks = [asset tracks];
        AVAssetTrack* track = [tracks objectAtIndex:0];
        originalTransform = [track preferredTransform];
    }

    // Use the transform from the original track to set the video track transform.
    if (originalTransform.a || originalTransform.b || originalTransform.c || originalTransform.d) {
        videoTrack.preferredTransform = originalTransform;
    }

    NSURL *outputURL = [RnVideoEditor getTusStoragePathForFileWithExtension:@"mp4" saveToDirectoryName:saveToDirectoryName fileNameParam:fileName];

    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetHighestQuality];
    exporter.outputURL = outputURL;
    exporter.outputFileType = @"com.apple.quicktime-movie";
    exporter.shouldOptimizeForNetworkUse = YES;

    [exporter exportAsynchronouslyWithCompletionHandler:^{

        switch ([exporter status])
        {
            case AVAssetExportSessionStatusFailed:
                break;

            case AVAssetExportSessionStatusCancelled:
                break;

            case AVAssetExportSessionStatusCompleted:
                success(@[@"merge video complete", outputURL.absoluteString]);
                break;

            default:
                break;
        }
    }];
}

- (NSString*) applicationDocumentsDirectory
{
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    return basePath;
}

/**
  If this logic ever changes update in:
  - node_modules/react-native-vision-camera/ios/PhotoCaptureDelegate.swift
  - node_modules/react-native-image-crop-picker/ios/src/ImageCropPicker.m
  - node_modules/@cpm/react-native-photo-editor/ios/PhotoEditor.swift
  - node_modules/rn-video-editor/ios/RnVideoEditor.m
*/
+ (nullable NSURL *)getTusStoragePathForFileWithExtension:(NSString *)fileExtension saveToDirectoryName:(NSString *)saveToDirectoryName fileNameParam:(NSString *)fileNameParam {
    NSArray *urls = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    NSURL *documentDirectory = [urls firstObject];
    NSURL *cacheDir = [documentDirectory URLByAppendingPathComponent:saveToDirectoryName];
    
    NSUUID *uuid = [NSUUID UUID];
    NSURL *uuidDir = [cacheDir URLByAppendingPathComponent:[uuid UUIDString]];
    NSString *fileName = [NSString stringWithFormat:@"%@.%@", fileNameParam, fileExtension];
    NSURL *filePath = [uuidDir URLByAppendingPathComponent:fileName];
    
    NSError *error = nil;
    
    BOOL doesExist = [[NSFileManager defaultManager] fileExistsAtPath:cacheDir.path isDirectory:NULL];
    if (!doesExist) {
        [[NSFileManager defaultManager] createDirectoryAtPath:cacheDir.path withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            return nil;
        }
    }
    
    BOOL doesUuidDirExist = [[NSFileManager defaultManager] fileExistsAtPath:uuidDir.path isDirectory:NULL];
    if (!doesUuidDirExist) {
        [[NSFileManager defaultManager] createDirectoryAtPath:uuidDir.path withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            return nil;
        }
    }
    
    return filePath;
}

@end
