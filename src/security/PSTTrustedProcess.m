#import "security/PSTTrustedProcess.h"

#import "policy/PSTRuntimePolicy.h"

#include "security/PSTTrustedProcessValidation.h"

#import <AppKit/AppKit.h>

NSErrorDomain const PSTTrustedProcessErrorDomain =
    @"dev.4evy.permstrap.trusted-process";

static NSError *PSTProcessError(PSTTrustedProcessError code, NSString *description) {
  return [NSError errorWithDomain:PSTTrustedProcessErrorDomain
                             code:code
                         userInfo:@{NSLocalizedDescriptionKey : description}];
}

@interface PSTTrustedProcessPolicy ()

- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
                          executablePath:(NSString *)executablePath
                                   roles:(PSTTrustedProcessRole)roles
                       requiresFrontmost:(BOOL)requiresFrontmost
         activePromptRequiresSecureField:(BOOL)activePromptRequiresSecureField
               eventHostBundleIdentifier:(NSString *_Nullable)eventHostBundleIdentifier
                   localizedNameContains:(NSString *_Nullable)localizedNameContains
    NS_DESIGNATED_INITIALIZER;

@end

@implementation PSTTrustedProcessPolicy

- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
                          executablePath:(NSString *)executablePath
                                   roles:(PSTTrustedProcessRole)roles
                       requiresFrontmost:(BOOL)requiresFrontmost
         activePromptRequiresSecureField:(BOOL)activePromptRequiresSecureField
               eventHostBundleIdentifier:(NSString *_Nullable)eventHostBundleIdentifier
                   localizedNameContains:(NSString *_Nullable)localizedNameContains {
  self = [super init];
  if (self != nil) {
    _bundleIdentifier = [bundleIdentifier copy];
    _executablePath = [executablePath copy];
    _roles = roles;
    _requiresFrontmost = requiresFrontmost;
    _activePromptRequiresSecureField = activePromptRequiresSecureField;
    _eventHostBundleIdentifier = [eventHostBundleIdentifier copy];
    _localizedNameContains = [localizedNameContains copy];
  }
  return self;
}

@end

static PSTTrustedProcessRole PSTTrustedProcessRoles(NSArray<NSString *> *identifiers) {
  PSTTrustedProcessRole roles = 0;
  for (NSString *identifier in identifiers) {
    PSTTrustedProcessRole role = {};
    if (pst_trusted_process_role_parse(identifier.UTF8String, &role)) {
      roles |= role;
    }
  }
  return roles;
}

NSArray<PSTTrustedProcessPolicy *> *PSTTrustedProcessPolicies(void) {
  static NSArray<PSTTrustedProcessPolicy *> *policies;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSArray<NSDictionary<NSString *, id> *> *configurations =
        PSTCurrentRuntimePolicy().trustedProcesses;
    NSMutableArray<PSTTrustedProcessPolicy *> *loadedPolicies =
        [NSMutableArray arrayWithCapacity:configurations.count];
    for (NSDictionary<NSString *, id> *configuration in configurations) {
      [loadedPolicies
          addObject:
              [[PSTTrustedProcessPolicy alloc]
                         initWithBundleIdentifier:configuration[@"bundleIdentifier"]
                                   executablePath:configuration[@"executablePath"]
                                            roles:PSTTrustedProcessRoles(
                                                      configuration[@"roles"])
                                requiresFrontmost:[configuration[@"requiresFrontmost"]
                                                      boolValue]
                  activePromptRequiresSecureField:
                      [configuration[@"activePromptRequiresSecureField"] boolValue]
                        eventHostBundleIdentifier:configuration
                                                      [@"eventHostBundleIdentifier"]
                            localizedNameContains:configuration
                                                      [@"localizedNameContains"]]];
    }
    policies = [loadedPolicies copy];
  });
  return policies;
}

PSTTrustedProcessPolicy *
PSTTrustedProcessPolicyForBundleIdentifier(NSString *bundleIdentifier) {
  for (PSTTrustedProcessPolicy *policy in PSTTrustedProcessPolicies()) {
    if ([policy.bundleIdentifier isEqualToString:bundleIdentifier]) {
      return policy;
    }
  }
  return nil;
}

NSArray<NSRunningApplication *> *
PSTRunningApplicationsWithRoles(PSTTrustedProcessRole roles) {
  NSMutableArray<NSRunningApplication *> *applications = [NSMutableArray array];
  for (PSTTrustedProcessPolicy *policy in PSTTrustedProcessPolicies()) {
    if ((policy.roles & roles) != roles) {
      continue;
    }
    for (NSRunningApplication *application in [NSRunningApplication
             runningApplicationsWithBundleIdentifier:policy.bundleIdentifier]) {
      NSString *localizedNameContains = policy.localizedNameContains;
      if (localizedNameContains != nil &&
          ![application.localizedName
              containsString:(NSString *_Nonnull)localizedNameContains]) {
        continue;
      }
      [applications addObject:application];
    }
  }
  return applications;
}

static NSError *
PSTIdentityValidationError(PSTTrustedProcessValidationError validationError) {
  const char *description =
      pst_trusted_process_validation_error_description(validationError);
  NSString *text = [NSString stringWithUTF8String:description];
  return PSTProcessError(pst_trusted_process_validation_public_error(validationError),
                         text != nil ? text
                                     : @"Trusted UI identity validation failed.");
}

BOOL PSTValidateTrustedProcess(pid_t processIdentifier, uint64_t notBeforeNanoseconds,
                               NSError *_Nullable *_Nullable error) {
  PSTTrustedProcessIdentity identity = {};
  PSTTrustedProcessValidationError validationError =
      PSTTrustedProcessValidationErrorNone;
  if (!pst_trusted_process_validate_identity(processIdentifier, notBeforeNanoseconds,
                                             &identity, &validationError)) {
    if (error != nullptr) {
      *error = PSTIdentityValidationError(validationError);
    }
    return NO;
  }

  NSString *identifier = [NSString stringWithUTF8String:identity.code_identifier];
  PSTTrustedProcessPolicy *policy =
      identifier == nil ? nil : PSTTrustedProcessPolicyForBundleIdentifier(identifier);
  if (policy == nil) {
    if (error != nullptr) {
      *error = PSTProcessError(PSTTrustedProcessErrorPolicyMissing,
                               @"Trusted UI process has no declared policy.");
    }
    return NO;
  }

  NSRunningApplication *application =
      [NSRunningApplication runningApplicationWithProcessIdentifier:processIdentifier];
  NSString *localizedNameContains = policy.localizedNameContains;
  if (localizedNameContains != nil &&
      ![application.localizedName
          containsString:(NSString *_Nonnull)localizedNameContains]) {
    if (error != nullptr) {
      *error = PSTProcessError(PSTTrustedProcessErrorInstanceMismatch,
                               @"Trusted UI process instance does not match policy.");
    }
    return NO;
  }

  NSString *actualPath = [NSString stringWithUTF8String:identity.executable_path];
  if (actualPath == nil || ![actualPath isEqualToString:policy.executablePath]) {
    if (error != nullptr) {
      *error = PSTProcessError(PSTTrustedProcessErrorPathInvalid,
                               @"Trusted UI process path is not allowed.");
    }
    return NO;
  }
  return YES;
}
