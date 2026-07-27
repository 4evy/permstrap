#import <Foundation/Foundation.h>

#import "authorization/PSTAuthorizationInjector.h"
#import "permissions/PSTPermissionManifest.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^PSTWorkflowStatusHandler)(NSString *message);
typedef void (^PSTWorkflowCompletionHandler)(BOOL success, NSString *summary);

__attribute__((objc_subclassing_restricted))
@interface PSTPermissionWorkflow : NSObject

- (instancetype)initWithInjector:(PSTAuthorizationInjector *)injector
                        manifest:(PSTPermissionManifest *)manifest
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
- (void)runWithStatus:(PSTWorkflowStatusHandler)status
           completion:(PSTWorkflowCompletionHandler)completion;

@end

NS_ASSUME_NONNULL_END
