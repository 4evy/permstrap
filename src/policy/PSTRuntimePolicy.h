#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const PSTRuntimePolicyErrorDomain;

typedef NS_ERROR_ENUM(PSTRuntimePolicyErrorDomain, PSTRuntimePolicyError){
    PSTRuntimePolicyErrorInvalidJSON = 1,
    PSTRuntimePolicyErrorUnsupportedVersion,
    PSTRuntimePolicyErrorInvalidAuthorizationPrompt,
    PSTRuntimePolicyErrorInvalidSystemSettings,
    PSTRuntimePolicyErrorInvalidTrustedProcess,
    PSTRuntimePolicyErrorDuplicateTrustedProcess,
    PSTRuntimePolicyErrorInvalidRelationship,
    PSTRuntimePolicyErrorMissingResource,
    PSTRuntimePolicyErrorAlreadyLoaded,
};

__attribute__((objc_subclassing_restricted))
@interface PSTRuntimePolicy : NSObject

@property(nonatomic, copy, readonly) NSDictionary<NSString *, id> *authorizationPrompt;
@property(nonatomic, copy, readonly) NSDictionary<NSString *, id> *systemSettings;
@property(nonatomic, copy, readonly)
    NSArray<NSDictionary<NSString *, id> *> *trustedProcesses;

+ (nullable instancetype)policyWithData:(NSData *)data
                                  error:(NSError *_Nullable *_Nullable)error;
+ (nullable instancetype)policyWithContentsOfURL:(NSURL *)URL
                                           error:(NSError *_Nullable *_Nullable)error;
+ (nullable instancetype)bundledPolicyWithError:(NSError *_Nullable *_Nullable)error;

- (instancetype)init NS_UNAVAILABLE;

@end

FOUNDATION_EXPORT BOOL PSTLoadRuntimePolicy(NSURL *_Nullable URL,
                                            NSError *_Nullable *_Nullable error);
FOUNDATION_EXPORT PSTRuntimePolicy *PSTCurrentRuntimePolicy(void);

NS_ASSUME_NONNULL_END
