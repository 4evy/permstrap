#import "policy/PSTRuntimePolicy.h"

#include "policy/PSTRuntimePolicyValidation.h"

NSErrorDomain const PSTRuntimePolicyErrorDomain = @"dev.4evy.permstrap.runtime-policy";

static_assert((int)PSTRuntimePolicyErrorInvalidJSON ==
              (int)PSTRuntimePolicyValidationInvalidJSON);
static_assert((int)PSTRuntimePolicyErrorUnsupportedVersion ==
              (int)PSTRuntimePolicyValidationUnsupportedVersion);
static_assert((int)PSTRuntimePolicyErrorInvalidAuthorizationPrompt ==
              (int)PSTRuntimePolicyValidationInvalidAuthorizationPrompt);
static_assert((int)PSTRuntimePolicyErrorInvalidSystemSettings ==
              (int)PSTRuntimePolicyValidationInvalidSystemSettings);
static_assert((int)PSTRuntimePolicyErrorInvalidTrustedProcess ==
              (int)PSTRuntimePolicyValidationInvalidTrustedProcess);
static_assert((int)PSTRuntimePolicyErrorDuplicateTrustedProcess ==
              (int)PSTRuntimePolicyValidationDuplicateTrustedProcess);
static_assert((int)PSTRuntimePolicyErrorInvalidRelationship ==
              (int)PSTRuntimePolicyValidationInvalidRelationship);

static PSTRuntimePolicy *pstCurrentRuntimePolicy;

static NSError *PSTPolicyError(PSTRuntimePolicyError code, NSString *path,
                               NSString *description) {
  return [NSError errorWithDomain:PSTRuntimePolicyErrorDomain
                             code:code
                         userInfo:@{
                           NSLocalizedDescriptionKey :
                               [NSString stringWithFormat:@"%@: %@", path, description]
                         }];
}

static BOOL PSTSetPolicyError(NSError *_Nullable *_Nullable error,
                              PSTRuntimePolicyError code, NSString *path,
                              NSString *description) {
  if (error != nullptr) {
    *error = PSTPolicyError(code, path, description);
  }
  return NO;
}

static NSError *
PSTPolicyValidationNSError(const PSTRuntimePolicyValidationError *validationError) {
  NSString *path = [NSString stringWithUTF8String:validationError->path];
  NSString *description = [NSString stringWithUTF8String:validationError->description];
  return PSTPolicyError(
      (PSTRuntimePolicyError)validationError->code, path != nil ? path : @"<root>",
      description != nil ? description : @"runtime policy validation failed");
}

@interface PSTRuntimePolicy ()

- (instancetype)
    initWithAuthorizationPrompt:(NSDictionary<NSString *, id> *)authorizationPrompt
                 systemSettings:(NSDictionary<NSString *, id> *)systemSettings
               trustedProcesses:
                   (NSArray<NSDictionary<NSString *, id> *> *)trustedProcesses
    NS_DESIGNATED_INITIALIZER;

@end

@implementation PSTRuntimePolicy

- (instancetype)
    initWithAuthorizationPrompt:(NSDictionary<NSString *, id> *)authorizationPrompt
                 systemSettings:(NSDictionary<NSString *, id> *)systemSettings
               trustedProcesses:
                   (NSArray<NSDictionary<NSString *, id> *> *)trustedProcesses {
  self = [super init];
  if (self != nil) {
    _authorizationPrompt = [authorizationPrompt copy];
    _systemSettings = [systemSettings copy];
    _trustedProcesses = [trustedProcesses copy];
  }
  return self;
}

+ (nullable instancetype)policyWithData:(NSData *)data
                                  error:(NSError *_Nullable *_Nullable)error {
  PSTRuntimePolicyValidationError validationError = {};
  if (!pst_runtime_policy_validate(data.bytes, data.length, &validationError)) {
    if (error != nullptr) {
      *error = PSTPolicyValidationNSError(&validationError);
    }
    return nil;
  }

  NSError *jsonError = nil;
  id value = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
  if (![value isKindOfClass:NSDictionary.class]) {
    if (error != nullptr) {
      *error = jsonError != nil
                   ? jsonError
                   : PSTPolicyError(PSTRuntimePolicyErrorInvalidJSON, @"<root>",
                                    @"validated JSON could not be materialized");
    }
    return nil;
  }

  NSDictionary<NSString *, id> *root = value;
  NSDictionary<NSString *, id> *authorizationPrompt = root[@"authorizationPrompt"];
  NSDictionary<NSString *, id> *systemSettings = root[@"systemSettings"];
  NSArray<NSDictionary<NSString *, id> *> *trustedProcesses = root[@"trustedProcesses"];
  return [[self alloc] initWithAuthorizationPrompt:authorizationPrompt
                                    systemSettings:systemSettings
                                  trustedProcesses:trustedProcesses];
}

+ (nullable instancetype)policyWithContentsOfURL:(NSURL *)URL
                                           error:(NSError *_Nullable *_Nullable)error {
  NSData *data = [NSData dataWithContentsOfURL:URL options:0 error:error];
  return data == nil ? nil : [self policyWithData:data error:error];
}

+ (nullable instancetype)bundledPolicyWithError:(NSError *_Nullable *_Nullable)error {
  NSURL *URL = [NSBundle.mainBundle URLForResource:@"RuntimePolicy"
                                     withExtension:@"json"];
  if (URL == nil) {
    if (error != nullptr) {
      *error =
          PSTPolicyError(PSTRuntimePolicyErrorMissingResource, @"RuntimePolicy.json",
                         @"bundled runtime policy is missing");
    }
    return nil;
  }
  return [self policyWithContentsOfURL:URL error:error];
}

@end

BOOL PSTLoadRuntimePolicy(NSURL *_Nullable URL, NSError *_Nullable *_Nullable error) {
  @synchronized(PSTRuntimePolicy.class) {
    if (pstCurrentRuntimePolicy != nil) {
      return PSTSetPolicyError(error, PSTRuntimePolicyErrorAlreadyLoaded,
                               @"RuntimePolicy.json",
                               @"runtime policy has already been loaded");
    }
    PSTRuntimePolicy *policy = nil;
    if (URL == nil) {
      policy = [PSTRuntimePolicy bundledPolicyWithError:error];
    } else {
      policy = [PSTRuntimePolicy policyWithContentsOfURL:(NSURL *_Nonnull)URL
                                                   error:error];
    }
    if (policy == nil) {
      return NO;
    }
    pstCurrentRuntimePolicy = policy;
    return YES;
  }
}

PSTRuntimePolicy *PSTCurrentRuntimePolicy(void) {
  @synchronized(PSTRuntimePolicy.class) {
    if (pstCurrentRuntimePolicy == nil) {
      [NSException
           raise:NSInternalInconsistencyException
          format:@"PSTLoadRuntimePolicy must succeed before policy is accessed."];
    }
    return pstCurrentRuntimePolicy;
  }
}
