#import "policy/PSTRuntimePolicy.h"

#include <assert.h>

static NSMutableDictionary<NSString *, id> *PSTMutablePolicy(NSData *data) {
  NSError *error = nil;
  id value = [NSJSONSerialization JSONObjectWithData:data
                                             options:NSJSONReadingMutableContainers
                                               error:&error];
  assert(error == nil);
  assert([value isKindOfClass:NSMutableDictionary.class]);
  return value;
}

static NSData *PSTPolicyData(NSDictionary<NSString *, id> *policy) {
  NSError *error = nil;
  NSData *data = [NSJSONSerialization dataWithJSONObject:policy options:0 error:&error];
  assert(data != nil);
  assert(error == nil);
  return data;
}

static void PSTAssertPolicyFailure(NSDictionary<NSString *, id> *policy,
                                   PSTRuntimePolicyError expectedCode,
                                   NSString *expectedPath) {
  NSError *error = nil;
  PSTRuntimePolicy *parsed = [PSTRuntimePolicy policyWithData:PSTPolicyData(policy)
                                                        error:&error];
  assert(parsed == nil);
  assert([error.domain isEqualToString:PSTRuntimePolicyErrorDomain]);
  assert(error.code == expectedCode);
  assert([error.localizedDescription containsString:expectedPath]);
}

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    assert(argc == 2);
    NSString *path = [NSString stringWithUTF8String:argv[1]];
    assert(path != nil);
    NSURL *URL = [NSURL fileURLWithPath:path];
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfURL:URL options:0 error:&error];
    assert(data != nil);
    assert(error == nil);

    PSTRuntimePolicy *policy = [PSTRuntimePolicy policyWithData:data error:&error];
    assert(policy != nil);
    assert(error == nil);
    assert(policy.authorizationPrompt.count == 4);
    assert(policy.systemSettings.count == 10);
    assert(policy.trustedProcesses.count == 5);

    NSData *malformed = [@"{" dataUsingEncoding:NSUTF8StringEncoding];
    assert(malformed != nil);
    assert([PSTRuntimePolicy policyWithData:malformed error:&error] == nil);
    assert(error != nil);

    NSMutableDictionary<NSString *, id> *unknownRoot = PSTMutablePolicy(data);
    unknownRoot[@"unexpected"] = @YES;
    PSTAssertPolicyFailure(unknownRoot, PSTRuntimePolicyErrorInvalidJSON, @"<root>");

    NSMutableDictionary<NSString *, id> *unsupported = PSTMutablePolicy(data);
    unsupported[@"version"] = @2;
    PSTAssertPolicyFailure(unsupported, PSTRuntimePolicyErrorUnsupportedVersion,
                           @"version");

    NSMutableDictionary<NSString *, id> *invalidPrompt = PSTMutablePolicy(data);
    NSMutableDictionary<NSString *, id> *candidateText =
        invalidPrompt[@"authorizationPrompt"][@"candidateText"];
    candidateText[@"required"] = @[];
    PSTAssertPolicyFailure(invalidPrompt,
                           PSTRuntimePolicyErrorInvalidAuthorizationPrompt,
                           @"authorizationPrompt/candidateText/required");

    NSMutableDictionary<NSString *, id> *invalidInteraction = PSTMutablePolicy(data);
    invalidInteraction[@"systemSettings"][@"interaction"]
                      [@"permissionListMinimumWidth"] = @0;
    PSTAssertPolicyFailure(invalidInteraction,
                           PSTRuntimePolicyErrorInvalidSystemSettings,
                           @"systemSettings/interaction/permissionListMinimumWidth");

    NSMutableDictionary<NSString *, id> *invalidPath = PSTMutablePolicy(data);
    NSMutableDictionary<NSString *, id> *firstProcess =
        invalidPath[@"trustedProcesses"][0];
    firstProcess[@"executablePath"] = @"/System/../tmp/fake";
    PSTAssertPolicyFailure(invalidPath, PSTRuntimePolicyErrorInvalidTrustedProcess,
                           @"trustedProcesses/0/executablePath");

    NSMutableDictionary<NSString *, id> *invalidRole = PSTMutablePolicy(data);
    invalidRole[@"trustedProcesses"][0][@"roles"] = @[ @"password-receiver" ];
    PSTAssertPolicyFailure(invalidRole, PSTRuntimePolicyErrorInvalidTrustedProcess,
                           @"trustedProcesses/0/roles");

    NSMutableDictionary<NSString *, id> *duplicateProcess = PSTMutablePolicy(data);
    NSMutableArray<NSMutableDictionary<NSString *, id> *> *processes =
        duplicateProcess[@"trustedProcesses"];
    NSMutableDictionary<NSString *, id> *secondProcess = processes[1];
    secondProcess[@"bundleIdentifier"] = processes[0][@"bundleIdentifier"];
    PSTAssertPolicyFailure(duplicateProcess,
                           PSTRuntimePolicyErrorDuplicateTrustedProcess,
                           @"trustedProcesses");

    NSMutableDictionary<NSString *, id> *invalidRelationship = PSTMutablePolicy(data);
    invalidRelationship[@"systemSettings"][@"bundleIdentifier"] =
        @"com.example.missing";
    PSTAssertPolicyFailure(invalidRelationship,
                           PSTRuntimePolicyErrorInvalidRelationship,
                           @"systemSettings/bundleIdentifier");

    NSMutableDictionary<NSString *, id> *missingEventHost = PSTMutablePolicy(data);
    missingEventHost[@"trustedProcesses"][4][@"eventHostBundleIdentifier"] =
        @"com.example.missing";
    PSTAssertPolicyFailure(missingEventHost, PSTRuntimePolicyErrorInvalidRelationship,
                           @"trustedProcesses/4/eventHostBundleIdentifier");

    NSMutableDictionary<NSString *, id> *invalidSecureField = PSTMutablePolicy(data);
    invalidSecureField[@"trustedProcesses"][3][@"activePromptRequiresSecureField"] =
        @YES;
    PSTAssertPolicyFailure(invalidSecureField, PSTRuntimePolicyErrorInvalidRelationship,
                           @"trustedProcesses/3/activePromptRequiresSecureField");

    error = nil;
    assert(PSTLoadRuntimePolicy(URL, &error));
    assert(error == nil);
    assert(PSTCurrentRuntimePolicy().trustedProcesses.count == 5);
    assert(!PSTLoadRuntimePolicy(URL, &error));
    assert(error.code == PSTRuntimePolicyErrorAlreadyLoaded);
  }
  return 0;
}
