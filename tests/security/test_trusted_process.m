#import "policy/PSTRuntimePolicy.h"
#import "security/PSTTrustedProcess.h"

#include <assert.h>

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    assert(argc == 2);
    NSString *path = [NSString stringWithUTF8String:argv[1]];
    assert(path != nil);
    NSError *error = nil;
    assert(PSTLoadRuntimePolicy([NSURL fileURLWithPath:path], &error));
    assert(error == nil);

    NSArray<PSTTrustedProcessPolicy *> *policies = PSTTrustedProcessPolicies();
    assert(policies.count == 5);

    NSMutableSet<NSString *> *identifiers = [NSMutableSet set];
    for (PSTTrustedProcessPolicy *policy in policies) {
      assert(policy.bundleIdentifier.length > 0);
      assert(policy.executablePath.absolutePath);
      assert(policy.roles != 0);
      assert(![identifiers containsObject:policy.bundleIdentifier]);
      [identifiers addObject:policy.bundleIdentifier];
    }

    PSTTrustedProcessPolicy *settings =
        PSTTrustedProcessPolicyForBundleIdentifier(@"com.apple.systempreferences");
    assert(settings != nil);
    assert(settings.roles & PSTTrustedProcessRoleAuthorizationObserver);
    assert(settings.roles & PSTTrustedProcessRoleAuthorizationAXHost);
    assert(!(settings.roles & PSTTrustedProcessRoleAuthorizationEventHost));
    assert(settings.requiresFrontmost);
    assert(settings.activePromptRequiresSecureField);
    assert([settings.eventHostBundleIdentifier
        isEqualToString:@"com.apple.LocalAuthenticationRemoteService"]);

    PSTTrustedProcessPolicy *localAuthentication =
        PSTTrustedProcessPolicyForBundleIdentifier(
            @"com.apple.LocalAuthenticationRemoteService");
    assert(localAuthentication != nil);
    assert(localAuthentication.roles & PSTTrustedProcessRoleAuthorizationObserver);
    assert(localAuthentication.roles & PSTTrustedProcessRoleAuthorizationEventHost);
    assert(!(localAuthentication.roles & PSTTrustedProcessRoleAuthorizationAXHost));

    assert(PSTTrustedProcessPolicyForBundleIdentifier(@"invalid.example") == nil);
  }
  return 0;
}
