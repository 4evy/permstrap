#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PSTPermissionManifest;

typedef void (^PSTPermissionConfirmationHandler)(BOOL confirmed);

__attribute__((objc_subclassing_restricted))
@interface PSTPermissionConfirmationController
    : NSWindowController<NSTableViewDataSource, NSTableViewDelegate>

- (instancetype)initWithManifest:(PSTPermissionManifest *)manifest
    NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithWindow:(nullable NSWindow *)window NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (void)presentForWindow:(NSWindow *)parentWindow
              completion:(PSTPermissionConfirmationHandler)completion;

@end

NS_ASSUME_NONNULL_END
