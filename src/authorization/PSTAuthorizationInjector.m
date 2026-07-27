#import "authorization/PSTAuthorizationInjector.h"

#import "authorization/PSTAuthorizationPlatform.h"
#import "authorization/PSTAuthorizationPromptPolicy.h"
#import "automation/PSTAXUtilities.h"
#import "core/PSTPlatformPoll.h"
#import "security/PSTTrustedProcess.h"

#import <AppKit/AppKit.h>

static NSErrorDomain const PSTAuthorizationInjectorErrorDomain =
    @"dev.4evy.permstrap.authorization";

typedef NS_ENUM(NSInteger, PSTAuthorizationInjectorError) {
  PSTAuthorizationInjectorErrorAlreadyArmed = 1,
  PSTAuthorizationInjectorErrorCredentialUnavailable,
  PSTAuthorizationInjectorErrorActivePrompt,
  PSTAuthorizationInjectorErrorClockUnavailable,
};

static NSError *PSTAuthorizationError(PSTAuthorizationInjectorError code,
                                      NSString *description) {
  return [NSError errorWithDomain:PSTAuthorizationInjectorErrorDomain
                             code:code
                         userInfo:@{NSLocalizedDescriptionKey : description}];
}

@interface PSTAuthorizationInjector ()

@property(nonatomic, assign) const PSTSecureBuffer *credential;
@property(nonatomic, assign) BOOL armed;
@property(nonatomic, assign) uint64_t armedAtNanoseconds;
@property(nonatomic, copy) NSSet<NSNumber *> *safeExistingProcesses;
@property(nonatomic, strong) PSTAuthorizationPromptPolicy *promptPolicy;

@end

@implementation PSTAuthorizationInjector

- (instancetype)initWithCredential:(const PSTSecureBuffer *)credential {
  self = [super init];
  if (self != nil) {
    _credential = credential;
    _safeExistingProcesses = [NSSet set];
    _promptPolicy = PSTCurrentAuthorizationPromptPolicy();
  }
  return self;
}

static NSArray<NSString *> *PSTVisibleText(AXUIElementRef element) {
  CFArrayRef visibleText = pst_ax_copy_visible_text(element);
  return visibleText != nullptr ? CFBridgingRelease(visibleText) : @[];
}

static bool pst_agent_has_active_prompt(NSRunningApplication *application,
                                        PSTAuthorizationPromptPolicy *promptPolicy) {
  AXUIElementRef agent = pst_ax_copy_application(application.processIdentifier);
  if (agent == nullptr) {
    return true;
  }
  AXUIElementRef secure_field = pst_ax_copy_secure_text_field(agent);
  bool has_secure_field = secure_field != nullptr;
  if (secure_field != nullptr) {
    CFRelease(secure_field);
  }
  bool has_authorization_text =
      [promptPolicy matchesCandidateText:PSTVisibleText(agent)];
  CFRelease(agent);
  NSString *bundle_identifier = application.bundleIdentifier;
  PSTTrustedProcessPolicy *policy = PSTTrustedProcessPolicyForBundleIdentifier(
      bundle_identifier != nil ? bundle_identifier : @"");
  if (policy.activePromptRequiresSecureField) {
    return has_secure_field && has_authorization_text;
  }
  return has_secure_field || has_authorization_text;
}

- (BOOL)armForSystemSettingsOperation:(NSError **)error {
  @synchronized(self) {
    if (self.armed) {
      if (error != nullptr) {
        *error = PSTAuthorizationError(PSTAuthorizationInjectorErrorAlreadyArmed,
                                       @"Credential injector is already armed.");
      }
      return NO;
    }
    if (self.credential == nullptr || self.credential->bytes == nullptr ||
        self.credential->data_length == 0) {
      if (error != nullptr) {
        *error =
            PSTAuthorizationError(PSTAuthorizationInjectorErrorCredentialUnavailable,
                                  @"No validated administrator password is in memory.");
      }
      return NO;
    }

    NSMutableSet<NSNumber *> *safe_processes = [NSMutableSet set];
    for (NSRunningApplication *application in PSTRunningApplicationsWithRoles(
             PSTTrustedProcessRoleAuthorizationObserver)) {
      NSError *identity_error = nil;
      if (!PSTValidateTrustedProcess(application.processIdentifier, 0,
                                     &identity_error)) {
        continue;
      }
      if (pst_agent_has_active_prompt(application, self.promptPolicy)) {
        if (error != nullptr) {
          *error =
              PSTAuthorizationError(PSTAuthorizationInjectorErrorActivePrompt,
                                    @"An authorization prompt already exists; refusing "
                                     "to arm automatic password entry.");
        }
        return NO;
      }
      [safe_processes addObject:@(application.processIdentifier)];
    }

    uint64_t now = pst_authorization_realtime_nanoseconds();
    if (now == 0) {
      if (error != nullptr) {
        *error =
            PSTAuthorizationError(PSTAuthorizationInjectorErrorClockUnavailable,
                                  @"Unable to timestamp the authorization operation.");
      }
      return NO;
    }
    self.safeExistingProcesses = safe_processes;
    self.armedAtNanoseconds = now;
    self.armed = YES;
    return YES;
  }
}

- (void)disarm {
  @synchronized(self) {
    self.armed = NO;
    self.armedAtNanoseconds = 0;
    self.safeExistingProcesses = [NSSet set];
  }
}

- (BOOL)isStillArmed {
  @synchronized(self) {
    return self.armed;
  }
}

- (BOOL)processWasSafeAtArmTime:(pid_t)processIdentifier {
  @synchronized(self) {
    return [self.safeExistingProcesses containsObject:@(processIdentifier)];
  }
}

- (uint64_t)minimumProcessStartTime {
  @synchronized(self) {
    uint64_t tolerance = self.promptPolicy.processAgeToleranceNanoseconds;
    return self.armedAtNanoseconds > tolerance ? self.armedAtNanoseconds - tolerance
                                               : 0;
  }
}

- (BOOL)authorizationTextIsExpected:(NSArray<NSString *> *)visibleText {
  return [self.promptPolicy matchesExpectedText:visibleText];
}

static pid_t pst_event_target_for_policy(PSTTrustedProcessPolicy *policy,
                                         pid_t default_target) {
  NSString *eventHostBundleIdentifier = policy.eventHostBundleIdentifier;
  if (eventHostBundleIdentifier == nil) {
    return default_target;
  }
  NSString *requiredBundleIdentifier = (NSString *_Nonnull)eventHostBundleIdentifier;
  for (NSRunningApplication *application in PSTRunningApplicationsWithRoles(
           PSTTrustedProcessRoleAuthorizationEventHost)) {
    if (![application.bundleIdentifier isEqualToString:requiredBundleIdentifier]) {
      continue;
    }
    if (PSTValidateTrustedProcess(application.processIdentifier, 0, nil)) {
      return application.processIdentifier;
    }
  }
  return 0;
}

- (PSTAuthorizationInjectionResult)inspectAndInject:
    (NSRunningApplication *)application {
  pid_t process_identifier = application.processIdentifier;
  NSString *bundle_identifier = application.bundleIdentifier;
  PSTTrustedProcessPolicy *policy = PSTTrustedProcessPolicyForBundleIdentifier(
      bundle_identifier != nil ? bundle_identifier : @"");
  if (policy == nil || !(policy.roles & PSTTrustedProcessRoleAuthorizationObserver)) {
    return PSTAuthorizationInjectionResultRejected;
  }
  uint64_t not_before = [self processWasSafeAtArmTime:process_identifier]
                            ? 0
                            : [self minimumProcessStartTime];
  NSError *identity_error = nil;
  if (!PSTValidateTrustedProcess(process_identifier, not_before, &identity_error)) {
    if ([identity_error.domain isEqualToString:PSTTrustedProcessErrorDomain]) {
      return pst_authorization_injection_result_for_trusted_process_error(
          (PSTTrustedProcessError)identity_error.code);
    }
    return PSTAuthorizationInjectionResultRejected;
  }

  if (!(policy.roles & PSTTrustedProcessRoleAuthorizationAXHost)) {
    return PSTAuthorizationInjectionResultNoPrompt;
  }
  NSRunningApplication *frontmost = NSWorkspace.sharedWorkspace.frontmostApplication;
  if (policy.requiresFrontmost && frontmost.processIdentifier != process_identifier) {
    return PSTAuthorizationInjectionResultNoPrompt;
  }

  AXUIElementRef agent = pst_ax_copy_application(process_identifier);
  if (agent == nullptr) {
    return PSTAuthorizationInjectionResultAXUnavailable;
  }
  NSArray<NSString *> *visible_text = PSTVisibleText(agent);
  if (![self authorizationTextIsExpected:visible_text]) {
    CFRelease(agent);
    return PSTAuthorizationInjectionResultNoPrompt;
  }

  AXUIElementRef secure_field = pst_authorization_copy_secure_field(
      agent, (__bridge CFArrayRef)self.promptPolicy.credentialRevealButtonTitles,
      self.promptPolicy.secureFieldAppearanceAttempts,
      self.promptPolicy.secureFieldAppearancePollNanoseconds);
  if (secure_field == nullptr) {
    CFRelease(agent);
    return PSTAuthorizationInjectionResultSecureFieldMissing;
  }
  BOOL focused = pst_authorization_focus_secure_field(
      agent, secure_field, self.promptPolicy.secureFieldAppearanceAttempts,
      self.promptPolicy.secureFieldAppearancePollNanoseconds);
  BOOL prompt_is_still_expected =
      [self authorizationTextIsExpected:PSTVisibleText(agent)];
  CFRelease(agent);
  CFRelease(secure_field);
  if (!prompt_is_still_expected) {
    return PSTAuthorizationInjectionResultNoPrompt;
  }
  if (!focused) {
    return PSTAuthorizationInjectionResultFocusFailed;
  }
  pid_t event_target = pst_event_target_for_policy(policy, process_identifier);
  if (event_target <= 0) {
    return PSTAuthorizationInjectionResultEventHostUnavailable;
  }
  return pst_authorization_post_credential(event_target, self.credential)
             ? PSTAuthorizationInjectionResultInjected
             : PSTAuthorizationInjectionResultEventSubmissionFailed;
}

typedef struct PSTAuthorizationInjectionPollContext {
  __unsafe_unretained PSTAuthorizationInjector *injector;
  PSTAuthorizationInjectionResult result;
} PSTAuthorizationInjectionPollContext;

static PSTPlatformPollDecision PSTProbeAuthorizationInjection(void *rawContext) {
  PSTAuthorizationInjectionPollContext *context = rawContext;
  if (![context->injector isStillArmed]) {
    return PSTPlatformPollDecisionStopped;
  }
  for (NSRunningApplication *application in PSTRunningApplicationsWithRoles(
           PSTTrustedProcessRoleAuthorizationAXHost)) {
    PSTAuthorizationInjectionResult candidateResult =
        [context->injector inspectAndInject:application];
    if (candidateResult == PSTAuthorizationInjectionResultNoPrompt) {
      continue;
    }
    context->result = candidateResult;
    if (!pst_authorization_injection_result_is_retryable(candidateResult)) {
      return PSTPlatformPollDecisionStopped;
    }
  }
  return PSTPlatformPollDecisionContinue;
}

- (PSTAuthorizationInjectionResult)waitAndInjectWithTimeoutNanoseconds:
    (uint64_t)timeoutNanoseconds {
  if (![self isStillArmed] || timeoutNanoseconds == 0) {
    return PSTAuthorizationInjectionResultRejected;
  }
  PSTAuthorizationInjectionPollContext context = {
      .injector = self,
      .result = PSTAuthorizationInjectionResultNoPrompt,
  };
  (void)pst_platform_poll(timeoutNanoseconds, self.promptPolicy.promptPollNanoseconds,
                          PSTProbeAuthorizationInjection, &context);
  [self disarm];
  return context.result;
}

@end
