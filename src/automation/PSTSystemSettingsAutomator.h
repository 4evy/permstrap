#import <Foundation/Foundation.h>

#import "authorization/PSTAuthorizationInjector.h"
#import "permissions/PSTPermissionPlan.h"

#include "automation/PSTSystemSettingsTypes.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^PSTSystemSettingsStatusHandler)(NSString *message);

FOUNDATION_EXPORT NSErrorDomain const PSTSystemSettingsAutomatorErrorDomain;

FOUNDATION_EXPORT BOOL
PSTSystemSettingsAutomatorErrorAllowsContinuation(NSError *_Nullable error);

__attribute__((objc_subclassing_restricted))
@interface PSTSystemSettingsAutomator : NSObject

@property(nonatomic, copy, nullable) PSTSystemSettingsStatusHandler statusHandler;

- (instancetype)initWithInjector:(PSTAuthorizationInjector *)injector
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

+ (NSSet<NSNumber *> *)supportedServiceModes;

- (void)prepareForOperations:(NSArray<PSTPermissionOperation *> *)operations;
- (BOOL)configureOperation:(PSTPermissionOperation *)operation
                     error:(NSError *_Nullable *_Nullable)error;
@end

NS_ASSUME_NONNULL_END
