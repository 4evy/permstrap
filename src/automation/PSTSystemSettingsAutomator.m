#import "automation/PSTSystemSettingsAutomator.h"

#import "automation/PSTAXUtilities.h"
#import "automation/PSTAutomaticFileDrag.h"
#import "automation/PSTSystemSettingsControl.h"
#import "automation/PSTSystemSettingsUIProfile.h"

#import <AppKit/AppKit.h>

#include "core/PSTPlatformPoll.h"

#include <math.h>

NSErrorDomain const PSTSystemSettingsAutomatorErrorDomain =
    @"dev.4evy.permstrap.system-settings";

static NSError *PSTSystemSettingsError(PSTSystemSettingsAutomatorError code,
                                       NSString *description) {
  return [NSError errorWithDomain:PSTSystemSettingsAutomatorErrorDomain
                             code:code
                         userInfo:@{NSLocalizedDescriptionKey : description}];
}

static NSError *PSTAccessibilityUnavailableError(void) {
  return PSTSystemSettingsError(
      PSTSystemSettingsAutomatorErrorAuthorization,
      @"Permstrap no longer has Accessibility access. "
       "Enable it in System Settings, then run the workflow again.");
}

BOOL PSTSystemSettingsAutomatorErrorAllowsContinuation(NSError *error) {
  if (![error.domain isEqualToString:PSTSystemSettingsAutomatorErrorDomain]) {
    return NO;
  }
  return pst_system_settings_error_allows_continuation(
      (PSTSystemSettingsAutomatorError)error.code);
}

static NSString *_Nullable PSTInjectionFailureDescription(
    PSTAuthorizationInjectionResult result) {
  const char *description = pst_authorization_injection_failure_description(result);
  if (description == nullptr) {
    if (result != PSTAuthorizationInjectionResultNoPrompt &&
        result != PSTAuthorizationInjectionResultInjected) {
      return @"The authorization injector returned an unknown result.";
    }
    return nil;
  }
  NSString *text = [NSString stringWithUTF8String:description];
  return text != nil ? text : @"The authorization injector returned an unknown result.";
}

typedef BOOL (^PSTServiceConfigurationHandler)(PSTPermissionOperation *operation,
                                               NSError *_Nullable *_Nullable error);

@interface PSTSystemSettingsAutomator ()

@property(nonatomic, strong) PSTAuthorizationInjector *injector;
@property(nonatomic, strong) PSTSystemSettingsUIProfile *profile;
@property(nonatomic, copy)
    NSDictionary<NSNumber *, PSTServiceConfigurationHandler> *handlersByMode;
@property(nonatomic, copy) NSArray<PSTPermissionOperation *> *plannedOperations;
@property(nonatomic, copy, nullable) NSString *currentServiceIdentifier;
@property(nonatomic) pid_t currentSystemSettingsProcessIdentifier;
@property(nonatomic, strong) NSMutableSet<NSString *> *currentPaneItems;

- (BOOL)configureApplicationListOperation:(PSTPermissionOperation *)operation
                                    error:(NSError *_Nullable *_Nullable)error;
- (BOOL)configureExistingRelationshipsOperation:(PSTPermissionOperation *)operation
                                          error:(NSError *_Nullable *_Nullable)error;
- (BOOL)enableApplicationSwitchForProcess:(pid_t)processIdentifier
                         switchIdentifier:(NSString *)switchIdentifier
                            requiresAdmin:(BOOL)requiresAdmin
                                    error:(NSError *_Nullable *_Nullable)error;
- (BOOL)pressElement:(AXUIElementRef)element processID:(pid_t)processIdentifier;

@end

@implementation PSTSystemSettingsAutomator

- (instancetype)initWithInjector:(PSTAuthorizationInjector *)injector {
  self = [super init];
  if (self != nil) {
    _injector = injector;
    _profile = PSTCurrentSystemSettingsUIProfile();
    _plannedOperations = @[];
    _currentPaneItems = [NSMutableSet set];
    __weak PSTSystemSettingsAutomator *weakSelf = self;
    _handlersByMode = @{@(PSTPermissionServiceModeApplicationList) : ^BOOL(
        PSTPermissionOperation *operation, NSError **error){
        return [weakSelf configureApplicationListOperation:operation error:error];
  }
  ,
      @(PSTPermissionServiceModeExistingRelationships)
      : ^BOOL(PSTPermissionOperation *operation, NSError **error) {
          return [weakSelf configureExistingRelationshipsOperation:operation
                                                             error:error];
        },
};
}
return self;
}

+ (NSSet<NSNumber *> *)supportedServiceModes {
  return [NSSet setWithArray:@[
    @(PSTPermissionServiceModeApplicationList),
    @(PSTPermissionServiceModeExistingRelationships),
  ]];
}

- (void)prepareForOperations:(NSArray<PSTPermissionOperation *> *)operations {
  self.plannedOperations = operations;
  self.currentServiceIdentifier = nil;
  self.currentSystemSettingsProcessIdentifier = 0;
  [self.currentPaneItems removeAllObjects];
}

- (BOOL)configureOperation:(PSTPermissionOperation *)operation
                     error:(NSError *_Nullable *_Nullable)error {
  if (!pst_ax_is_trusted(false)) {
    if (error != nullptr) {
      *error = PSTAccessibilityUnavailableError();
    }
    return NO;
  }
  PSTServiceConfigurationHandler handler =
      self.handlersByMode[@(operation.service.mode)];
  if (handler != nil) {
    BOOL succeeded = handler(operation, error);
    if (!succeeded) {
      self.currentServiceIdentifier = nil;
      self.currentSystemSettingsProcessIdentifier = 0;
      [self.currentPaneItems removeAllObjects];
    }
    return succeeded;
  }
  if (error != nullptr) {
    *error = PSTSystemSettingsError(
        PSTSystemSettingsAutomatorErrorUnsupportedMode,
        [NSString
            stringWithFormat:@"No System Settings strategy is declared for mode %@.",
                             operation.service.modeIdentifier]);
  }
  return NO;
}

- (void)report:(NSString *)message {
  if (self.statusHandler != nil) {
    self.statusHandler(message);
  }
}

- (BOOL)pressElement:(AXUIElementRef)element processID:(pid_t)process_identifier {
  return pst_ax_press_with_fallback(element, process_identifier);
}

static NSRunningApplication *
pst_system_settings_application(NSString *bundleIdentifier) {
  return [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleIdentifier]
      .firstObject;
}

static BOOL pst_open_url_without_activation(NSURL *url,
                                            PSTSystemSettingsUIProfile *profile) {
  __block BOOL opened = NO;
  dispatch_semaphore_t completion = dispatch_semaphore_create(0);
  dispatch_block_t open = ^{
    NSURL *application_url = [NSWorkspace.sharedWorkspace
        URLForApplicationWithBundleIdentifier:profile.bundleIdentifier];
    if (application_url == nil) {
      dispatch_semaphore_signal(completion);
      return;
    }
    NSWorkspaceOpenConfiguration *configuration =
        NSWorkspaceOpenConfiguration.configuration;
    configuration.activates = NO;
    configuration.promptsUserIfNeeded = NO;
    [NSWorkspace.sharedWorkspace
                    openURLs:@[ url ]
        withApplicationAtURL:application_url
               configuration:configuration
           completionHandler:^(NSRunningApplication *application, NSError *error) {
             opened = application != nil && error == nil;
             dispatch_semaphore_signal(completion);
           }];
  };

  if (NSThread.isMainThread) {
    open();
    NSDate *deadline =
        [NSDate dateWithTimeIntervalSinceNow:profile.workspaceOpenTimeoutInterval];
    while (dispatch_semaphore_wait(completion, DISPATCH_TIME_NOW) != 0 &&
           deadline.timeIntervalSinceNow > 0.0) {
      NSDate *next_poll =
          [NSDate dateWithTimeIntervalSinceNow:profile.mainRunLoopPollInterval];
      [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:next_poll];
    }
  } else {
    dispatch_async(dispatch_get_main_queue(), open);
    dispatch_time_t deadline = dispatch_time(
        DISPATCH_TIME_NOW,
        (int64_t)(profile.workspaceOpenTimeoutInterval * (NSTimeInterval)NSEC_PER_SEC));
    if (dispatch_semaphore_wait(completion, deadline) != 0) {
      return NO;
    }
  }
  return opened;
}

typedef struct PSTOpenServicePanePollContext {
  __unsafe_unretained PSTSystemSettingsAutomator *automator;
  __unsafe_unretained PSTPermissionService *service;
  pid_t *processIdentifier;
  bool accessibilityUnavailable;
} PSTOpenServicePanePollContext;

static PSTPlatformPollDecision PSTProbeOpenServicePane(void *rawContext) {
  PSTOpenServicePanePollContext *context = rawContext;
  if (!pst_ax_is_trusted(false)) {
    context->accessibilityUnavailable = true;
    return PSTPlatformPollDecisionStopped;
  }
  NSRunningApplication *application =
      pst_system_settings_application(context->automator.profile.bundleIdentifier);
  if (application == nil) {
    return PSTPlatformPollDecisionContinue;
  }
  *context->processIdentifier = application.processIdentifier;
  AXUIElementRef settings = pst_ax_copy_application(*context->processIdentifier);
  if (settings == nullptr) {
    return PSTPlatformPollDecisionContinue;
  }
  AXUIElementRef expectedWindow = pst_ax_copy_descendant_by_role_and_title(
      settings, kAXWindowRole, (__bridge CFStringRef)context->service.name);
  CFRelease(settings);
  if (expectedWindow == nullptr) {
    return PSTPlatformPollDecisionContinue;
  }
  CFRelease(expectedWindow);
  return PSTPlatformPollDecisionSucceeded;
}

- (BOOL)openServicePane:(PSTPermissionService *)service
           processIDOut:(pid_t *)processIdentifier
                  error:(NSError **)error {
  NSURL *url = [self.profile privacyPaneURLForRoute:service.route];
  if (url == nil) {
    if (error != nullptr) {
      *error = PSTSystemSettingsError(
          PSTSystemSettingsAutomatorErrorOpenPane,
          [NSString
              stringWithFormat:@"Invalid System Settings route for %@.", service.name]);
    }
    return NO;
  }

  BOOL opened = pst_open_url_without_activation(url, self.profile);
  if (!opened) {
    if (error != nullptr) {
      *error = PSTSystemSettingsError(
          PSTSystemSettingsAutomatorErrorOpenPane,
          [NSString
              stringWithFormat:@"System Settings did not open %@.", service.name]);
    }
    return NO;
  }

  PSTOpenServicePanePollContext context = {
      .automator = self,
      .service = service,
      .processIdentifier = processIdentifier,
  };
  PSTPlatformPollOutcome outcome =
      pst_platform_poll(self.profile.paneWaitNanoseconds, self.profile.pollNanoseconds,
                        PSTProbeOpenServicePane, &context);
  if (outcome == PSTPlatformPollOutcomeSucceeded) {
    return YES;
  }
  if (context.accessibilityUnavailable) {
    if (error != nullptr) {
      *error = PSTAccessibilityUnavailableError();
    }
    return NO;
  }
  if (error != nullptr) {
    *error = PSTSystemSettingsError(
        PSTSystemSettingsAutomatorErrorOpenPane,
        [NSString stringWithFormat:@"Timed out opening the %@ pane.", service.name]);
  }
  return NO;
}

- (nullable NSMutableSet<NSString *> *)inventoryForService:
                                           (PSTPermissionService *)service
                                                 processID:(pid_t)process_identifier {
  AXUIElementRef settings = pst_ax_copy_application(process_identifier);
  if (settings == nullptr) {
    return nil;
  }
  CFStringRef attribute = service.mode == PSTPermissionServiceModeApplicationList
                              ? kAXIdentifierAttribute
                              : kAXDescriptionAttribute;
  NSString *suffix = service.mode == PSTPermissionServiceModeApplicationList
                         ? self.profile.applicationSwitchSuffix
                         : self.profile.automationRowSuffix;
  CFArrayRef values = pst_ax_copy_descendant_string_attribute_values_with_suffix(
      settings, attribute, (__bridge CFStringRef)suffix);
  CFRelease(settings);
  if (values == nullptr) {
    return nil;
  }
  NSMutableSet<NSString *> *inventory =
      [NSMutableSet setWithArray:(__bridge NSArray<NSString *> *)values];
  CFRelease(values);
  return inventory;
}

- (BOOL)openServicePaneIfNeeded:(PSTPermissionService *)service
                   processIDOut:(pid_t *)process_identifier
                          error:(NSError **)error {
  NSRunningApplication *running =
      pst_system_settings_application(self.profile.bundleIdentifier);
  BOOL canReuse =
      [self.currentServiceIdentifier isEqualToString:service.identifier] &&
      running != nil &&
      running.processIdentifier == self.currentSystemSettingsProcessIdentifier;
  if (canReuse) {
    AXUIElementRef settings =
        pst_ax_copy_application(self.currentSystemSettingsProcessIdentifier);
    AXUIElementRef expected_window =
        settings == nullptr
            ? nullptr
            : pst_ax_copy_descendant_by_role_and_title(
                  settings, kAXWindowRole, (__bridge CFStringRef)service.name);
    canReuse = expected_window != nullptr;
    if (expected_window != nullptr) {
      CFRelease(expected_window);
    }
    if (settings != nullptr) {
      CFRelease(settings);
    }
  }
  if (canReuse) {
    *process_identifier = self.currentSystemSettingsProcessIdentifier;
    return YES;
  }

  if (![self openServicePane:service processIDOut:process_identifier error:error]) {
    return NO;
  }
  NSMutableSet<NSString *> *inventory = [self inventoryForService:service
                                                        processID:*process_identifier];
  if (inventory == nil) {
    if (error != nullptr) {
      *error = PSTSystemSettingsError(
          PSTSystemSettingsAutomatorErrorUIAction,
          [NSString
              stringWithFormat:@"Unable to inventory the %@ pane.", service.name]);
    }
    return NO;
  }
  self.currentServiceIdentifier = service.identifier;
  self.currentSystemSettingsProcessIdentifier = *process_identifier;
  self.currentPaneItems = inventory;
  [self
      report:[NSString stringWithFormat:@"Found %lu existing items in %@; reusing this "
                                         "inventory for the whole pane.",
                                        (unsigned long)inventory.count, service.name]];
  return YES;
}

typedef struct PSTActionCompletionPollContext {
  __unsafe_unretained BOOL (^completionCheck)(void);
} PSTActionCompletionPollContext;

static PSTPlatformPollDecision PSTProbeActionCompletion(void *rawContext) {
  PSTActionCompletionPollContext *context = rawContext;
  return context->completionCheck() ? PSTPlatformPollDecisionSucceeded
                                    : PSTPlatformPollDecisionContinue;
}

typedef struct PSTAdministrativeActionPollContext {
  __unsafe_unretained PSTSystemSettingsAutomator *automator;
  __unsafe_unretained BOOL (^completionCheck)(void);
  dispatch_group_t group;
  PSTAuthorizationInjectionResult *injectionResult;
  bool announcedInjection;
  __strong NSString *failureDescription;
} PSTAdministrativeActionPollContext;

static PSTPlatformPollDecision PSTProbeAdministrativeAction(void *rawContext) {
  PSTAdministrativeActionPollContext *context = rawContext;
  if (context->completionCheck()) {
    return PSTPlatformPollDecisionSucceeded;
  }
  if (dispatch_group_wait(context->group, DISPATCH_TIME_NOW) != 0) {
    return PSTPlatformPollDecisionContinue;
  }
  PSTAuthorizationInjectionResult result = *context->injectionResult;
  if (result == PSTAuthorizationInjectionResultInjected) {
    if (!context->announcedInjection) {
      [context->automator report:@"Password events were submitted to the verified "
                                  "authorization host."];
      context->announcedInjection = true;
      return PSTPlatformPollDecisionRestartDeadline;
    }
    return PSTPlatformPollDecisionContinue;
  }
  context->failureDescription = PSTInjectionFailureDescription(result);
  return context->failureDescription != nil ? PSTPlatformPollDecisionStopped
                                            : PSTPlatformPollDecisionContinue;
}

- (BOOL)performAction:(BOOL (^)(void))action
        completedWhen:(BOOL (^)(void))completion_check
        requiresAdmin:(BOOL)requires_admin
                error:(NSError **)error {
  if (!requires_admin) {
    if (!action()) {
      if (error != nullptr) {
        *error = PSTSystemSettingsError(
            PSTSystemSettingsAutomatorErrorUIAction,
            @"System Settings rejected an accessibility action.");
      }
      return NO;
    }
    PSTActionCompletionPollContext context = {
        .completionCheck = completion_check,
    };
    if (pst_platform_poll(self.profile.authorizationWaitNanoseconds,
                          self.profile.pollNanoseconds, PSTProbeActionCompletion,
                          &context) == PSTPlatformPollOutcomeSucceeded) {
      return YES;
    }
    if (error != nullptr) {
      *error = PSTSystemSettingsError(
          PSTSystemSettingsAutomatorErrorUIAction,
          @"The permission switch did not reach the enabled state.");
    }
    return NO;
  }

  NSError *arm_error = nil;
  if (![self.injector armForSystemSettingsOperation:&arm_error]) {
    if (error != nullptr) {
      *error = arm_error;
    }
    return NO;
  }

  __block PSTAuthorizationInjectionResult injection_result =
      PSTAuthorizationInjectionResultNoPrompt;
  dispatch_group_t group = dispatch_group_create();
  dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    injection_result = [self.injector
        waitAndInjectWithTimeoutNanoseconds:self.profile.authorizationWaitNanoseconds];
  });

  if (!action()) {
    [self.injector disarm];
    (void)dispatch_group_wait(group,
                              dispatch_time(DISPATCH_TIME_NOW, (int64_t)NSEC_PER_SEC));
    if (error != nullptr) {
      *error =
          PSTSystemSettingsError(PSTSystemSettingsAutomatorErrorUIAction,
                                 @"System Settings rejected an accessibility action.");
    }
    return NO;
  }

  PSTAdministrativeActionPollContext pollContext = {
      .automator = self,
      .completionCheck = completion_check,
      .group = group,
      .injectionResult = &injection_result,
  };
  PSTPlatformPollOutcome outcome = pst_platform_poll(
      self.profile.authorizationWaitNanoseconds, self.profile.pollNanoseconds,
      PSTProbeAdministrativeAction, &pollContext);
  [self.injector disarm];
  (void)dispatch_group_wait(group,
                            dispatch_time(DISPATCH_TIME_NOW, (int64_t)NSEC_PER_SEC));
  if (outcome == PSTPlatformPollOutcomeSucceeded) {
    return YES;
  }
  if (pollContext.failureDescription != nil) {
    if (error != nullptr) {
      *error = PSTSystemSettingsError(PSTSystemSettingsAutomatorErrorAuthorization,
                                      pollContext.failureDescription);
    }
    return NO;
  }
  if (error != nullptr) {
    *error = PSTSystemSettingsError(
        PSTSystemSettingsAutomatorErrorAuthorization,
        @"Timed out waiting for the administrator authorization to finish.");
  }
  return NO;
}

- (void)dismissRestartAlertForProcess:(pid_t)process_identifier {
  AXUIElementRef later_button = pst_system_settings_copy_button(
      process_identifier, (__bridge CFStringRef)self.profile.restartLaterButtonTitle);
  if (later_button != nullptr) {
    (void)[self pressElement:later_button processID:process_identifier];
    CFRelease(later_button);
  }
}

static AXUIElementRef PSTCopyPermissionList(pid_t process_identifier,
                                            PSTSystemSettingsUIProfile *profile,
                                            CGRect *list_frame) {
  AXUIElementRef application = pst_ax_copy_application(process_identifier);
  if (application == nullptr) {
    return nullptr;
  }

  AXUIElementRef best_list = nullptr;
  CGRect best_frame = CGRectZero;
  CGFloat best_area = 0.0;
  for (NSString *role in profile.permissionListRoles) {
    CFArrayRef candidates =
        pst_ax_copy_descendants_by_role(application, (__bridge CFStringRef)role);
    if (candidates == nullptr) {
      continue;
    }
    for (CFIndex index = 0; index < CFArrayGetCount(candidates); ++index) {
      AXUIElementRef candidate =
          (AXUIElementRef)CFArrayGetValueAtIndex(candidates, index);
      CGRect frame = CGRectZero;
      if (!pst_ax_copy_frame(candidate, &frame) || CGRectIsEmpty(frame) ||
          frame.size.width < profile.permissionListMinimumWidth ||
          frame.size.height < profile.permissionListMinimumHeight) {
        continue;
      }
      CGFloat area = frame.size.width * frame.size.height;
      BOOL is_rightmost =
          best_list == nullptr || CGRectGetMinX(frame) > CGRectGetMinX(best_frame);
      BOOL is_larger_at_same_position =
          best_list != nullptr &&
          fabs(CGRectGetMinX(frame) - CGRectGetMinX(best_frame)) <
              profile.permissionListFrameTolerance &&
          area > best_area;
      if (!is_rightmost && !is_larger_at_same_position) {
        continue;
      }
      if (best_list != nullptr) {
        CFRelease(best_list);
      }
      best_list = (AXUIElementRef)CFRetain(candidate);
      best_frame = frame;
      best_area = area;
    }
    CFRelease(candidates);
  }
  CFRelease(application);

  if (best_list != nullptr && list_frame != nullptr) {
    *list_frame = best_frame;
  }
  return best_list;
}

static BOOL PSTPermissionListDropPoint(pid_t process_identifier,
                                       PSTSystemSettingsUIProfile *profile,
                                       CGPoint *drop_point) {
  CGRect list_frame = CGRectZero;
  AXUIElementRef permission_list =
      PSTCopyPermissionList(process_identifier, profile, &list_frame);
  if (permission_list == nullptr || CGRectIsEmpty(list_frame)) {
    if (permission_list != nullptr) {
      CFRelease(permission_list);
    }
    return NO;
  }

  AXUIElementRef element = permission_list;
  for (NSUInteger depth = 0; depth < profile.permissionListAncestorLimit; ++depth) {
    AXUIElementRef parent = pst_ax_copy_parent(element);
    CFRelease(element);
    element = parent;
    if (element == nullptr) {
      break;
    }
    CFStringRef role = nullptr;
    if (pst_ax_copy_string_attribute(element, kAXRoleAttribute, &role)) {
      BOOL is_window = CFEqual(role, kAXWindowRole);
      CFRelease(role);
      if (is_window) {
        (void)AXUIElementPerformAction(element, kAXRaiseAction);
        break;
      }
    }
  }
  if (element != nullptr) {
    CFRelease(element);
  }

  CGFloat target_x = CGRectGetMinX(list_frame) + profile.dropOffsetFromLeft;
  CGFloat target_y = CGRectGetMaxY(list_frame) - profile.dropOffsetFromTop;
  target_x = fmin(fmax(target_x, CGRectGetMinX(list_frame) + profile.dropEdgeInset),
                  CGRectGetMaxX(list_frame) - profile.dropEdgeInset);
  target_y = fmin(fmax(target_y, CGRectGetMinY(list_frame) + profile.dropEdgeInset),
                  CGRectGetMaxY(list_frame) - profile.dropEdgeInset);
  *drop_point = CGPointMake(target_x, target_y);
  return isfinite(target_x) && isfinite(target_y);
}

- (BOOL)addApplicationsAtPaths:(NSArray<NSString *> *)application_paths
                     processID:(pid_t)process_identifier
             switchIdentifiers:(NSArray<NSString *> *)switch_identifiers
                 requiresAdmin:(BOOL)requires_admin
        addedSwitchIdentifiers:
            (NSArray<NSString *> *_Nullable *_Nullable)added_switch_identifiers
                         error:(NSError **)error {
  if (application_paths.count == 0 ||
      application_paths.count != switch_identifiers.count) {
    if (error != nullptr) {
      *error = PSTSystemSettingsError(PSTSystemSettingsAutomatorErrorAutomation,
                                      @"The application insertion batch was invalid.");
    }
    return NO;
  }
  for (NSString *path in application_paths) {
    if (![NSFileManager.defaultManager fileExistsAtPath:path]) {
      if (error != nullptr) {
        *error = PSTSystemSettingsError(
            PSTSystemSettingsAutomatorErrorAutomation,
            [NSString
                stringWithFormat:
                    @"The permission target disappeared before insertion: %@", path]);
      }
      return NO;
    }
  }

  CGPoint drop_point = CGPointZero;
  if (!PSTPermissionListDropPoint(process_identifier, self.profile, &drop_point)) {
    if (error != nullptr) {
      *error = PSTSystemSettingsError(
          PSTSystemSettingsAutomatorErrorAutomation,
          @"The permission pane did not expose a native file-drop list.");
    }
    return NO;
  }

  NSRunningApplication *destination_application =
      [NSRunningApplication runningApplicationWithProcessIdentifier:process_identifier];
  if (destination_application == nil) {
    if (error != nullptr) {
      *error = PSTSystemSettingsError(PSTSystemSettingsAutomatorErrorAutomation,
                                      @"System Settings is no longer running.");
    }
    return NO;
  }
  NSRunningApplication *previous_application =
      NSWorkspace.sharedWorkspace.frontmostApplication;
  BOOL destination_activated = NO;
  if ([destination_application activateWithOptions:NSApplicationActivateAllWindows]) {
    for (NSUInteger attempt = 0; attempt < self.profile.applicationActivationAttempts &&
                                 !destination_application.active;
         ++attempt) {
      pst_platform_wait(self.profile.applicationActivationPollNanoseconds);
    }
    destination_activated = destination_application.active;
  }

  if (!destination_activated) {
    if (error != nullptr) {
      *error = PSTSystemSettingsError(
          PSTSystemSettingsAutomatorErrorAutomation,
          @"System Settings could not be brought forward for the native file drop.");
    }
    return NO;
  }

  NSMutableArray<NSURL *> *file_urls =
      [NSMutableArray arrayWithCapacity:application_paths.count];
  for (NSString *path in application_paths) {
    [file_urls addObject:[NSURL fileURLWithPath:path]];
  }
  __block NSError *drag_error = nil;
  PSTAutomaticFileDrag *automatic_drag = [[PSTAutomaticFileDrag alloc] init];
  NSError *automatic_action_error = nil;
  BOOL inserted_automatically = [self
      performAction:^BOOL {
        return [automatic_drag dragFileURLs:file_urls
                              toQuartzPoint:drop_point
                                    timeout:self.profile.nativeDragTimeoutInterval
                                      error:&drag_error];
      }
      completedWhen:^BOOL {
        for (NSString *switch_identifier in switch_identifiers) {
          if (pst_system_settings_permission_switch_state(
                  process_identifier, (__bridge CFStringRef)switch_identifier) ==
              PSTPermissionSwitchStateUnavailable) {
            return NO;
          }
        }
        return YES;
      }
      requiresAdmin:requires_admin
      error:&automatic_action_error];
  if (previous_application != nil &&
      previous_application.processIdentifier != process_identifier) {
    (void)[previous_application activateWithOptions:NSApplicationActivateAllWindows];
  }

  if (!inserted_automatically) {
    if (error != nullptr) {
      NSString *failure_description = drag_error.localizedDescription != nil
                                          ? drag_error.localizedDescription
                                          : automatic_action_error.localizedDescription;
      *error = PSTSystemSettingsError(
          PSTSystemSettingsAutomatorErrorAutomation,
          failure_description != nil
              ? [NSString stringWithFormat:@"The native file drop failed: %@",
                                           failure_description]
              : @"System Settings rejected the native file drop.");
    }
    return NO;
  }

  if (added_switch_identifiers != nullptr) {
    *added_switch_identifiers = switch_identifiers;
  }
  [self report:[NSString
                   stringWithFormat:@"Added %lu permission target%@ with an automatic "
                                    @"native file drop.",
                                    (unsigned long)application_paths.count,
                                    application_paths.count == 1 ? @"" : @"s"]];
  return YES;
}

- (NSArray<PSTPermissionOperation *> *)missingBatchForOperation:
    (PSTPermissionOperation *)operation {
  NSMutableArray<PSTPermissionOperation *> *batch = [NSMutableArray array];
  for (PSTPermissionOperation *candidate in self.plannedOperations) {
    if (candidate.service.mode != PSTPermissionServiceModeApplicationList ||
        ![candidate.service.identifier isEqualToString:operation.service.identifier]) {
      continue;
    }
    NSString *candidate_switch =
        [self.profile switchIdentifierForApplicationPath:candidate.applicationPath];
    if (![self.currentPaneItems containsObject:candidate_switch]) {
      [batch addObject:candidate];
    }
  }
  return batch.count > 0 ? batch : @[ operation ];
}

typedef struct PSTPermissionSwitchPollContext {
  pid_t processIdentifier;
  __unsafe_unretained NSString *switchIdentifier;
  PSTPermissionSwitchState state;
} PSTPermissionSwitchPollContext;

static PSTPlatformPollDecision PSTProbePermissionSwitch(void *rawContext) {
  PSTPermissionSwitchPollContext *context = rawContext;
  context->state = pst_system_settings_permission_switch_state(
      context->processIdentifier, (__bridge CFStringRef)context->switchIdentifier);
  if (context->state == PSTPermissionSwitchStateEnabled) {
    return PSTPlatformPollDecisionSucceeded;
  }
  if (context->state == PSTPermissionSwitchStateDisabled) {
    return PSTPlatformPollDecisionStopped;
  }
  return PSTPlatformPollDecisionContinue;
}

- (BOOL)enableApplicationSwitchForProcess:(pid_t)process_identifier
                         switchIdentifier:(NSString *)switch_identifier
                            requiresAdmin:(BOOL)requires_admin
                                    error:(NSError **)error {
  PSTPermissionSwitchPollContext context = {
      .processIdentifier = process_identifier,
      .switchIdentifier = switch_identifier,
      .state = PSTPermissionSwitchStateUnavailable,
  };
  if (pst_platform_poll(self.profile.elementWaitNanoseconds,
                        self.profile.pollNanoseconds, PSTProbePermissionSwitch,
                        &context) == PSTPlatformPollOutcomeSucceeded) {
    return YES;
  }

  if (context.state != PSTPermissionSwitchStateDisabled) {
    if (error != nullptr) {
      NSString *description =
          context.state == PSTPermissionSwitchStateUnavailable
              ? @"The permission switch did not appear after adding the application."
              : @"The permission switch appeared, but its state could not be read.";
      *error =
          PSTSystemSettingsError(PSTSystemSettingsAutomatorErrorUIAction, description);
    }
    return NO;
  }

  return [self
      performAction:^BOOL {
        AXUIElementRef toggle = pst_system_settings_copy_element_by_identifier(
            process_identifier, (__bridge CFStringRef)switch_identifier);
        if (toggle == nullptr) {
          return NO;
        }
        BOOL pressed = [self pressElement:toggle processID:process_identifier];
        CFRelease(toggle);
        return pressed;
      }
      completedWhen:^BOOL {
        return pst_system_settings_permission_switch_state(
                   process_identifier, (__bridge CFStringRef)switch_identifier) ==
               PSTPermissionSwitchStateEnabled;
      }
      requiresAdmin:requires_admin
      error:error];
}

- (BOOL)configureApplicationListOperation:(PSTPermissionOperation *)operation
                                    error:(NSError **)error {
  PSTPermissionService *service = operation.service;
  NSString *application_path = operation.applicationPath;
  pid_t process_identifier = 0;
  if (![self openServicePaneIfNeeded:service
                        processIDOut:&process_identifier
                               error:error]) {
    return NO;
  }
  NSString *switch_identifier =
      [self.profile switchIdentifierForApplicationPath:application_path];
  if (![self.currentPaneItems containsObject:switch_identifier]) {
    NSArray<PSTPermissionOperation *> *batch =
        [self missingBatchForOperation:operation];
    NSArray<NSString *> *paths = [batch valueForKey:@"applicationPath"];
    NSMutableArray<NSString *> *switch_identifiers =
        [NSMutableArray arrayWithCapacity:paths.count];
    for (NSString *path in paths) {
      [switch_identifiers
          addObject:[self.profile switchIdentifierForApplicationPath:path]];
    }
    NSArray<NSString *> *added_switch_identifiers = @[];
    if (![self addApplicationsAtPaths:paths
                            processID:process_identifier
                    switchIdentifiers:switch_identifiers
                        requiresAdmin:service.requiresAdmin
               addedSwitchIdentifiers:&added_switch_identifiers
                                error:error]) {
      return NO;
    }
    [self.currentPaneItems addObjectsFromArray:added_switch_identifiers];
  }

  BOOL succeeded = [self enableApplicationSwitchForProcess:process_identifier
                                          switchIdentifier:switch_identifier
                                             requiresAdmin:service.requiresAdmin
                                                     error:error];
  [self dismissRestartAlertForProcess:process_identifier];
  return succeeded;
}

- (BOOL)configureExistingRelationshipsOperation:(PSTPermissionOperation *)operation
                                          error:(NSError **)error {
  PSTPermissionService *service = operation.service;
  PSTPermissionTarget *target = operation.target;
  pid_t process_identifier = 0;
  if (![self openServicePaneIfNeeded:service
                        processIDOut:&process_identifier
                               error:error]) {
    return NO;
  }
  NSString *target_row_name = [self.profile automationRowNameForTargetName:target.name];
  if (![self.currentPaneItems containsObject:target_row_name]) {
    [self
        report:[NSString stringWithFormat:
                             @"%@ has no existing Automation requests; nothing can be "
                              "pre-granted.",
                             target.name]];
    return YES;
  }
  AXUIElementRef settings = pst_ax_copy_application(process_identifier);
  if (settings == nullptr) {
    if (error != nullptr) {
      *error = PSTSystemSettingsError(PSTSystemSettingsAutomatorErrorAutomation,
                                      @"Unable to inspect the Automation pane.");
    }
    return NO;
  }
  AXUIElementRef target_row = pst_ax_copy_descendant_by_attribute(
      settings, kAXDescriptionAttribute, (__bridge CFStringRef)target_row_name);
  CFRelease(settings);
  if (target_row == nullptr) {
    [self.currentPaneItems removeObject:target_row_name];
    if (error != nullptr) {
      *error =
          PSTSystemSettingsError(PSTSystemSettingsAutomatorErrorAutomation,
                                 @"An inventoried Automation target row disappeared.");
    }
    return NO;
  }

  CFArrayRef toggles = pst_ax_copy_descendants_by_role(
      target_row, (__bridge CFStringRef)self.profile.automationToggleRole);
  if (toggles == nullptr || CFArrayGetCount(toggles) == 0) {
    AXUIElementRef disclosure = pst_ax_copy_descendant_by_attribute(
        target_row, kAXRoleAttribute,
        (__bridge CFStringRef)self.profile.automationDisclosureRole);
    if (disclosure != nullptr) {
      (void)[self pressElement:disclosure processID:process_identifier];
      CFRelease(disclosure);
      pst_platform_wait(self.profile.disclosureSettleNanoseconds);
    }
    if (toggles != nullptr) {
      CFRelease(toggles);
    }
    CFRelease(target_row);
    settings = pst_ax_copy_application(process_identifier);
    target_row = settings == nullptr ? nullptr
                                     : pst_ax_copy_descendant_by_attribute(
                                           settings, kAXDescriptionAttribute,
                                           (__bridge CFStringRef)target_row_name);
    if (settings != nullptr) {
      CFRelease(settings);
    }
    if (target_row == nullptr) {
      if (error != nullptr) {
        *error = PSTSystemSettingsError(PSTSystemSettingsAutomatorErrorAutomation,
                                        @"The Automation target row disappeared.");
      }
      return NO;
    }
    toggles = pst_ax_copy_descendants_by_role(
        target_row, (__bridge CFStringRef)self.profile.automationToggleRole);
  }

  BOOL success = YES;
  if (toggles != nullptr) {
    CFIndex toggle_count = CFArrayGetCount(toggles);
    for (CFIndex index = 0; index < toggle_count; index++) {
      AXUIElementRef toggle = (AXUIElementRef)CFArrayGetValueAtIndex(toggles, index);
      bool enabled = false;
      if (pst_ax_copy_boolean_value(toggle, &enabled) && !enabled &&
          ![self pressElement:toggle processID:process_identifier]) {
        success = NO;
        break;
      }
    }
    CFRelease(toggles);
  }
  CFRelease(target_row);
  if (!success && error != nullptr) {
    *error = PSTSystemSettingsError(PSTSystemSettingsAutomatorErrorAutomation,
                                    @"Unable to enable an Automation relationship.");
  }
  return success;
}

@end
