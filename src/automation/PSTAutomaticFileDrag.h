#ifndef PST_AUTOMATIC_FILE_DRAG_H
#define PST_AUTOMATIC_FILE_DRAG_H

#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const PSTAutomaticFileDragErrorDomain;

typedef NS_ERROR_ENUM(PSTAutomaticFileDragErrorDomain, PSTAutomaticFileDragError){
    PSTAutomaticFileDragErrorInvalidInput = 1,
    PSTAutomaticFileDragErrorUnavailable,
    PSTAutomaticFileDragErrorTimedOut,
    PSTAutomaticFileDragErrorRejected,
};

@interface PSTFileURLPasteboardWriter : NSObject <NSPasteboardWriting>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithFileURL:(NSURL *)fileURL NS_DESIGNATED_INITIALIZER;

@end

@interface PSTAutomaticFileDrag : NSObject

- (BOOL)dragFileURLs:(NSArray<NSURL *> *)fileURLs
       toQuartzPoint:(CGPoint)destination
             timeout:(NSTimeInterval)timeout
               error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END

#endif
