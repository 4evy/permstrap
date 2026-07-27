#import <ApplicationServices/ApplicationServices.h>
#import <Foundation/Foundation.h>

#include <stdint.h>

NS_ASSUME_NONNULL_BEGIN

__attribute__((objc_subclassing_restricted))
@interface PSTSystemSettingsUIProfile : NSObject

@property(nonatomic, copy, readonly) NSString *bundleIdentifier;
@property(nonatomic, copy, readonly) NSString *privacyPaneURLPrefix;
@property(nonatomic, copy, readonly) NSString *accessibilityBootstrapRoute;
@property(nonatomic, copy, readonly) NSString *restartLaterButtonTitle;
@property(nonatomic, copy, readonly) NSString *applicationSwitchSuffix;
@property(nonatomic, copy, readonly) NSString *automationRowSuffix;
@property(nonatomic, copy, readonly) NSString *automationToggleRole;
@property(nonatomic, copy, readonly) NSString *automationDisclosureRole;
@property(nonatomic, copy, readonly) NSArray<NSString *> *permissionListRoles;
@property(nonatomic, readonly) CGFloat permissionListMinimumWidth;
@property(nonatomic, readonly) CGFloat permissionListMinimumHeight;
@property(nonatomic, readonly) CGFloat permissionListFrameTolerance;
@property(nonatomic, readonly) NSUInteger permissionListAncestorLimit;
@property(nonatomic, readonly) CGFloat dropOffsetFromLeft;
@property(nonatomic, readonly) CGFloat dropOffsetFromTop;
@property(nonatomic, readonly) CGFloat dropEdgeInset;
@property(nonatomic, readonly) NSUInteger applicationActivationAttempts;
@property(nonatomic, readonly) NSTimeInterval workspaceOpenTimeoutInterval;
@property(nonatomic, readonly) NSTimeInterval mainRunLoopPollInterval;
@property(nonatomic, readonly) uint64_t paneWaitNanoseconds;
@property(nonatomic, readonly) uint64_t elementWaitNanoseconds;
@property(nonatomic, readonly) uint64_t authorizationWaitNanoseconds;
@property(nonatomic, readonly) uint64_t applicationActivationPollNanoseconds;
@property(nonatomic, readonly) NSTimeInterval nativeDragTimeoutInterval;
@property(nonatomic, readonly) uint64_t disclosureSettleNanoseconds;
@property(nonatomic, readonly) uint64_t pollNanoseconds;

- (instancetype)init NS_UNAVAILABLE;
- (nullable NSURL *)privacyPaneURLForRoute:(NSString *)route;
- (NSString *)switchIdentifierForApplicationPath:(NSString *)applicationPath;
- (NSString *)automationRowNameForTargetName:(NSString *)targetName;

@end

FOUNDATION_EXPORT PSTSystemSettingsUIProfile *PSTCurrentSystemSettingsUIProfile(void);

NS_ASSUME_NONNULL_END
