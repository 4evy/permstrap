#import "application/PSTPermissionTargetsDocument.h"

NSErrorDomain const PSTPermissionTargetsDocumentErrorDomain =
    @"dev.4evy.permstrap.targets-document";

NSString *const PSTPermissionTargetsFilename = @"PermissionTargets.json";
static NSString *const PSTTargetsSchemaPath = @"./PermissionTargets.schema.json";
static NSString *const PSTTargetsSchemaKey = @"$schema";
static NSString *const PSTTargetsVersionKey = @"version";
static NSString *const PSTTargetsItemsKey = @"targets";
static NSString *const PSTTargetIdentifierKey = @"id";
static NSString *const PSTTargetNameKey = @"name";
static NSString *const PSTTargetRequiredKey = @"required";
static NSString *const PSTTargetKindKey = @"kind";
static NSString *const PSTTargetBundleIdentifiersKey = @"bundleIdentifiers";
static NSString *const PSTTargetPathCandidatesKey = @"pathCandidates";
static NSString *const PSTTargetPermissionsKey = @"permissions";
static NSString *const PSTTargetInheritDefaultsKey = @"inheritDefaults";
static NSString *const PSTTargetIncludedPermissionsKey = @"include";
constexpr uint8_t PSTTargetsDocumentTerminator = '\n';

@implementation PSTPermissionTargetDraft

- (instancetype)initWithIdentifier:(NSString *)identifier
                              name:(NSString *)name
                              kind:(PSTPermissionTargetKind)kind
                 bundleIdentifiers:(NSArray<NSString *> *)bundleIdentifiers
                    pathCandidates:(NSArray<NSString *> *)pathCandidates
                          required:(BOOL)required
                serviceIdentifiers:(NSArray<NSString *> *)serviceIdentifiers {
  self = [super init];
  if (self != nil) {
    _identifier = [identifier copy];
    _name = [name copy];
    _kind = kind;
    _bundleIdentifiers = [bundleIdentifiers copy];
    _pathCandidates = [pathCandidates copy];
    _required = required;
    _serviceIdentifiers = [serviceIdentifiers copy];
  }
  return self;
}

@end

@interface PSTPermissionTargetsStore ()

@property(nonatomic, copy) NSURL *directoryURL;

@end

@implementation PSTPermissionTargetsStore

- (instancetype)init {
  NSURL *applicationSupportURL =
      [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory
                                           inDomains:NSUserDomainMask]
          .firstObject;
  NSString *directoryName = NSBundle.mainBundle.bundleIdentifier.length > 0
                                ? NSBundle.mainBundle.bundleIdentifier
                                : @"dev.4evy.permstrap";
  NSURL *directoryURL = [applicationSupportURL URLByAppendingPathComponent:directoryName
                                                               isDirectory:YES];
  return [self initWithDirectoryURL:directoryURL];
}

- (instancetype)initWithDirectoryURL:(NSURL *)directoryURL {
  self = [super init];
  if (self != nil) {
    _directoryURL = [directoryURL copy];
    NSURL *targetsURL =
        [directoryURL URLByAppendingPathComponent:PSTPermissionTargetsFilename
                                      isDirectory:NO];
    if (targetsURL == nil) {
      return nil;
    }
    _targetsURL = targetsURL;
  }
  return self;
}

- (nullable NSURL *)existingTargetsURL {
  NSNumber *regularFile = nil;
  NSError *error = nil;
  if (![self.targetsURL getResourceValue:&regularFile
                                  forKey:NSURLIsRegularFileKey
                                   error:&error] ||
      !regularFile.boolValue) {
    return nil;
  }
  return self.targetsURL;
}

- (BOOL)saveTargetsData:(NSData *)data error:(NSError *_Nullable *_Nullable)error {
  NSFileManager *fileManager = NSFileManager.defaultManager;
  if (![fileManager createDirectoryAtURL:self.directoryURL
             withIntermediateDirectories:YES
                              attributes:@{NSFilePosixPermissions : @0700}
                                   error:error]) {
    return NO;
  }
  return [data writeToURL:self.targetsURL options:NSDataWritingAtomic error:error];
}

@end

@implementation PSTPermissionTargetsDocument

static NSError *PSTTargetsDocumentError(PSTPermissionTargetsDocumentError code,
                                        NSString *description) {
  return [NSError errorWithDomain:PSTPermissionTargetsDocumentErrorDomain
                             code:code
                         userInfo:@{NSLocalizedDescriptionKey : description}];
}

static BOOL PSTSetTargetsDocumentError(NSError *_Nullable *_Nullable error,
                                       PSTPermissionTargetsDocumentError code,
                                       NSString *description) {
  if (error != nullptr) {
    *error = PSTTargetsDocumentError(code, description);
  }
  return NO;
}

static BOOL PSTStringIsNonempty(NSString *value) {
  return [value stringByTrimmingCharactersInSet:NSCharacterSet
                                                    .whitespaceAndNewlineCharacterSet]
             .length > 0;
}

static BOOL PSTIdentifierIsValid(NSString *identifier) {
  if (identifier.length == 0) {
    return NO;
  }
  NSCharacterSet *initialCharacters = NSCharacterSet.alphanumericCharacterSet;
  if (![initialCharacters characterIsMember:[identifier characterAtIndex:0]]) {
    return NO;
  }
  NSCharacterSet *allowedCharacters =
      [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                                                          "abcdefghijklmnopqrstuvwxyz"
                                                          "0123456789._:-"];
  return [identifier rangeOfCharacterFromSet:allowedCharacters.invertedSet].location ==
         NSNotFound;
}

static BOOL PSTStringArrayIsValid(NSArray<NSString *> *values) {
  if (values.count == 0) {
    return NO;
  }
  NSMutableSet<NSString *> *uniqueValues = [NSMutableSet set];
  for (id value in values) {
    if (![value isKindOfClass:NSString.class] || !PSTStringIsNonempty(value) ||
        [uniqueValues containsObject:value]) {
      return NO;
    }
    [uniqueValues addObject:value];
  }
  return YES;
}

static BOOL PSTValidateTarget(PSTPermissionTargetDraft *target, NSUInteger index,
                              NSSet<NSString *> *allowedServiceIdentifiers,
                              NSMutableSet<NSString *> *usedIdentifiers,
                              NSError *_Nullable *_Nullable error) {
  NSString *targetLabel =
      [NSString stringWithFormat:@"Target %lu", (unsigned long)(index + 1)];
  if (!PSTIdentifierIsValid(target.identifier)) {
    return PSTSetTargetsDocumentError(
        error, PSTPermissionTargetsDocumentErrorInvalidTarget,
        [NSString stringWithFormat:
                      @"%@ needs an identifier containing only letters, numbers, "
                      @"periods, underscores, colons, or hyphens.",
                      targetLabel]);
  }
  if ([usedIdentifiers containsObject:target.identifier]) {
    return PSTSetTargetsDocumentError(
        error, PSTPermissionTargetsDocumentErrorDuplicateIdentifier,
        [NSString stringWithFormat:@"The identifier “%@” is used more than once.",
                                   target.identifier]);
  }
  [usedIdentifiers addObject:target.identifier];
  if (!PSTStringIsNonempty(target.name)) {
    return PSTSetTargetsDocumentError(
        error, PSTPermissionTargetsDocumentErrorInvalidTarget,
        [NSString stringWithFormat:@"%@ needs a display name.", targetLabel]);
  }

  BOOL bundleIdentifiersValid = target.bundleIdentifiers.count == 0 ||
                                PSTStringArrayIsValid(target.bundleIdentifiers);
  BOOL pathCandidatesValid =
      target.pathCandidates.count == 0 || PSTStringArrayIsValid(target.pathCandidates);
  if (!bundleIdentifiersValid || !pathCandidatesValid) {
    return PSTSetTargetsDocumentError(
        error, PSTPermissionTargetsDocumentErrorInvalidTarget,
        [NSString stringWithFormat:@"%@ contains an empty or duplicate source value.",
                                   target.name]);
  }

  switch (target.kind) {
  case PSTPermissionTargetKindApplicationBundle:
    if (target.bundleIdentifiers.count == 0 && target.pathCandidates.count == 0) {
      return PSTSetTargetsDocumentError(
          error, PSTPermissionTargetsDocumentErrorInvalidTarget,
          [NSString stringWithFormat:@"%@ needs an application bundle or path.",
                                     target.name]);
    }
    break;
  case PSTPermissionTargetKindExecutable:
    if (target.pathCandidates.count == 0 || target.bundleIdentifiers.count != 0) {
      return PSTSetTargetsDocumentError(
          error, PSTPermissionTargetsDocumentErrorInvalidTarget,
          [NSString stringWithFormat:@"%@ needs an executable path.", target.name]);
    }
    break;
  }

  if (!PSTStringArrayIsValid(target.serviceIdentifiers)) {
    return PSTSetTargetsDocumentError(
        error, PSTPermissionTargetsDocumentErrorInvalidPermission,
        [NSString stringWithFormat:@"%@ needs at least one permission.", target.name]);
  }
  for (NSString *serviceIdentifier in target.serviceIdentifiers) {
    if (![allowedServiceIdentifiers containsObject:serviceIdentifier]) {
      return PSTSetTargetsDocumentError(
          error, PSTPermissionTargetsDocumentErrorInvalidPermission,
          [NSString stringWithFormat:@"%@ refers to the unknown permission “%@”.",
                                     target.name, serviceIdentifier]);
    }
  }
  return YES;
}

+ (nullable NSData *)dataWithTargets:(NSArray<PSTPermissionTargetDraft *> *)targets
           allowedServiceIdentifiers:(NSSet<NSString *> *)allowedServiceIdentifiers
                               error:(NSError *_Nullable *_Nullable)error {
  if (targets.count == 0) {
    PSTSetTargetsDocumentError(error, PSTPermissionTargetsDocumentErrorNoTargets,
                               @"Add at least one application or executable.");
    return nil;
  }

  NSMutableSet<NSString *> *usedIdentifiers = [NSMutableSet set];
  NSMutableArray<NSDictionary<NSString *, id> *> *serializedTargets =
      [NSMutableArray arrayWithCapacity:targets.count];
  NSUInteger index = 0;
  for (PSTPermissionTargetDraft *target in targets) {
    if (!PSTValidateTarget(target, index, allowedServiceIdentifiers, usedIdentifiers,
                           error)) {
      return nil;
    }
    NSMutableDictionary<NSString *, id> *serializedTarget =
        [NSMutableDictionary dictionaryWithDictionary:@{
          PSTTargetIdentifierKey : target.identifier,
          PSTTargetNameKey : target.name,
          PSTTargetRequiredKey : @(target.isRequired),
          PSTTargetPermissionsKey : @{
            PSTTargetInheritDefaultsKey : @NO,
            PSTTargetIncludedPermissionsKey : target.serviceIdentifiers,
          },
        }];
    const char *kindIdentifier = pst_permission_target_kind_identifier(target.kind);
    if (kindIdentifier == nullptr) {
      PSTSetTargetsDocumentError(
          error, PSTPermissionTargetsDocumentErrorInvalidTarget,
          [NSString
              stringWithFormat:@"%@ has an unsupported target kind.", target.name]);
      return nil;
    }
    serializedTarget[PSTTargetKindKey] = [NSString stringWithUTF8String:kindIdentifier];
    switch (target.kind) {
    case PSTPermissionTargetKindApplicationBundle:
      if (target.bundleIdentifiers.count > 0) {
        serializedTarget[PSTTargetBundleIdentifiersKey] = target.bundleIdentifiers;
      }
      if (target.pathCandidates.count > 0) {
        serializedTarget[PSTTargetPathCandidatesKey] = target.pathCandidates;
      }
      break;
    case PSTPermissionTargetKindExecutable:
      serializedTarget[PSTTargetPathCandidatesKey] = target.pathCandidates;
      break;
    }
    [serializedTargets addObject:serializedTarget];
    index++;
  }

  NSDictionary<NSString *, id> *root = @{
    PSTTargetsSchemaKey : PSTTargetsSchemaPath,
    PSTTargetsVersionKey : @(PST_PERMISSION_MANIFEST_VERSION),
    PSTTargetsItemsKey : serializedTargets,
  };
  NSError *serializationError = nil;
  NSData *data = [NSJSONSerialization
      dataWithJSONObject:root
                 options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys |
                         NSJSONWritingWithoutEscapingSlashes
                   error:&serializationError];
  if (data == nil) {
    if (error != nullptr) {
      *error = serializationError != nil
                   ? serializationError
                   : PSTTargetsDocumentError(
                         PSTPermissionTargetsDocumentErrorSerialization,
                         @"The target configuration could not be encoded as JSON.");
    }
    return nil;
  }

  NSMutableData *terminatedData = [data mutableCopy];
  [terminatedData appendBytes:&PSTTargetsDocumentTerminator
                       length:sizeof(PSTTargetsDocumentTerminator)];
  return terminatedData;
}

@end
