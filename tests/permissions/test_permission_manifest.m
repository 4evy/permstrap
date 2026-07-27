#import "permissions/PSTPermissionManifest.h"

#include <assert.h>

static NSData *PSTJSONData(NSString *json) {
  NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
  assert(data != nil);
  return data;
}

static id _Nonnull PSTRequired(id _Nullable value) {
  assert(value != nil);
  return (id _Nonnull)value;
}

static NSString *const PSTValidCatalog =
    @"{\"$schema\":\"./Permissions.schema.json\",\"version\":1,"
     "\"services\":["
     "{\"id\":\"accessibility\",\"name\":\"Accessibility\","
     "\"description\":\"Control the desktop\","
     "\"route\":\"Privacy_Accessibility\",\"requiresAdmin\":true,"
     "\"mode\":\"application-list\"},"
     "{\"id\":\"automation\",\"name\":\"Automation\","
     "\"route\":\"Privacy_Automation\",\"requiresAdmin\":false,"
     "\"mode\":\"existing-relationships\"}],"
     "\"permissionSets\":{"
     "\"desktop\":{\"name\":\"Desktop control\","
     "\"services\":[\"accessibility\",\"automation\"]}}}";

static NSString *const PSTValidTargets =
    @"{\"$schema\":\"./PermissionTargets.schema.json\",\"version\":1,"
     "\"defaults\":{\"permissions\":{\"sets\":[\"desktop\"]}},"
     "\"targets\":[{\"id\":\"test:app\",\"name\":\"Test App\","
     "\"bundleIdentifiers\":[\"dev.test.app\"],"
     "\"pathCandidates\":[\"/Applications/Test App.app\"]}]}";

static void PSTAssertFailure(NSString *catalogJSON, NSString *targetsJSON,
                             PSTPermissionManifestError expectedCode) {
  NSError *error = nil;
  PSTPermissionManifest *manifest =
      [PSTPermissionManifest manifestWithPermissionCatalogData:PSTJSONData(catalogJSON)
                                                   targetsData:PSTJSONData(targetsJSON)
                                                         error:&error];
  assert(manifest == nil);
  assert(error.code == expectedCode);
}

static PSTPermissionTarget *PSTTargetNamed(PSTPermissionManifest *manifest,
                                           NSString *name) {
  for (PSTPermissionTarget *target in manifest.targets) {
    if ([target.name isEqualToString:name]) {
      return target;
    }
  }
  return nil;
}

static NSUInteger PSTCountOccurrences(NSString *value, NSString *needle) {
  NSUInteger count = 0;
  NSRange searchRange = NSMakeRange(0, value.length);
  while (searchRange.length > 0) {
    NSRange match = [value rangeOfString:needle options:0 range:searchRange];
    if (match.location == NSNotFound) {
      break;
    }
    count++;
    NSUInteger nextLocation = NSMaxRange(match);
    searchRange = NSMakeRange(nextLocation, value.length - nextLocation);
  }
  return count;
}

static void PSTCollectSelectionReferences(NSDictionary<NSString *, id> *selection,
                                          NSMutableSet<NSString *> *sets,
                                          NSMutableSet<NSString *> *services) {
  for (NSString *identifier in selection[@"sets"] != nil ? selection[@"sets"] : @[]) {
    [sets addObject:identifier];
  }
  for (NSString *key in @[ @"include", @"exclude" ]) {
    NSArray<NSString *> *identifiers = selection[key] != nil ? selection[key] : @[];
    for (NSString *identifier in identifiers) {
      [services addObject:identifier];
    }
  }
}

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    assert(argc == 3);
    NSString *catalogPath = [NSString stringWithUTF8String:argv[1]];
    NSString *targetsPath = [NSString stringWithUTF8String:argv[2]];
    assert(catalogPath != nil);
    assert(targetsPath != nil);

    NSError *error = nil;
    NSData *catalogData = [NSData dataWithContentsOfFile:catalogPath
                                                 options:0
                                                   error:&error];
    NSData *targetsData = [NSData dataWithContentsOfFile:targetsPath
                                                 options:0
                                                   error:&error];
    assert(catalogData != nil);
    assert(targetsData != nil);

    NSDictionary<NSString *, id> *rawCatalog =
        [NSJSONSerialization JSONObjectWithData:catalogData options:0 error:&error];
    NSDictionary<NSString *, id> *rawConfiguration =
        [NSJSONSerialization JSONObjectWithData:targetsData options:0 error:&error];
    assert(rawCatalog != nil);
    assert(rawConfiguration != nil);
    NSArray<NSDictionary<NSString *, id> *> *rawTargets = rawConfiguration[@"targets"];
    assert(rawTargets.count == 15);

    NSArray<NSDictionary<NSString *, id> *> *rawServices =
        PSTRequired(rawCatalog[@"services"]);
    NSMutableSet<NSString *> *catalogServices = [NSMutableSet set];
    for (NSDictionary<NSString *, id> *service in rawServices) {
      NSString *identifier = PSTRequired(service[@"id"]);
      [catalogServices addObject:identifier];
    }
    NSDictionary<NSString *, id> *rawPermissionSets =
        PSTRequired(rawCatalog[@"permissionSets"]);
    NSSet<NSString *> *catalogSets = [NSSet setWithArray:rawPermissionSets.allKeys];
    NSMutableSet<NSString *> *referencedServices = [NSMutableSet set];
    NSMutableSet<NSString *> *referencedSets = [NSMutableSet set];
    NSDictionary<NSString *, id> *rawDefaults =
        PSTRequired(rawConfiguration[@"defaults"]);
    assert([rawDefaults[@"required"] isEqual:@NO]);
    NSDictionary<NSString *, id> *defaultSelection =
        PSTRequired(rawDefaults[@"permissions"]);
    assert(defaultSelection[@"sets"] != nil);
    assert(defaultSelection[@"include"] != nil);
    assert(defaultSelection[@"exclude"] != nil);
    PSTCollectSelectionReferences(defaultSelection, referencedSets, referencedServices);

    BOOL sawDisabled = NO;
    BOOL sawRequired = NO;
    BOOL sawExplicitOptional = NO;
    BOOL sawImplicitKind = NO;
    BOOL sawApplicationKind = NO;
    BOOL sawExecutableKind = NO;
    BOOL sawImplicitPermissions = NO;
    BOOL sawInheritedPermissions = NO;
    BOOL sawReplacementPermissions = NO;
    BOOL sawMultipleSets = NO;
    BOOL sawMultipleBundleIdentifiers = NO;
    BOOL sawMultiplePathCandidates = NO;
    BOOL sawBundleOnlyApplication = NO;
    BOOL sawPathOnlyApplication = NO;
    for (NSDictionary<NSString *, id> *rawTarget in rawTargets) {
      assert([rawTarget[@"id"] hasPrefix:@"macos:"]);
      NSArray<NSString *> *bundleIdentifiers = rawTarget[@"bundleIdentifiers"] != nil
                                                   ? rawTarget[@"bundleIdentifiers"]
                                                   : @[];
      for (NSString *bundleIdentifier in bundleIdentifiers) {
        assert([bundleIdentifier hasPrefix:@"com.apple."]);
      }

      NSArray<NSString *> *pathCandidates =
          rawTarget[@"pathCandidates"] != nil ? rawTarget[@"pathCandidates"] : @[];
      assert(bundleIdentifiers.count > 0 || pathCandidates.count > 0);
      BOOL hasInstalledCandidate = pathCandidates.count == 0;
      for (NSString *path in pathCandidates) {
        assert([path hasPrefix:@"/System/"] || [path hasPrefix:@"/usr/"]);
        BOOL exists = [NSFileManager.defaultManager fileExistsAtPath:path];
        hasInstalledCandidate |= exists;
        if (exists && [path hasSuffix:@".app"]) {
          NSBundle *bundle = PSTRequired([NSBundle bundleWithPath:path]);
          NSString *bundleIdentifier = PSTRequired(bundle.bundleIdentifier);
          assert([bundleIdentifier hasPrefix:@"com.apple."]);
          assert(bundleIdentifiers.count == 0 ||
                 [bundleIdentifiers containsObject:bundleIdentifier]);
        }
      }
      assert(hasInstalledCandidate);

      NSNumber *enabled = rawTarget[@"enabled"];
      sawDisabled |= enabled != nil && !enabled.boolValue;
      NSNumber *required = rawTarget[@"required"];
      sawRequired |= required != nil && required.boolValue;
      sawExplicitOptional |= required != nil && !required.boolValue;

      NSString *kind = rawTarget[@"kind"];
      sawImplicitKind |= kind == nil;
      sawApplicationKind |= [kind isEqualToString:@"application-bundle"];
      sawExecutableKind |= [kind isEqualToString:@"executable"];
      sawMultipleBundleIdentifiers |= bundleIdentifiers.count > 1;
      sawMultiplePathCandidates |= pathCandidates.count > 1;
      BOOL isApplication = kind == nil || [kind isEqualToString:@"application-bundle"];
      sawBundleOnlyApplication |=
          isApplication && bundleIdentifiers.count > 0 && pathCandidates.count == 0;
      sawPathOnlyApplication |=
          isApplication && bundleIdentifiers.count == 0 && pathCandidates.count > 0;

      NSDictionary<NSString *, id> *permissions = rawTarget[@"permissions"];
      sawImplicitPermissions |= permissions == nil;
      if (permissions != nil) {
        NSNumber *inheritDefaults = permissions[@"inheritDefaults"];
        sawInheritedPermissions |= inheritDefaults != nil && inheritDefaults.boolValue;
        sawReplacementPermissions |=
            inheritDefaults != nil && !inheritDefaults.boolValue;
        sawMultipleSets |= [(NSArray<NSString *> *)permissions[@"sets"] count] > 1;
        PSTCollectSelectionReferences(permissions, referencedSets, referencedServices);
      }
    }
    assert(sawDisabled);
    assert(sawRequired);
    assert(sawExplicitOptional);
    assert(sawImplicitKind);
    assert(sawApplicationKind);
    assert(sawExecutableKind);
    assert(sawImplicitPermissions);
    assert(sawInheritedPermissions);
    assert(sawReplacementPermissions);
    assert(sawMultipleSets);
    assert(sawMultipleBundleIdentifiers);
    assert(sawMultiplePathCandidates);
    assert(sawBundleOnlyApplication);
    assert(sawPathOnlyApplication);
    assert([referencedSets isEqualToSet:catalogSets]);
    assert([referencedServices isEqualToSet:catalogServices]);

    PSTPermissionManifest *manifest =
        [PSTPermissionManifest manifestWithPermissionCatalogData:catalogData
                                                     targetsData:targetsData
                                                           error:&error];
    assert(manifest != nil);
    assert(error == nil);
    assert(manifest.services.count == 9);
    assert(manifest.targets.count == 14);

    PSTPermissionService *accessibility =
        [manifest serviceForIdentifier:@"accessibility"];
    assert(accessibility != nil);
    assert(accessibility.mode == PSTPermissionServiceModeApplicationList);
    assert(accessibility.requiresAdmin);
    assert([accessibility.route isEqualToString:@"Privacy_Accessibility"]);
    assert(accessibility.serviceDescription.length > 0);
    assert([accessibility.symbolName isEqualToString:@"accessibility"]);

    PSTPermissionService *automation = [manifest serviceForIdentifier:@"automation"];
    assert(automation != nil);
    assert(automation.mode == PSTPermissionServiceModeExistingRelationships);
    assert(!automation.requiresAdmin);
    assert([automation.symbolName isEqualToString:@"gearshape.2"]);

    PSTPermissionTarget *textEdit = PSTTargetNamed(manifest, @"TextEdit");
    assert(textEdit != nil);
    assert([textEdit.inventoryIdentifier isEqualToString:@"macos:textedit"]);
    assert(textEdit.isRequired);
    assert(
        [textEdit.permissionSetIdentifiers isEqualToArray:@[ @"interactive-control" ]]);
    assert(([textEdit.serviceIdentifiers isEqualToArray:@[
      @"accessibility", @"input-monitoring", @"screen-recording", @"full-disk-access",
      @"bluetooth"
    ]]));

    PSTPermissionTarget *preview = PSTTargetNamed(manifest, @"Preview");
    assert(preview != nil);
    assert(!preview.isRequired);
    assert(([preview.serviceIdentifiers isEqualToArray:@[
      @"accessibility", @"input-monitoring", @"screen-recording", @"full-disk-access",
      @"media-library"
    ]]));

    PSTPermissionTarget *calculator = PSTTargetNamed(manifest, @"Calculator");
    assert([calculator.serviceIdentifiers isEqualToArray:@[ @"accessibility" ]]);
    assert(calculator.permissionSetIdentifiers.count == 0);

    PSTPermissionTarget *music = PSTTargetNamed(manifest, @"Music");
    assert(([music.serviceIdentifiers isEqualToArray:@[
      @"accessibility", @"automation", @"media-library", @"bluetooth"
    ]]));

    PSTPermissionTarget *grapher = PSTTargetNamed(manifest, @"Grapher");
    assert([grapher.permissionSetIdentifiers isEqualToArray:@[ @"developer-tool" ]]);
    assert(([grapher.serviceIdentifiers isEqualToArray:@[
      @"accessibility", @"input-monitoring", @"full-disk-access", @"developer-tools",
      @"app-management", @"screen-recording"
    ]]));

    PSTPermissionTarget *stickies = PSTTargetNamed(manifest, @"Stickies");
    assert(([stickies.permissionSetIdentifiers
        isEqualToArray:@[ @"interactive-control", @"developer-tool" ]]));
    assert(([stickies.serviceIdentifiers isEqualToArray:@[
      @"accessibility", @"screen-recording", @"automation", @"developer-tools",
      @"app-management", @"media-library", @"bluetooth"
    ]]));

    PSTPermissionTarget *screenshot = PSTTargetNamed(manifest, @"Screenshot UI");
    assert(screenshot.kind == PSTPermissionTargetKindApplicationBundle);
    assert(([screenshot.bundleIdentifiers isEqualToArray:@[
      @"com.apple.screenshot.launcher", @"com.apple.screencaptureui"
    ]]));
    assert(screenshot.pathCandidates.count == 2);
    assert(([screenshot.serviceIdentifiers
        isEqualToArray:@[ @"accessibility", @"screen-recording" ]]));

    PSTPermissionTarget *dictionary = PSTTargetNamed(manifest, @"Dictionary");
    assert(
        [dictionary.permissionSetIdentifiers isEqualToArray:@[ @"all-automatable" ]]);
    assert(dictionary.serviceIdentifiers.count == 9);

    PSTPermissionTarget *interpreter =
        PSTTargetNamed(manifest, @"AppleScript Interpreter");
    assert(interpreter.kind == PSTPermissionTargetKindExecutable);
    assert(interpreter.bundleIdentifier == nil);
    assert([interpreter.pathCandidates isEqualToArray:@[ @"/usr/bin/osascript" ]]);
    assert(([interpreter.serviceIdentifiers
        isEqualToArray:@[ @"automation", @"developer-tools" ]]));

    PSTPermissionTarget *voiceMemos = PSTTargetNamed(manifest, @"Voice Memos");
    assert([voiceMemos.bundleIdentifiers isEqualToArray:@[ @"com.apple.VoiceMemos" ]]);
    assert(voiceMemos.pathCandidates.count == 0);
    assert([voiceMemos.serviceIdentifiers isEqualToArray:@[ @"media-library" ]]);

    PSTPermissionTarget *photoBooth = PSTTargetNamed(manifest, @"Photo Booth");
    assert(photoBooth.bundleIdentifiers.count == 0);
    assert([photoBooth.pathCandidates
        isEqualToArray:@[ @"/System/Applications/Photo Booth.app" ]]);
    assert([photoBooth.serviceIdentifiers isEqualToArray:@[ @"bluetooth" ]]);

    NSMutableSet<NSString *> *effectiveServices = [NSMutableSet set];
    NSMutableSet<NSString *> *effectiveMixes = [NSMutableSet set];
    for (PSTPermissionTarget *target in manifest.targets) {
      [effectiveServices addObjectsFromArray:target.serviceIdentifiers];
      [effectiveMixes
          addObject:[target.serviceIdentifiers componentsJoinedByString:@"\x1f"]];
    }
    assert([effectiveServices isEqualToSet:catalogServices]);
    assert(effectiveMixes.count == manifest.targets.count);
    assert(PSTTargetNamed(manifest, @"Chess (disabled example)") == nil);

    assert(PSTCountOccurrences(manifest.confirmationDescription,
                               @"— applied to 1 target") == 14);
    assert(PSTCountOccurrences(manifest.confirmationDescription, @"Targets (1)") == 14);

    PSTPermissionManifest *smallManifest = [PSTPermissionManifest
        manifestWithPermissionCatalogData:PSTJSONData(PSTValidCatalog)
                              targetsData:PSTJSONData(PSTValidTargets)
                                    error:&error];
    assert(smallManifest != nil);
    assert(smallManifest.targets.count == 1);
    assert(smallManifest.targets.firstObject.serviceIdentifiers.count == 2);

    NSString *disabledTarget =
        @"{\"$schema\":\"./PermissionTargets.schema.json\","
         "\"version\":1,\"defaults\":{\"permissions\":{"
         "\"sets\":[\"desktop\"]}},\"targets\":["
         "{\"id\":\"test:disabled\",\"name\":\"Disabled\","
         "\"enabled\":false,\"bundleIdentifiers\":[\"dev.test.disabled\"]},"
         "{\"id\":\"test:enabled\",\"name\":\"Enabled\","
         "\"bundleIdentifiers\":[\"dev.test.enabled\"]}]}";
    PSTPermissionManifest *enabledManifest = [PSTPermissionManifest
        manifestWithPermissionCatalogData:PSTJSONData(PSTValidCatalog)
                              targetsData:PSTJSONData(disabledTarget)
                                    error:&error];
    assert(enabledManifest != nil);
    assert(enabledManifest.targets.count == 1);
    assert([enabledManifest.targets.firstObject.name isEqualToString:@"Enabled"]);

    NSString *unknownSet = @"{\"$schema\":\"./PermissionTargets.schema.json\","
                            "\"version\":1,\"defaults\":{\"permissions\":{"
                            "\"sets\":[\"missing\"]}},\"targets\":[{"
                            "\"id\":\"test:app\",\"name\":\"Test App\","
                            "\"bundleIdentifiers\":[\"dev.test.app\"]}]}";
    PSTAssertFailure(PSTValidCatalog, unknownSet,
                     PSTPermissionManifestErrorUnknownPermissionSet);

    NSString *unknownService = @"{\"$schema\":\"./PermissionTargets.schema.json\","
                                "\"version\":1,\"targets\":[{\"id\":\"test:app\","
                                "\"name\":\"Test App\","
                                "\"bundleIdentifiers\":[\"dev.test.app\"],"
                                "\"permissions\":{\"include\":[\"missing\"]}}]}";
    PSTAssertFailure(PSTValidCatalog, unknownService,
                     PSTPermissionManifestErrorUnknownService);

    NSString *noSelection = @"{\"$schema\":\"./PermissionTargets.schema.json\","
                             "\"version\":1,\"targets\":[{\"id\":\"test:app\","
                             "\"name\":\"Test App\","
                             "\"bundleIdentifiers\":[\"dev.test.app\"]}]}";
    PSTAssertFailure(PSTValidCatalog, noSelection,
                     PSTPermissionManifestErrorInvalidTarget);

    NSString *duplicateService =
        @"{\"$schema\":\"./Permissions.schema.json\","
         "\"version\":1,\"services\":["
         "{\"id\":\"same\",\"name\":\"A\",\"route\":\"A\","
         "\"requiresAdmin\":true,\"mode\":\"application-list\"},"
         "{\"id\":\"same\",\"name\":\"B\",\"route\":\"B\","
         "\"requiresAdmin\":false,\"mode\":\"application-list\"}],"
         "\"permissionSets\":{\"all\":{\"name\":\"All\","
         "\"services\":[\"same\"]}}}";
    PSTAssertFailure(duplicateService, PSTValidTargets,
                     PSTPermissionManifestErrorDuplicateService);
  }
  return 0;
}
