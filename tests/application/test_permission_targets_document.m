#import "application/PSTPermissionTargetsDocument.h"
#import "permissions/PSTPermissionManifest.h"

#include <assert.h>

static id _Nonnull PSTRequired(id _Nullable value) {
  assert(value != nil);
  return (id _Nonnull)value;
}

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    assert(argc == 2);
    NSString *catalogPath = [NSString stringWithUTF8String:argv[1]];
    assert(catalogPath != nil);
    NSData *catalogData = [NSData dataWithContentsOfFile:catalogPath];
    assert(catalogData != nil);

    NSSet<NSString *> *allowedServices =
        [NSSet setWithArray:@[ @"accessibility", @"screen-recording", @"automation" ]];
    PSTPermissionTargetDraft *application = [[PSTPermissionTargetDraft alloc]
        initWithIdentifier:@"app:dev.test.editor"
                      name:@"Test Editor"
                      kind:PSTPermissionTargetKindApplicationBundle
         bundleIdentifiers:@[ @"dev.test.editor" ]
            pathCandidates:@[ @"/Applications/Test Editor.app" ]
                  required:YES
        serviceIdentifiers:@[ @"accessibility", @"screen-recording" ]];
    PSTPermissionTargetDraft *executable = [[PSTPermissionTargetDraft alloc]
        initWithIdentifier:@"tool:test-runner"
                      name:@"Test Runner"
                      kind:PSTPermissionTargetKindExecutable
         bundleIdentifiers:@[]
            pathCandidates:@[ @"/usr/bin/true" ]
                  required:NO
        serviceIdentifiers:@[ @"automation" ]];

    NSError *error = nil;
    NSData *targetsData =
        [PSTPermissionTargetsDocument dataWithTargets:@[ application, executable ]
                            allowedServiceIdentifiers:allowedServices
                                                error:&error];
    assert(targetsData != nil);
    assert(error == nil);
    const uint8_t *bytes = targetsData.bytes;
    assert(targetsData.length > 0);
    assert(bytes[targetsData.length - 1] == '\n');

    NSDictionary<NSString *, id> *root =
        [NSJSONSerialization JSONObjectWithData:targetsData options:0 error:&error];
    assert(root != nil);
    assert([root[@"$schema"] isEqual:@"./PermissionTargets.schema.json"]);
    assert([root[@"version"] isEqual:@1]);
    NSArray<NSDictionary<NSString *, id> *> *targets = PSTRequired(root[@"targets"]);
    assert(targets.count == 2);
    NSDictionary<NSString *, id> *rawApplication = targets[0];
    assert([rawApplication[@"kind"] isEqual:@"application-bundle"]);
    assert([rawApplication[@"required"] isEqual:@YES]);
    NSDictionary<NSString *, id> *applicationPermissions =
        PSTRequired(rawApplication[@"permissions"]);
    assert([applicationPermissions[@"inheritDefaults"] isEqual:@NO]);
    assert(([applicationPermissions[@"include"]
        isEqual:@[ @"accessibility", @"screen-recording" ]]));
    NSDictionary<NSString *, id> *rawExecutable = targets[1];
    assert([rawExecutable[@"kind"] isEqual:@"executable"]);
    assert(rawExecutable[@"bundleIdentifiers"] == nil);

    PSTPermissionManifest *manifest =
        [PSTPermissionManifest manifestWithPermissionCatalogData:catalogData
                                                     targetsData:targetsData
                                                           error:&error];
    assert(manifest != nil);
    assert(error == nil);
    assert(manifest.targets.count == 2);
    assert(manifest.services.count == 9);

    NSURL *temporaryRoot = [NSURL
        fileURLWithPath:[NSTemporaryDirectory()
                            stringByAppendingPathComponent:NSUUID.UUID.UUIDString]
            isDirectory:YES];
    NSURL *storeDirectory =
        [temporaryRoot URLByAppendingPathComponent:@"Application Support"
                                       isDirectory:YES];
    PSTPermissionTargetsStore *store =
        [[PSTPermissionTargetsStore alloc] initWithDirectoryURL:storeDirectory];
    assert(
        [store.targetsURL.lastPathComponent isEqualToString:@"PermissionTargets.json"]);
    assert([store existingTargetsURL] == nil);
    error = nil;
    assert([store saveTargetsData:targetsData error:&error]);
    assert(error == nil);
    assert([[store existingTargetsURL] isEqual:store.targetsURL]);
    NSData *storedData = [NSData dataWithContentsOfURL:store.targetsURL];
    assert([storedData isEqual:targetsData]);
    PSTPermissionTargetsStore *reopenedStore =
        [[PSTPermissionTargetsStore alloc] initWithDirectoryURL:storeDirectory];
    assert([[reopenedStore existingTargetsURL] isEqual:store.targetsURL]);
    error = nil;
    assert([NSFileManager.defaultManager removeItemAtURL:temporaryRoot error:&error]);
    assert(error == nil);

    error = nil;
    NSData *empty = [PSTPermissionTargetsDocument dataWithTargets:@[]
                                        allowedServiceIdentifiers:allowedServices
                                                            error:&error];
    assert(empty == nil);
    assert(error.code == PSTPermissionTargetsDocumentErrorNoTargets);

    error = nil;
    NSData *duplicate =
        [PSTPermissionTargetsDocument dataWithTargets:@[ application, application ]
                            allowedServiceIdentifiers:allowedServices
                                                error:&error];
    assert(duplicate == nil);
    assert(error.code == PSTPermissionTargetsDocumentErrorDuplicateIdentifier);

    PSTPermissionTargetDraft *unknownPermission = [[PSTPermissionTargetDraft alloc]
        initWithIdentifier:@"app:unknown"
                      name:@"Unknown"
                      kind:PSTPermissionTargetKindApplicationBundle
         bundleIdentifiers:@[ @"dev.test.unknown" ]
            pathCandidates:@[]
                  required:NO
        serviceIdentifiers:@[ @"not-in-catalog" ]];
    error = nil;
    NSData *unknown =
        [PSTPermissionTargetsDocument dataWithTargets:@[ unknownPermission ]
                            allowedServiceIdentifiers:allowedServices
                                                error:&error];
    assert(unknown == nil);
    assert(error.code == PSTPermissionTargetsDocumentErrorInvalidPermission);
  }
  return 0;
}
