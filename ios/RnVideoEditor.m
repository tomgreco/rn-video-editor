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
                  :(RCTResponseSenderBlock)failureCallback
                  :(RCTResponseSenderBlock)successCallback) {

    [self MergeVideos:filePaths saveToDirectoryName:saveToDirectoryName successCallback:successCallback];
}

-(void)MergeVideos:
                (NSArray *)filePaths
                saveToDirectoryName:(NSString *)saveToDirectoryName
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

    NSURL *outputURL = [RnVideoEditor getTusStoragePathForFileWithExtension:@"mp4" saveToDirectoryName:saveToDirectoryName ];

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


+ (nullable NSURL *)getTusStoragePathForFileWithExtension:(NSString *)fileExtension saveToDirectoryName:(NSString *)saveToDirectoryName {
    NSArray *urls = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    NSURL *documentDirectory = [urls firstObject];
    NSURL *tusDir = [documentDirectory URLByAppendingPathComponent:@"TUS"];
    
    NSUUID *uuid = [NSUUID UUID];
    NSURL *uuidDir = [tusDir URLByAppendingPathComponent:[uuid UUIDString]];
    NSString *fileName = [NSString stringWithFormat:@"0.%@", fileExtension];
    NSURL *filePath = [uuidDir URLByAppendingPathComponent:fileName];
    
    NSError *error = nil;
    
    BOOL doesExist = [[NSFileManager defaultManager] fileExistsAtPath:tusDir.path isDirectory:NULL];
    if (!doesExist) {
        [[NSFileManager defaultManager] createDirectoryAtPath:tusDir.path withIntermediateDirectories:YES attributes:nil error:&error];
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
