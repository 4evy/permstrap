#import "permissions/PSTPermissionPlan.h"

#include <assert.h>

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    assert(argc == 3);
    NSString *catalogPath = [NSString stringWithUTF8String:argv[1]];
    NSString *targetsPath = [NSString stringWithUTF8String:argv[2]];
    assert(catalogPath != nil);
    assert(targetsPath != nil);
    NSData *catalogData = [NSData dataWithContentsOfFile:catalogPath
                                                 options:0
                                                   error:nil];
    NSData *targetsData = [NSData dataWithContentsOfFile:targetsPath
                                                 options:0
                                                   error:nil];
    assert(catalogData != nil);
    assert(targetsData != nil);

    NSError *error = nil;
    PSTPermissionManifest *manifest =
        [PSTPermissionManifest manifestWithPermissionCatalogData:catalogData
                                                     targetsData:targetsData
                                                           error:&error];
    assert(manifest != nil);
    assert(error == nil);

    NSDictionary<NSString *, NSString *> *resolvedPaths = @{
      @"TextEdit" : @"/System/Applications/TextEdit.app",
      @"Preview" : @"/System/Applications/Preview.app",
      @"Calculator" : @"/System/Applications/Calculator.app",
      @"Grapher" : @"/System/Applications/Utilities/Grapher.app",
      @"Digital Color Meter" :
          @"/System/Applications/Utilities/Digital Color Meter.app",
    };
    PSTPermissionPlan *plan = [PSTPermissionPlan
        planWithManifest:manifest
            pathResolver:^NSString *_Nullable(PSTPermissionTarget *target) {
              return resolvedPaths[target.name];
            }
                   error:&error];
    assert(plan != nil);
    assert(error == nil);
    assert(plan.operations.count == 22);
    assert(plan.missingTargets.count == 9);
    assert(plan.missingRequiredTargets.count == 0);
    assert(plan.missingOptionalTargets.count == 9);
    assert([plan.missingTargets.firstObject.name isEqualToString:@"QuickTime Player"]);

    NSMutableDictionary<NSString *, NSNumber *> *serviceOrder =
        [NSMutableDictionary dictionary];
    [manifest.services enumerateObjectsUsingBlock:^(PSTPermissionService *service,
                                                    NSUInteger index, BOOL *stop) {
      (void)stop;
      serviceOrder[service.identifier] = @(index);
    }];
    NSUInteger previousService = 0;
    NSString *previousDirectory = @"";
    for (NSUInteger index = 0; index < plan.operations.count; ++index) {
      PSTPermissionOperation *operation = plan.operations[index];
      NSUInteger service =
          serviceOrder[operation.service.identifier].unsignedIntegerValue;
      NSString *directory = operation.applicationPath.stringByDeletingLastPathComponent;
      assert(index == 0 || service >= previousService);
      assert(index == 0 || service != previousService ||
             [directory compare:previousDirectory
                        options:NSLiteralSearch] != NSOrderedAscending);
      previousService = service;
      previousDirectory = directory;
    }
    NSArray<NSString *> *accessibilityTargets = [[plan.operations
        filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(
                                                     PSTPermissionOperation *operation,
                                                     NSDictionary *bindings) {
          (void)bindings;
          return [operation.service.identifier isEqualToString:@"accessibility"];
        }]] valueForKeyPath:@"target.name"];
    NSArray<NSString *> *expectedAccessibilityTargets = @[
      @"TextEdit",
      @"Preview",
      @"Calculator",
      @"Grapher",
      @"Digital Color Meter",
    ];
    assert([accessibilityTargets isEqualToArray:expectedAccessibilityTargets]);

    PSTPermissionPlan *missingPlan = [PSTPermissionPlan
        planWithManifest:manifest
            pathResolver:^NSString *_Nullable(PSTPermissionTarget *target) {
              (void)target;
              return nil;
            }
                   error:&error];
    assert(missingPlan != nil);
    assert(missingPlan.operations.count == 0);
    assert(missingPlan.missingTargets.count == 14);
    assert(missingPlan.missingRequiredTargets.count == 1);
    assert([missingPlan.missingRequiredTargets.firstObject.name
        isEqualToString:@"TextEdit"]);
    assert(missingPlan.missingOptionalTargets.count == 13);
  }
  return 0;
}
