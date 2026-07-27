#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

__attribute__((objc_subclassing_restricted))
@interface PSTAboutWindowController : NSWindowController

- (instancetype)init;
- (instancetype)initWithWindow:(nullable NSWindow *)window NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
