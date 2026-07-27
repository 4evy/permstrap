#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PSTPermissionService;

__attribute__((objc_subclassing_restricted))
@interface PSTPermissionTargetsEditorResult : NSObject

@property(nonatomic, copy, readonly) NSData *targetsData;
@property(nonatomic, copy, readonly, nullable) NSURL *savedURL;
@property(nonatomic, readonly) BOOL shouldApply;

- (instancetype)init NS_UNAVAILABLE;

@end

typedef void (^PSTPermissionTargetsEditorHandler)(
    PSTPermissionTargetsEditorResult *_Nullable result);

__attribute__((objc_subclassing_restricted))
@interface PSTPermissionTargetsEditorController
    : NSWindowController<NSTableViewDataSource, NSTableViewDelegate,
                         NSTextFieldDelegate>

- (instancetype)initWithServices:(NSArray<PSTPermissionService *> *)services
    NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithWindow:(nullable NSWindow *)window NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (void)presentForWindow:(NSWindow *)parentWindow
              completion:(PSTPermissionTargetsEditorHandler)completion;

@end

NS_ASSUME_NONNULL_END
