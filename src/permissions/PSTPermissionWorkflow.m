#import "permissions/PSTPermissionWorkflow.h"

#import "automation/PSTSystemSettingsAutomator.h"
#import "permissions/PSTPermissionPlan.h"

#include "permissions/PSTPermissionWorkflowCore.h"

@import AppKit;

@interface PSTPermissionWorkflow ()

@property(nonatomic, strong) PSTPermissionManifest *manifest;
@property(nonatomic, strong) PSTSystemSettingsAutomator *automator;
@property(nonatomic, copy, nullable) PSTWorkflowStatusHandler statusHandler;

- (void)report:(NSString *)message;

@end

typedef struct PSTPermissionWorkflowBridgeContext {
  __unsafe_unretained PSTPermissionWorkflow *workflow;
  __unsafe_unretained PSTSystemSettingsAutomator *automator;
  __unsafe_unretained NSArray<PSTPermissionOperation *> *operations;
  __unsafe_unretained NSMutableArray<NSString *> *failures;
} PSTPermissionWorkflowBridgeContext;

static PSTPermissionWorkflowOperationResult
PSTExecutePermissionOperation(size_t operationIndex, void *rawContext) {
  PSTPermissionWorkflowBridgeContext *context = rawContext;
  if (operationIndex >= context->operations.count) {
    [context->failures addObject:@"Permission workflow operation index was invalid."];
    return PSTPermissionWorkflowOperationFailedAndStop;
  }

  PSTPermissionOperation *operation = context->operations[operationIndex];
  [context->workflow
      report:[NSString stringWithFormat:@"Configuring %@ for %@…",
                                        operation.service.name, operation.target.name]];
  NSError *operationError = nil;
  if ([context->automator configureOperation:operation error:&operationError]) {
    return PSTPermissionWorkflowOperationSucceeded;
  }

  NSString *failure =
      [NSString stringWithFormat:@"%@ / %@ failed: %@", operation.target.name,
                                 operation.service.name,
                                 operationError.localizedDescription != nil
                                     ? operationError.localizedDescription
                                     : @"unknown error"];
  [context->failures addObject:failure];
  [context->workflow report:failure];
  if (PSTSystemSettingsAutomatorErrorAllowsContinuation(operationError)) {
    [context->workflow
        report:@"Continuing with the remaining independent permission operations."];
    return PSTPermissionWorkflowOperationFailedAndContinue;
  }
  [context->workflow
      report:@"Stopping because the failure could involve authorization or an "
              "undeclared execution strategy."];
  return PSTPermissionWorkflowOperationFailedAndStop;
}

@implementation PSTPermissionWorkflow

- (instancetype)initWithInjector:(PSTAuthorizationInjector *)injector
                        manifest:(PSTPermissionManifest *)manifest {
  self = [super init];
  if (self != nil) {
    _manifest = manifest;
    _automator = [[PSTSystemSettingsAutomator alloc] initWithInjector:injector];
  }
  return self;
}

- (void)report:(NSString *)message {
  if (self.statusHandler != nil) {
    self.statusHandler(message);
  }
}

- (nullable NSString *)resolvedPathForTarget:(PSTPermissionTarget *)target {
  for (NSString *rawCandidate in target.pathCandidates) {
    NSString *candidate = rawCandidate.stringByExpandingTildeInPath;
    BOOL isDirectory = NO;
    BOOL exists = [NSFileManager.defaultManager fileExistsAtPath:candidate
                                                     isDirectory:&isDirectory];
    BOOL isSupportedTarget =
        target.kind == PSTPermissionTargetKindApplicationBundle
            ? isDirectory
            : (!isDirectory &&
               [NSFileManager.defaultManager isExecutableFileAtPath:candidate]);
    if (exists && isSupportedTarget) {
      return candidate.stringByStandardizingPath;
    }
  }

  if (target.kind != PSTPermissionTargetKindApplicationBundle) {
    return nil;
  }
  for (NSString *bundleIdentifier in target.bundleIdentifiers) {
    NSURL *applicationURL = [NSWorkspace.sharedWorkspace
        URLForApplicationWithBundleIdentifier:bundleIdentifier];
    if (!applicationURL.isFileURL) {
      continue;
    }
    NSString *applicationPath = applicationURL.path;
    if (applicationPath == nil) {
      continue;
    }
    BOOL isDirectory = NO;
    BOOL exists = [NSFileManager.defaultManager fileExistsAtPath:applicationPath
                                                     isDirectory:&isDirectory];
    if (exists && isDirectory) {
      return applicationPath.stringByStandardizingPath;
    }
  }
  return nil;
}

- (BOOL)runSynchronouslyWithSummary:(NSString *_Nullable *_Nullable)summary {
  NSMutableArray<NSString *> *failures = [NSMutableArray array];
  NSError *planError = nil;
  PSTPermissionPlan *plan = [PSTPermissionPlan
      planWithManifest:self.manifest
          pathResolver:^NSString *_Nullable(PSTPermissionTarget *target) {
            return [self resolvedPathForTarget:target];
          }
                 error:&planError];
  if (plan == nil) {
    if (summary != nullptr) {
      *summary = planError.localizedDescription != nil
                     ? planError.localizedDescription
                     : @"Unable to create permission plan.";
    }
    return NO;
  }

  if (plan.missingRequiredTargets.count > 0) {
    NSArray<NSString *> *names = [plan.missingRequiredTargets valueForKey:@"name"];
    NSString *message =
        [NSString stringWithFormat:
                      @"Required permission targets were not found: %@. No permission "
                       "changes were attempted.",
                      [names componentsJoinedByString:@", "]];
    [self report:message];
    if (summary != nullptr) {
      *summary = message;
    }
    return NO;
  }

  for (PSTPermissionTarget *target in plan.missingOptionalTargets) {
    [self
        report:[NSString stringWithFormat:@"Skipping %@ because its permission target "
                                           "was not found.",
                                          target.name]];
  }

  PSTPermissionWorkflowBridgeContext context = {
      .workflow = self,
      .automator = self.automator,
      .operations = plan.operations,
      .failures = failures,
  };
  [self.automator prepareForOperations:plan.operations];
  PSTPermissionWorkflowOutcome outcome = {};
  if (!pst_permission_workflow_execute(
          plan.operations.count, PSTExecutePermissionOperation, &context, &outcome)) {
    if (summary != nullptr) {
      *summary = @"Unable to execute the permission workflow.";
    }
    return NO;
  }

  if (summary != nullptr) {
    if (pst_permission_workflow_succeeded(&outcome)) {
      *summary = [NSString
          stringWithFormat:@"Configured %lu permission operations; skipped %lu missing "
                            "applications.",
                           (unsigned long)outcome.completed_count,
                           (unsigned long)plan.missingOptionalTargets.count];
    } else {
      NSString *failureList = [failures componentsJoinedByString:@"\n• "];
      NSString *outcomeText = outcome.stopped_for_safety
                                  ? @"Stopped safely"
                                  : @"Finished the remaining operations";
      *summary = [NSString
          stringWithFormat:@"%@ after attempting %lu of %lu permission operations: "
                            "%lu configured, %lu failed, and %lu applications missing."
                            "\n• %@",
                           outcomeText, (unsigned long)outcome.attempted_count,
                           (unsigned long)outcome.operation_count,
                           (unsigned long)outcome.completed_count,
                           (unsigned long)outcome.failed_count,
                           (unsigned long)plan.missingOptionalTargets.count,
                           failureList];
    }
  }
  return pst_permission_workflow_succeeded(&outcome);
}

- (void)runWithStatus:(PSTWorkflowStatusHandler)status
           completion:(PSTWorkflowCompletionHandler)completion {
  self.statusHandler = status;
  self.automator.statusHandler = status;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    NSString *summary = nil;
    BOOL success = [self runSynchronouslyWithSummary:&summary];
    self.automator.statusHandler = nil;
    self.statusHandler = nil;
    completion(success, summary != nil ? summary : @"Permission workflow finished.");
  });
}

@end
