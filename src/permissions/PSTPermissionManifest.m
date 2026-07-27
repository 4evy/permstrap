#import "permissions/PSTPermissionManifest.h"

#include "permissions/PSTPermissionManifestValidation.h"
#include "permissions/PSTPermissionSelectionCore.h"

#include <stdlib.h>

NSErrorDomain const PSTPermissionManifestErrorDomain = @"dev.4evy.permstrap.manifest";

static_assert((int)PSTPermissionManifestErrorInvalidJSON ==
              (int)PSTPermissionManifestValidationInvalidJSON);
static_assert((int)PSTPermissionManifestErrorUnsupportedVersion ==
              (int)PSTPermissionManifestValidationUnsupportedVersion);
static_assert((int)PSTPermissionManifestErrorInvalidService ==
              (int)PSTPermissionManifestValidationInvalidService);
static_assert((int)PSTPermissionManifestErrorDuplicateService ==
              (int)PSTPermissionManifestValidationDuplicateService);
static_assert((int)PSTPermissionManifestErrorInvalidPermissionSet ==
              (int)PSTPermissionManifestValidationInvalidPermissionSet);
static_assert((int)PSTPermissionManifestErrorUnknownPermissionSet ==
              (int)PSTPermissionManifestValidationUnknownPermissionSet);
static_assert((int)PSTPermissionManifestErrorInvalidTarget ==
              (int)PSTPermissionManifestValidationInvalidTarget);
static_assert((int)PSTPermissionManifestErrorUnknownService ==
              (int)PSTPermissionManifestValidationUnknownService);

static NSError *PSTManifestError(PSTPermissionManifestError code,
                                 NSString *description) {
  return [NSError errorWithDomain:PSTPermissionManifestErrorDomain
                             code:code
                         userInfo:@{NSLocalizedDescriptionKey : description}];
}

static NSError *PSTManifestValidationNSError(
    const PSTPermissionManifestValidationError *validationError,
    NSString *documentName) {
  NSString *path = [NSString stringWithUTF8String:validationError->path];
  NSString *description = [NSString stringWithUTF8String:validationError->description];
  return PSTManifestError(
      (PSTPermissionManifestError)validationError->code,
      [NSString stringWithFormat:@"%@ — %@: %@", documentName,
                                 path != nil ? path : @"<root>",
                                 description != nil
                                     ? description
                                     : @"permission configuration validation failed"]);
}

static BOOL PSTSetManifestError(NSError *_Nullable *_Nullable error,
                                PSTPermissionManifestError code,
                                NSString *description) {
  if (error != nullptr) {
    *error = PSTManifestError(code, description);
  }
  return NO;
}

static NSDictionary<NSString *, id> *_Nullable PSTJSONObject(
    NSData *data, NSError *_Nullable *_Nullable error) {
  id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
  return [object isKindOfClass:NSDictionary.class] ? object : nil;
}

static size_t PSTConfirmationTargetCount(void *rawContext) {
  PSTPermissionManifest *manifest = (__bridge PSTPermissionManifest *)rawContext;
  return manifest.targets.count;
}

static PSTPermissionConfirmationHandle PSTConfirmationTargetAt(size_t index,
                                                               void *rawContext) {
  PSTPermissionManifest *manifest = (__bridge PSTPermissionManifest *)rawContext;
  return (__bridge const void *)manifest.targets[index];
}

static size_t
PSTConfirmationTargetServiceCount(PSTPermissionConfirmationHandle rawTarget,
                                  void *rawContext) {
  (void)rawContext;
  PSTPermissionTarget *target = (__bridge PSTPermissionTarget *)rawTarget;
  return target.serviceIdentifiers.count;
}

static PSTPermissionConfirmationHandle
PSTConfirmationTargetServiceAt(PSTPermissionConfirmationHandle rawTarget, size_t index,
                               void *rawContext) {
  (void)rawContext;
  PSTPermissionTarget *target = (__bridge PSTPermissionTarget *)rawTarget;
  return (__bridge const void *)target.serviceIdentifiers[index];
}

static size_t PSTConfirmationServiceCount(void *rawContext) {
  PSTPermissionManifest *manifest = (__bridge PSTPermissionManifest *)rawContext;
  return manifest.services.count;
}

static PSTPermissionConfirmationHandle PSTConfirmationServiceAt(size_t index,
                                                                void *rawContext) {
  PSTPermissionManifest *manifest = (__bridge PSTPermissionManifest *)rawContext;
  return (__bridge const void *)manifest.services[index].identifier;
}

static bool PSTConfirmationHandlesEqual(PSTPermissionConfirmationHandle lhs,
                                        PSTPermissionConfirmationHandle rhs,
                                        void *rawContext) {
  (void)rawContext;
  return [(__bridge id)lhs isEqual:(__bridge id)rhs];
}

PSTPermissionConfirmationDataSource PSTPermissionManifestConfirmationDataSource(void) {
  return (PSTPermissionConfirmationDataSource){
      .target_count = PSTConfirmationTargetCount,
      .target_at = PSTConfirmationTargetAt,
      .target_service_count = PSTConfirmationTargetServiceCount,
      .target_service_at = PSTConfirmationTargetServiceAt,
      .service_count = PSTConfirmationServiceCount,
      .service_at = PSTConfirmationServiceAt,
      .handles_equal = PSTConfirmationHandlesEqual,
  };
}

@interface PSTPermissionService ()

- (instancetype)initWithIdentifier:(NSString *)identifier
                              name:(NSString *)name
                serviceDescription:(nullable NSString *)serviceDescription
                        symbolName:(NSString *)symbolName
                             route:(NSString *)route
                     requiresAdmin:(BOOL)requiresAdmin
                    modeIdentifier:(NSString *)modeIdentifier
                              mode:(PSTPermissionServiceMode)mode
    NS_DESIGNATED_INITIALIZER;

@end

@implementation PSTPermissionService

- (instancetype)initWithIdentifier:(NSString *)identifier
                              name:(NSString *)name
                serviceDescription:(nullable NSString *)serviceDescription
                        symbolName:(NSString *)symbolName
                             route:(NSString *)route
                     requiresAdmin:(BOOL)requiresAdmin
                    modeIdentifier:(NSString *)modeIdentifier
                              mode:(PSTPermissionServiceMode)mode {
  self = [super init];
  if (self != nil) {
    _identifier = [identifier copy];
    _name = [name copy];
    _serviceDescription = [serviceDescription copy];
    _symbolName = [symbolName copy];
    _route = [route copy];
    _requiresAdmin = requiresAdmin;
    _modeIdentifier = [modeIdentifier copy];
    _mode = mode;
  }
  return self;
}

@end

static BOOL
PSTMaterializeServices(NSArray<NSDictionary<NSString *, id> *> *rawServices,
                       NSArray<PSTPermissionService *> *_Nullable *_Nonnull services,
                       NSDictionary<NSString *, PSTPermissionService *> *_Nullable
                           *_Nonnull servicesByIdentifier,
                       NSError *_Nullable *_Nullable error) {
  NSMutableArray<PSTPermissionService *> *materializedServices =
      [NSMutableArray arrayWithCapacity:rawServices.count];
  NSMutableDictionary<NSString *, PSTPermissionService *> *materializedByIdentifier =
      [NSMutableDictionary dictionaryWithCapacity:rawServices.count];
  for (NSDictionary<NSString *, id> *rawService in rawServices) {
    NSString *modeIdentifier = rawService[@"mode"];
    PSTPermissionServiceMode mode = PSTPermissionServiceModeApplicationList;
    if (!pst_permission_service_mode_parse(modeIdentifier.UTF8String, &mode)) {
      return PSTSetManifestError(error, PSTPermissionManifestErrorInvalidService,
                                 @"Validated service mode could not be materialized.");
    }
    NSString *symbolName = rawService[@"symbol"];
    if (symbolName.length == 0) {
      symbolName = @"checkmark.shield";
    }
    PSTPermissionService *service = [[PSTPermissionService alloc]
        initWithIdentifier:rawService[@"id"]
                      name:rawService[@"name"]
        serviceDescription:rawService[@"description"]
                symbolName:symbolName
                     route:rawService[@"route"]
             requiresAdmin:[rawService[@"requiresAdmin"] boolValue]
            modeIdentifier:modeIdentifier
                      mode:mode];
    [materializedServices addObject:service];
    materializedByIdentifier[service.identifier] = service;
  }
  *services = [materializedServices copy];
  *servicesByIdentifier = [materializedByIdentifier copy];
  return YES;
}

@interface PSTPermissionTarget ()

- (instancetype)initWithInventoryIdentifier:(NSString *)inventoryIdentifier
                                       name:(NSString *)name
                                       kind:(PSTPermissionTargetKind)kind
                          bundleIdentifiers:(NSArray<NSString *> *)bundleIdentifiers
                             pathCandidates:(NSArray<NSString *> *)pathCandidates
                                   required:(BOOL)required
                   permissionSetIdentifiers:
                       (NSArray<NSString *> *)permissionSetIdentifiers
                         serviceIdentifiers:(NSArray<NSString *> *)serviceIdentifiers
    NS_DESIGNATED_INITIALIZER;

@end

@implementation PSTPermissionTarget

- (instancetype)initWithInventoryIdentifier:(NSString *)inventoryIdentifier
                                       name:(NSString *)name
                                       kind:(PSTPermissionTargetKind)kind
                          bundleIdentifiers:(NSArray<NSString *> *)bundleIdentifiers
                             pathCandidates:(NSArray<NSString *> *)pathCandidates
                                   required:(BOOL)required
                   permissionSetIdentifiers:
                       (NSArray<NSString *> *)permissionSetIdentifiers
                         serviceIdentifiers:(NSArray<NSString *> *)serviceIdentifiers {
  self = [super init];
  if (self != nil) {
    _inventoryIdentifier = [inventoryIdentifier copy];
    _name = [name copy];
    _kind = kind;
    _bundleIdentifiers = [bundleIdentifiers copy];
    _bundleIdentifier = [_bundleIdentifiers.firstObject copy];
    _pathCandidates = [pathCandidates copy];
    _required = required;
    _permissionSetIdentifiers = [permissionSetIdentifiers copy];
    _serviceIdentifiers = [serviceIdentifiers copy];
  }
  return self;
}

@end

@interface PSTPermissionManifest ()

- (instancetype)initWithServices:(NSArray<PSTPermissionService *> *)services
                         targets:(NSArray<PSTPermissionTarget *> *)targets
            servicesByIdentifier:
                (NSDictionary<NSString *, PSTPermissionService *> *)servicesByIdentifier
    NS_DESIGNATED_INITIALIZER;

@end

typedef struct {
  PSTPermissionCatalogView view;
  const char **service_identifiers;
  PSTPermissionSetView *permission_sets;
  const char ***permission_set_services;
} PSTCatalogStorage;

typedef struct {
  PSTPermissionSelectionView view;
  const char **permission_sets;
  const char **included_services;
  const char **excluded_services;
} PSTSelectionStorage;

static BOOL PSTCopyUTF8Strings(NSArray<NSString *> *_Nullable strings,
                               const char ***storage, size_t *count) {
  *storage = nullptr;
  *count = strings != nil ? (size_t)strings.count : 0;
  if (*count == 0) {
    return YES;
  }
  const char **items = calloc(*count, sizeof(*items));
  if (items == nullptr) {
    return NO;
  }
  for (size_t index = 0; index < *count; ++index) {
    NSString *string = strings[index];
    items[index] = string.UTF8String;
    if (items[index] == nullptr) {
      free(items);
      return NO;
    }
  }
  *storage = items;
  return YES;
}

static void PSTCatalogStorageDestroy(PSTCatalogStorage *storage) {
  if (storage->permission_set_services != nullptr) {
    for (size_t index = 0; index < storage->view.permission_set_count; ++index) {
      free(storage->permission_set_services[index]);
    }
  }
  free(storage->permission_set_services);
  free(storage->permission_sets);
  free(storage->service_identifiers);
  *storage = (PSTCatalogStorage){};
}

static BOOL PSTCatalogStorageBuild(
    NSDictionary<NSString *, NSArray<NSString *> *> *permissionSets,
    NSDictionary<NSString *, PSTPermissionService *> *servicesByIdentifier,
    PSTCatalogStorage *storage) {
  NSArray<NSString *> *serviceIdentifiers = servicesByIdentifier.allKeys;
  if (!PSTCopyUTF8Strings(serviceIdentifiers, &storage->service_identifiers,
                          &storage->view.service_count)) {
    return NO;
  }
  storage->view.service_identifiers = storage->service_identifiers;

  NSArray<NSString *> *setIdentifiers = permissionSets.allKeys;
  storage->view.permission_set_count = (size_t)setIdentifiers.count;
  if (storage->view.permission_set_count == 0) {
    return YES;
  }
  storage->permission_sets =
      calloc(storage->view.permission_set_count, sizeof(*storage->permission_sets));
  storage->permission_set_services = calloc(storage->view.permission_set_count,
                                            sizeof(*storage->permission_set_services));
  if (storage->permission_sets == nullptr ||
      storage->permission_set_services == nullptr) {
    PSTCatalogStorageDestroy(storage);
    return NO;
  }
  storage->view.permission_sets = storage->permission_sets;

  for (size_t index = 0; index < storage->view.permission_set_count; ++index) {
    NSString *identifier = setIdentifiers[index];
    PSTPermissionSetView *set = &storage->permission_sets[index];
    set->identifier = identifier.UTF8String;
    if (set->identifier == nullptr ||
        !PSTCopyUTF8Strings(permissionSets[identifier],
                            &storage->permission_set_services[index],
                            &set->service_count)) {
      PSTCatalogStorageDestroy(storage);
      return NO;
    }
    set->service_identifiers = storage->permission_set_services[index];
  }
  return YES;
}

static void PSTSelectionStorageDestroy(PSTSelectionStorage *storage) {
  free(storage->permission_sets);
  free(storage->included_services);
  free(storage->excluded_services);
  *storage = (PSTSelectionStorage){};
}

static BOOL PSTSelectionStorageBuild(NSDictionary<NSString *, id> *selection,
                                     PSTSelectionStorage *storage) {
  if (!PSTCopyUTF8Strings(selection[@"sets"], &storage->permission_sets,
                          &storage->view.permission_set_count) ||
      !PSTCopyUTF8Strings(selection[@"include"], &storage->included_services,
                          &storage->view.included_service_count) ||
      !PSTCopyUTF8Strings(selection[@"exclude"], &storage->excluded_services,
                          &storage->view.excluded_service_count)) {
    PSTSelectionStorageDestroy(storage);
    return NO;
  }
  storage->view.permission_set_identifiers = storage->permission_sets;
  storage->view.included_service_identifiers = storage->included_services;
  storage->view.excluded_service_identifiers = storage->excluded_services;
  return YES;
}

static NSArray<NSString *> *_Nullable PSTStringsFromUTF8(const char *const *strings,
                                                         size_t count) {
  NSMutableArray<NSString *> *result = [NSMutableArray arrayWithCapacity:count];
  for (size_t index = 0; index < count; ++index) {
    NSString *string = [NSString stringWithUTF8String:strings[index]];
    if (string == nil) {
      return nil;
    }
    [result addObject:string];
  }
  return result;
}

static NSArray<NSString *> *_Nullable PSTServicesForSelections(
    NSArray<NSDictionary<NSString *, id> *> *selections,
    NSDictionary<NSString *, NSArray<NSString *> *> *permissionSets,
    NSDictionary<NSString *, PSTPermissionService *> *servicesByIdentifier,
    NSString *targetName,
    NSArray<NSString *> *_Nullable *_Nullable selectedPermissionSets,
    NSError *_Nullable *_Nullable error) {
  PSTCatalogStorage catalogStorage = {};
  if (!PSTCatalogStorageBuild(permissionSets, servicesByIdentifier, &catalogStorage)) {
    PSTSetManifestError(error, PSTPermissionManifestErrorInvalidTarget,
                        @"Not enough memory to resolve permission selections.");
    return nil;
  }

  const size_t selectionCount = (size_t)selections.count;
  PSTSelectionStorage *selectionStorage =
      calloc(selectionCount, sizeof(*selectionStorage));
  PSTPermissionSelectionView *selectionViews =
      calloc(selectionCount, sizeof(*selectionViews));
  if (selectionStorage == nullptr || selectionViews == nullptr) {
    free(selectionStorage);
    free(selectionViews);
    PSTCatalogStorageDestroy(&catalogStorage);
    PSTSetManifestError(error, PSTPermissionManifestErrorInvalidTarget,
                        @"Not enough memory to resolve permission selections.");
    return nil;
  }
  BOOL marshaled = YES;
  for (size_t index = 0; index < selectionCount; ++index) {
    if (!PSTSelectionStorageBuild(selections[index], &selectionStorage[index])) {
      marshaled = NO;
      break;
    }
    selectionViews[index] = selectionStorage[index].view;
  }

  PSTPermissionSelectionResult resolved = {};
  PSTPermissionSelectionError selectionError = {};
  BOOL resolutionSucceeded =
      marshaled &&
      pst_permission_selection_resolve(&catalogStorage.view, selectionViews,
                                       selectionCount, &resolved, &selectionError);
  NSArray<NSString *> *serviceIdentifiers = nil;
  NSArray<NSString *> *setIdentifiers = nil;
  if (resolutionSucceeded) {
    serviceIdentifiers =
        PSTStringsFromUTF8(resolved.service_identifiers, resolved.service_count);
    setIdentifiers = PSTStringsFromUTF8(resolved.permission_set_identifiers,
                                        resolved.permission_set_count);
    resolutionSucceeded = serviceIdentifiers != nil && setIdentifiers != nil;
  }

  NSString *invalidIdentifier =
      selectionError.identifier != nullptr
          ? [NSString stringWithUTF8String:selectionError.identifier]
          : nil;
  for (size_t index = 0; index < selectionCount; ++index) {
    PSTSelectionStorageDestroy(&selectionStorage[index]);
  }
  free(selectionStorage);
  free(selectionViews);
  PSTCatalogStorageDestroy(&catalogStorage);
  pst_permission_selection_result_destroy(&resolved);

  if (!resolutionSucceeded) {
    PSTPermissionManifestError code = PSTPermissionManifestErrorInvalidTarget;
    NSString *description = [NSString
        stringWithFormat:@"Target %@ has an invalid permission selection.", targetName];
    if (selectionError.code == PST_PERMISSION_SELECTION_ERROR_UNKNOWN_PERMISSION_SET) {
      code = PSTPermissionManifestErrorUnknownPermissionSet;
      description = [NSString
          stringWithFormat:@"Target %@ refers to unknown permission set %@.",
                           targetName,
                           invalidIdentifier != nil ? invalidIdentifier : @"<invalid>"];
    } else if (selectionError.code == PST_PERMISSION_SELECTION_ERROR_UNKNOWN_SERVICE) {
      code = PSTPermissionManifestErrorUnknownService;
      description = [NSString
          stringWithFormat:@"Target %@ refers to unknown service %@.", targetName,
                           invalidIdentifier != nil ? invalidIdentifier : @"<invalid>"];
    } else if (selectionError.code == PST_PERMISSION_SELECTION_ERROR_EMPTY_RESULT) {
      description =
          [NSString stringWithFormat:@"Target %@ resolves to no permission services.",
                                     targetName];
    }
    PSTSetManifestError(error, code, description);
    return nil;
  }
  if (selectedPermissionSets != nullptr) {
    *selectedPermissionSets = setIdentifiers;
  }
  return serviceIdentifiers;
}

typedef struct PSTConfirmationDescriptionContext {
  __unsafe_unretained PSTPermissionManifest *manifest;
  __unsafe_unretained NSMutableArray<NSString *> *sections;
  __strong NSArray<NSString *> *serviceNames;
  __strong NSMutableArray<NSString *> *targetNames;
  size_t groupTargetCount;
} PSTConfirmationDescriptionContext;

static void
PSTConfirmationDescriptionBeginGroup(PSTPermissionConfirmationHandle rawTarget,
                                     size_t targetCount, void *rawContext) {
  PSTConfirmationDescriptionContext *context = rawContext;
  PSTPermissionTarget *target = (__bridge PSTPermissionTarget *)rawTarget;
  NSMutableArray<NSString *> *serviceNames = [NSMutableArray array];
  for (NSString *identifier in target.serviceIdentifiers) {
    PSTPermissionService *service = [context->manifest serviceForIdentifier:identifier];
    if (service != nil) {
      [serviceNames addObject:service.name];
    }
  }
  context->serviceNames = serviceNames;
  context->targetNames = [NSMutableArray array];
  context->groupTargetCount = targetCount;
}

static void
PSTConfirmationDescriptionEmitTarget(PSTPermissionConfirmationHandle rawTarget,
                                     void *rawContext) {
  PSTConfirmationDescriptionContext *context = rawContext;
  PSTPermissionTarget *target = (__bridge PSTPermissionTarget *)rawTarget;
  [context->targetNames addObject:target.name];
}

static void PSTConfirmationDescriptionEndGroup(void *rawContext) {
  PSTConfirmationDescriptionContext *context = rawContext;
  NSString *scope =
      context->groupTargetCount == context->manifest.targets.count
          ? [NSString stringWithFormat:@"all %lu targets",
                                       (unsigned long)context->manifest.targets.count]
          : [NSString stringWithFormat:@"%zu %@", context->groupTargetCount,
                                       context->groupTargetCount == 1 ? @"target"
                                                                      : @"targets"];
  [context->sections
      addObject:[NSString
                    stringWithFormat:@"Permissions (%lu) — applied to %@\n• %@\n\n"
                                      "Targets (%lu)\n%@",
                                     (unsigned long)context->serviceNames.count, scope,
                                     [context->serviceNames
                                         componentsJoinedByString:@"\n• "],
                                     (unsigned long)context->targetNames.count,
                                     [context->targetNames
                                         componentsJoinedByString:@"  •  "]]];
}

@implementation PSTPermissionManifest

- (instancetype)initWithServices:(NSArray<PSTPermissionService *> *)services
                         targets:(NSArray<PSTPermissionTarget *> *)targets
            servicesByIdentifier:(NSDictionary<NSString *, PSTPermissionService *> *)
                                     servicesByIdentifier {
  self = [super init];
  if (self != nil) {
    _services = [services copy];
    _targets = [targets copy];
    _servicesByIdentifier = [servicesByIdentifier copy];
  }
  return self;
}

+ (nullable instancetype)
    manifestWithPermissionCatalogData:(NSData *)catalogData
                          targetsData:(NSData *)targetsData
                                error:(NSError *_Nullable *_Nullable)error {
  PSTPermissionManifestValidationError validationError = {};
  if (!pst_permission_catalog_validate(catalogData.bytes, catalogData.length,
                                       &validationError)) {
    if (error != nullptr) {
      *error = PSTManifestValidationNSError(&validationError, @"Permission catalog");
    }
    return nil;
  }
  if (!pst_permission_targets_validate(targetsData.bytes, targetsData.length,
                                       &validationError)) {
    if (error != nullptr) {
      *error = PSTManifestValidationNSError(&validationError, @"Permission targets");
    }
    return nil;
  }

  NSError *JSONError = nil;
  NSDictionary<NSString *, id> *catalog = PSTJSONObject(catalogData, &JSONError);
  NSDictionary<NSString *, id> *configuration = PSTJSONObject(targetsData, &JSONError);
  if (catalog == nil || configuration == nil) {
    if (error != nullptr) {
      *error = JSONError != nil
                   ? JSONError
                   : PSTManifestError(
                         PSTPermissionManifestErrorInvalidJSON,
                         @"Validated permission data could not be materialized.");
    }
    return nil;
  }

  NSArray<PSTPermissionService *> *services = nil;
  NSDictionary<NSString *, PSTPermissionService *> *servicesByIdentifier = nil;
  if (!PSTMaterializeServices(catalog[@"services"], &services, &servicesByIdentifier,
                              error)) {
    return nil;
  }

  NSMutableDictionary<NSString *, NSArray<NSString *> *> *permissionSets =
      [NSMutableDictionary dictionary];
  NSDictionary<NSString *, NSDictionary<NSString *, id> *> *rawPermissionSets =
      catalog[@"permissionSets"];
  for (NSString *identifier in rawPermissionSets) {
    permissionSets[identifier] = [rawPermissionSets[identifier][@"services"] copy];
  }

  NSDictionary<NSString *, id> *configuredDefaults = configuration[@"defaults"];
  NSDictionary<NSString *, id> *defaults =
      configuredDefaults != nil ? configuredDefaults : @{};
  NSDictionary<NSString *, id> *defaultPermissions = defaults[@"permissions"];
  BOOL defaultRequired = [defaults[@"required"] boolValue];
  NSMutableArray<PSTPermissionTarget *> *targets = [NSMutableArray array];

  for (NSDictionary<NSString *, id> *rawTarget in configuration[@"targets"]) {
    if (rawTarget[@"enabled"] != nil && ![rawTarget[@"enabled"] boolValue]) {
      continue;
    }
    NSString *name = rawTarget[@"name"];
    NSDictionary<NSString *, id> *targetPermissions = rawTarget[@"permissions"];
    BOOL inheritDefaults = targetPermissions == nil ||
                           targetPermissions[@"inheritDefaults"] == nil ||
                           [targetPermissions[@"inheritDefaults"] boolValue];
    NSMutableArray<NSDictionary<NSString *, id> *> *selections = [NSMutableArray array];
    if (inheritDefaults && defaultPermissions != nil) {
      [selections addObject:defaultPermissions];
    }
    if (targetPermissions != nil) {
      [selections addObject:targetPermissions];
    }
    if (selections.count == 0) {
      PSTSetManifestError(
          error, PSTPermissionManifestErrorInvalidTarget,
          [NSString
              stringWithFormat:@"Target %@ has no permission selection and no default.",
                               name]);
      return nil;
    }
    NSArray<NSString *> *permissionSetIdentifiers = nil;
    NSArray<NSString *> *serviceIdentifiers =
        PSTServicesForSelections(selections, permissionSets, servicesByIdentifier, name,
                                 &permissionSetIdentifiers, error);
    if (serviceIdentifiers == nil) {
      return nil;
    }

    NSString *configuredKindIdentifier = rawTarget[@"kind"];
    const char *defaultKindIdentifier =
        pst_permission_target_kind_identifier(PSTPermissionTargetKindApplicationBundle);
    NSString *kindIdentifier =
        configuredKindIdentifier != nil
            ? configuredKindIdentifier
            : [NSString stringWithUTF8String:defaultKindIdentifier];
    PSTPermissionTargetKind kind = PSTPermissionTargetKindApplicationBundle;
    if (!pst_permission_target_kind_parse(kindIdentifier.UTF8String, &kind)) {
      PSTSetManifestError(error, PSTPermissionManifestErrorInvalidTarget,
                          @"Validated target kind could not be materialized.");
      return nil;
    }
    BOOL required = rawTarget[@"required"] != nil ? [rawTarget[@"required"] boolValue]
                                                  : defaultRequired;
    NSArray<NSString *> *bundleIdentifiers = rawTarget[@"bundleIdentifiers"];
    NSArray<NSString *> *pathCandidates = rawTarget[@"pathCandidates"];
    [targets
        addObject:[[PSTPermissionTarget alloc]
                      initWithInventoryIdentifier:rawTarget[@"id"]
                                             name:name
                                             kind:kind
                                bundleIdentifiers:bundleIdentifiers != nil
                                                      ? bundleIdentifiers
                                                      : @[]
                                   pathCandidates:pathCandidates != nil ? pathCandidates
                                                                        : @[]
                                         required:required
                         permissionSetIdentifiers:permissionSetIdentifiers != nil
                                                      ? permissionSetIdentifiers
                                                      : @[]
                               serviceIdentifiers:serviceIdentifiers]];
  }
  if (targets.count == 0) {
    PSTSetManifestError(error, PSTPermissionManifestErrorInvalidTarget,
                        @"The target file must enable at least one permission target.");
    return nil;
  }
  return [[self alloc] initWithServices:services
                                targets:targets
                   servicesByIdentifier:servicesByIdentifier];
}

+ (nullable instancetype)bundledCatalogWithError:(NSError *_Nullable *_Nullable)error {
  NSURL *catalogURL = [NSBundle.mainBundle URLForResource:@"Permissions"
                                            withExtension:@"json"];
  if (catalogURL == nil) {
    PSTSetManifestError(error, PSTPermissionManifestErrorInvalidJSON,
                        @"The bundled Permissions.json catalog is missing.");
    return nil;
  }
  NSError *readError = nil;
  NSData *catalogData = [NSData dataWithContentsOfURL:catalogURL
                                              options:0
                                                error:&readError];
  if (catalogData == nil) {
    if (error != nullptr) {
      *error = readError;
    }
    return nil;
  }
  PSTPermissionManifestValidationError validationError = {};
  if (!pst_permission_catalog_validate(catalogData.bytes, catalogData.length,
                                       &validationError)) {
    if (error != nullptr) {
      *error = PSTManifestValidationNSError(&validationError, @"Permission catalog");
    }
    return nil;
  }

  NSDictionary<NSString *, id> *catalog = PSTJSONObject(catalogData, &readError);
  if (catalog == nil) {
    if (error != nullptr) {
      *error = readError;
    }
    return nil;
  }
  NSArray<PSTPermissionService *> *services = nil;
  NSDictionary<NSString *, PSTPermissionService *> *servicesByIdentifier = nil;
  if (!PSTMaterializeServices(catalog[@"services"], &services, &servicesByIdentifier,
                              error)) {
    return nil;
  }
  return [[self alloc] initWithServices:services
                                targets:@[]
                   servicesByIdentifier:servicesByIdentifier];
}

+ (nullable NSData *)bundledPermissionCatalogDataWithError:
    (NSError *_Nullable *_Nullable)error {
  NSURL *catalogURL = [NSBundle.mainBundle URLForResource:@"Permissions"
                                            withExtension:@"json"];
  if (catalogURL == nil) {
    PSTSetManifestError(error, PSTPermissionManifestErrorInvalidJSON,
                        @"The bundled Permissions.json catalog is missing.");
    return nil;
  }
  NSError *readError = nil;
  NSData *catalogData = [NSData dataWithContentsOfURL:catalogURL
                                              options:0
                                                error:&readError];
  if (catalogData == nil) {
    if (error != nullptr) {
      *error = readError;
    }
    return nil;
  }
  return catalogData;
}

+ (nullable instancetype)bundledManifestWithTargetsData:(NSData *)targetsData
                                                  error:(NSError *_Nullable *_Nullable)
                                                            error {
  NSData *catalogData = [self bundledPermissionCatalogDataWithError:error];
  if (catalogData == nil) {
    return nil;
  }
  return [self manifestWithPermissionCatalogData:catalogData
                                     targetsData:targetsData
                                           error:error];
}

+ (nullable instancetype)bundledManifestWithTargetsURL:(NSURL *)targetsURL
                                                 error:(NSError *_Nullable *_Nullable)
                                                           error {
  NSError *readError = nil;
  NSData *targetsData = [NSData dataWithContentsOfURL:targetsURL
                                              options:0
                                                error:&readError];
  if (targetsData == nil) {
    if (error != nullptr) {
      *error = readError;
    }
    return nil;
  }
  return [self bundledManifestWithTargetsData:targetsData error:error];
}

- (nullable PSTPermissionService *)serviceForIdentifier:(NSString *)identifier {
  return self.servicesByIdentifier[identifier];
}

- (NSString *)confirmationDescription {
  if (self.targets.count == 0) {
    return @"No permission targets are configured.";
  }

  static const PSTPermissionConfirmationGroupSink sink = {
      .begin_group = PSTConfirmationDescriptionBeginGroup,
      .emit_target = PSTConfirmationDescriptionEmitTarget,
      .end_group = PSTConfirmationDescriptionEndGroup,
  };
  NSMutableArray<NSString *> *sections = [NSMutableArray array];
  PSTConfirmationDescriptionContext context = {
      .manifest = self,
      .sections = sections,
  };
  PSTPermissionConfirmationDataSource source =
      PSTPermissionManifestConfirmationDataSource();
  bool enumerated = pst_permission_confirmation_enumerate_groups(
      &source, (__bridge void *)self, &sink, &context);
  return enumerated ? [sections componentsJoinedByString:@"\n\n"] : @"";
}

@end
