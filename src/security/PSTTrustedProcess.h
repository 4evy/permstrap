#import <Foundation/Foundation.h>

#include "policy/PSTRuntimePolicyTypes.h"
#include "security/PSTTrustedProcessTypes.h"

#include <stdint.h>
#include <sys/types.h>

NS_ASSUME_NONNULL_BEGIN

@class NSRunningApplication;

FOUNDATION_EXPORT NSErrorDomain const PSTTrustedProcessErrorDomain;

__attribute__((objc_subclassing_restricted))
@interface PSTTrustedProcessPolicy : NSObject

@property(nonatomic, copy, readonly) NSString *bundleIdentifier;
@property(nonatomic, copy, readonly) NSString *executablePath;
@property(nonatomic, readonly) PSTTrustedProcessRole roles;
@property(nonatomic, readonly) BOOL requiresFrontmost;
@property(nonatomic, readonly) BOOL activePromptRequiresSecureField;
@property(nonatomic, copy, readonly, nullable) NSString *eventHostBundleIdentifier;
@property(nonatomic, copy, readonly, nullable) NSString *localizedNameContains;

- (instancetype)init NS_UNAVAILABLE;

@end

FOUNDATION_EXPORT NSArray<PSTTrustedProcessPolicy *> *PSTTrustedProcessPolicies(void);

FOUNDATION_EXPORT PSTTrustedProcessPolicy
    *_Nullable PSTTrustedProcessPolicyForBundleIdentifier(NSString *bundleIdentifier);

FOUNDATION_EXPORT NSArray<NSRunningApplication *> *
PSTRunningApplicationsWithRoles(PSTTrustedProcessRole roles);

FOUNDATION_EXPORT BOOL PSTValidateTrustedProcess(pid_t processIdentifier,
                                                 uint64_t notBeforeNanoseconds,
                                                 NSError *_Nullable *_Nullable error);

NS_ASSUME_NONNULL_END
