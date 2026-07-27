#import "permissions/PSTPermissionPlan.h"

#include "permissions/PSTPermissionPlanCore.h"

NSErrorDomain const PSTPermissionPlanErrorDomain = @"dev.4evy.permstrap.plan";

@interface PSTPermissionOperation ()

- (instancetype)initWithTarget:(PSTPermissionTarget *)target
                       service:(PSTPermissionService *)service
               applicationPath:(NSString *)applicationPath NS_DESIGNATED_INITIALIZER;

@end

typedef struct PSTPermissionPlanBridgeContext {
  __unsafe_unretained PSTPermissionManifest *manifest;
  __unsafe_unretained PSTPermissionTargetPathResolver pathResolver;
  __unsafe_unretained NSMutableArray<PSTPermissionOperation *> *operations;
  __unsafe_unretained NSMutableArray<PSTPermissionTarget *> *missingTargets;
  __unsafe_unretained NSMutableArray<PSTPermissionTarget *> *missingRequiredTargets;
  __unsafe_unretained NSMutableArray<PSTPermissionTarget *> *missingOptionalTargets;
  __strong NSString *resolvedPath;
} PSTPermissionPlanBridgeContext;

static PSTPermissionPlanHandle PSTPlanTargetAt(size_t index, void *rawContext) {
  PSTPermissionPlanBridgeContext *context = rawContext;
  PSTPermissionTarget *target = context->manifest.targets[index];
  return (__bridge const void *)target;
}

static PSTPermissionPlanHandle PSTPlanPathForTarget(PSTPermissionPlanHandle rawTarget,
                                                    void *rawContext) {
  PSTPermissionPlanBridgeContext *context = rawContext;
  PSTPermissionTarget *target = (__bridge PSTPermissionTarget *)rawTarget;
  context->resolvedPath = context->pathResolver(target);
  return (__bridge const void *)context->resolvedPath;
}

static size_t PSTPlanServiceCount(PSTPermissionPlanHandle rawTarget, void *rawContext) {
  (void)rawContext;
  PSTPermissionTarget *target = (__bridge PSTPermissionTarget *)rawTarget;
  return target.serviceIdentifiers.count;
}

static PSTPermissionPlanHandle PSTPlanServiceAt(PSTPermissionPlanHandle rawTarget,
                                                size_t index, void *rawContext) {
  PSTPermissionPlanBridgeContext *context = rawContext;
  PSTPermissionTarget *target = (__bridge PSTPermissionTarget *)rawTarget;
  NSString *identifier = target.serviceIdentifiers[index];
  PSTPermissionService *service = [context->manifest serviceForIdentifier:identifier];
  return (__bridge const void *)service;
}

static void PSTPlanEmitOperation(PSTPermissionPlanHandle rawTarget,
                                 PSTPermissionPlanHandle rawService,
                                 PSTPermissionPlanHandle rawPath, void *rawContext) {
  PSTPermissionPlanBridgeContext *context = rawContext;
  PSTPermissionTarget *target = (__bridge PSTPermissionTarget *)rawTarget;
  PSTPermissionService *service = (__bridge PSTPermissionService *)rawService;
  NSString *path = (__bridge NSString *)rawPath;
  [context->operations addObject:[[PSTPermissionOperation alloc] initWithTarget:target
                                                                        service:service
                                                                applicationPath:path]];
}

static void PSTPlanEmitMissingTarget(PSTPermissionPlanHandle rawTarget,
                                     void *rawContext) {
  PSTPermissionPlanBridgeContext *context = rawContext;
  PSTPermissionTarget *target = (__bridge PSTPermissionTarget *)rawTarget;
  [context->missingTargets addObject:target];
  if (target.isRequired) {
    [context->missingRequiredTargets addObject:target];
  } else {
    [context->missingOptionalTargets addObject:target];
  }
}

@implementation PSTPermissionOperation

- (instancetype)initWithTarget:(PSTPermissionTarget *)target
                       service:(PSTPermissionService *)service
               applicationPath:(NSString *)applicationPath {
  self = [super init];
  if (self != nil) {
    _target = target;
    _service = service;
    _applicationPath = [applicationPath copy];
  }
  return self;
}

@end

@interface PSTPermissionPlan ()

- (instancetype)
        initWithOperations:(NSArray<PSTPermissionOperation *> *)operations
            missingTargets:(NSArray<PSTPermissionTarget *> *)missingTargets
    missingRequiredTargets:(NSArray<PSTPermissionTarget *> *)missingRequiredTargets
    missingOptionalTargets:(NSArray<PSTPermissionTarget *> *)missingOptionalTargets
    NS_DESIGNATED_INITIALIZER;

@end

@implementation PSTPermissionPlan

- (instancetype)
        initWithOperations:(NSArray<PSTPermissionOperation *> *)operations
            missingTargets:(NSArray<PSTPermissionTarget *> *)missingTargets
    missingRequiredTargets:(NSArray<PSTPermissionTarget *> *)missingRequiredTargets
    missingOptionalTargets:(NSArray<PSTPermissionTarget *> *)missingOptionalTargets {
  self = [super init];
  if (self != nil) {
    _operations = [operations copy];
    _missingTargets = [missingTargets copy];
    _missingRequiredTargets = [missingRequiredTargets copy];
    _missingOptionalTargets = [missingOptionalTargets copy];
  }
  return self;
}

+ (nullable instancetype)planWithManifest:(PSTPermissionManifest *)manifest
                             pathResolver:(PSTPermissionTargetPathResolver)pathResolver
                                    error:(NSError *_Nullable *_Nullable)error {
  NSMutableArray<PSTPermissionOperation *> *operations = [NSMutableArray array];
  NSMutableArray<PSTPermissionTarget *> *missingTargets = [NSMutableArray array];
  NSMutableArray<PSTPermissionTarget *> *missingRequiredTargets =
      [NSMutableArray array];
  NSMutableArray<PSTPermissionTarget *> *missingOptionalTargets =
      [NSMutableArray array];
  PSTPermissionPlanBridgeContext context = {
      .manifest = manifest,
      .pathResolver = pathResolver,
      .operations = operations,
      .missingTargets = missingTargets,
      .missingRequiredTargets = missingRequiredTargets,
      .missingOptionalTargets = missingOptionalTargets,
  };
  static const PSTPermissionPlanCallbacks callbacks = {
      .target_at = PSTPlanTargetAt,
      .path_for_target = PSTPlanPathForTarget,
      .service_count = PSTPlanServiceCount,
      .service_at = PSTPlanServiceAt,
      .emit_operation = PSTPlanEmitOperation,
      .emit_missing_target = PSTPlanEmitMissingTarget,
  };
  PSTPermissionPlanBuildError buildError = {};
  if (!pst_permission_plan_build(manifest.targets.count, &callbacks, &context,
                                 &buildError)) {
    if (error != nullptr) {
      if (buildError.code == PSTPermissionPlanBuildErrorMissingService) {
        PSTPermissionTarget *target = manifest.targets[buildError.target_index];
        NSString *serviceIdentifier =
            target.serviceIdentifiers[buildError.service_index];
        *error = [NSError
            errorWithDomain:PSTPermissionPlanErrorDomain
                       code:PSTPermissionPlanErrorMissingService
                   userInfo:@{
                     NSLocalizedDescriptionKey :
                         [NSString stringWithFormat:@"%@ refers to missing service %@.",
                                                    target.name, serviceIdentifier]
                   }];
      } else {
        *error = [NSError errorWithDomain:PSTPermissionPlanErrorDomain
                                     code:PSTPermissionPlanErrorMissingService
                                 userInfo:@{
                                   NSLocalizedDescriptionKey :
                                       @"Permission plan callbacks are invalid."
                                 }];
      }
    }
    return nil;
  }

  NSMutableDictionary<NSString *, NSNumber *> *serviceOrder =
      [NSMutableDictionary dictionaryWithCapacity:manifest.services.count];
  [manifest.services enumerateObjectsUsingBlock:^(PSTPermissionService *service,
                                                  NSUInteger index, BOOL *stop) {
    (void)stop;
    serviceOrder[service.identifier] = @(index);
  }];
  NSMutableDictionary<NSString *, NSNumber *> *targetOrder =
      [NSMutableDictionary dictionaryWithCapacity:manifest.targets.count];
  [manifest.targets enumerateObjectsUsingBlock:^(PSTPermissionTarget *target,
                                                 NSUInteger index, BOOL *stop) {
    (void)stop;
    targetOrder[target.inventoryIdentifier] = @(index);
  }];
  [operations sortUsingComparator:^NSComparisonResult(PSTPermissionOperation *left,
                                                      PSTPermissionOperation *right) {
    NSUInteger leftServiceOrder =
        serviceOrder[left.service.identifier].unsignedIntegerValue;
    NSUInteger rightServiceOrder =
        serviceOrder[right.service.identifier].unsignedIntegerValue;
    NSComparisonResult comparison =
        leftServiceOrder < rightServiceOrder
            ? NSOrderedAscending
            : (leftServiceOrder > rightServiceOrder ? NSOrderedDescending
                                                    : NSOrderedSame);
    if (comparison != NSOrderedSame) {
      return comparison;
    }

    NSString *leftDirectory = left.applicationPath.stringByDeletingLastPathComponent;
    NSString *rightDirectory = right.applicationPath.stringByDeletingLastPathComponent;
    comparison = [leftDirectory compare:rightDirectory options:NSLiteralSearch];
    if (comparison != NSOrderedSame) {
      return comparison;
    }
    NSUInteger leftTargetOrder =
        targetOrder[left.target.inventoryIdentifier].unsignedIntegerValue;
    NSUInteger rightTargetOrder =
        targetOrder[right.target.inventoryIdentifier].unsignedIntegerValue;
    return leftTargetOrder < rightTargetOrder
               ? NSOrderedAscending
               : (leftTargetOrder > rightTargetOrder ? NSOrderedDescending
                                                     : NSOrderedSame);
  }];

  return [[self alloc] initWithOperations:operations
                           missingTargets:missingTargets
                   missingRequiredTargets:missingRequiredTargets
                   missingOptionalTargets:missingOptionalTargets];
}

@end
