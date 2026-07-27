#import <Foundation/Foundation.h>

#import "security/PSTSecureBuffer.h"

#include "authorization/PSTAuthorizationInjectionTypes.h"

NS_ASSUME_NONNULL_BEGIN

__attribute__((objc_subclassing_restricted))
@interface PSTAuthorizationInjector : NSObject

- (instancetype)initWithCredential:(const PSTSecureBuffer *)credential;
- (BOOL)armForSystemSettingsOperation:(NSError *_Nullable *_Nullable)error;
- (PSTAuthorizationInjectionResult)waitAndInjectWithTimeoutNanoseconds:
    (uint64_t)timeoutNanoseconds;
- (void)disarm;

@end

NS_ASSUME_NONNULL_END
