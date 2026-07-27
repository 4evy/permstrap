#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

__attribute__((objc_subclassing_restricted))
@interface PSTAppDelegate : NSObject<NSApplicationDelegate, NSWindowDelegate>

- (instancetype)initWithCredentialArgument:(char *_Nullable)credentialArgument
                                targetsURL:(nullable NSURL *)targetsURL
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init;
- (void)start;
- (void)chooseTargets:(nullable id)sender;
- (void)createTargets:(nullable id)sender;
- (void)showAboutWindow:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END
