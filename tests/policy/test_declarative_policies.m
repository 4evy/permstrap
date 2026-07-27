#import "authorization/PSTAuthorizationPromptPolicy.h"
#import "automation/PSTSystemSettingsUIProfile.h"
#import "policy/PSTRuntimePolicy.h"

#include <assert.h>

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    assert(argc == 2);
    NSString *path = [NSString stringWithUTF8String:argv[1]];
    assert(path != nil);
    NSError *error = nil;
    assert(PSTLoadRuntimePolicy([NSURL fileURLWithPath:path], &error));
    assert(error == nil);

    PSTSystemSettingsUIProfile *settings = PSTCurrentSystemSettingsUIProfile();
    assert([settings.bundleIdentifier isEqualToString:@"com.apple.systempreferences"]);
    assert([[settings privacyPaneURLForRoute:@"Privacy_Accessibility"].absoluteString
        hasSuffix:@"?Privacy_Accessibility"]);
    assert([[settings switchIdentifierForApplicationPath:@"/Applications/Ghostty.app"]
        isEqualToString:@"Ghostty.app_Toggle"]);
    assert([[settings automationRowNameForTargetName:@"Ghostty"]
        isEqualToString:@"Ghostty.app"]);
    NSArray<NSString *> *permissionListRoles = @[ @"AXList", @"AXTable", @"AXOutline" ];
    assert([settings.permissionListRoles isEqualToArray:permissionListRoles]);
    assert(settings.permissionListMinimumWidth == 240.0);
    assert(settings.permissionListMinimumHeight == 80.0);
    assert(settings.permissionListFrameTolerance == 1.0);
    assert(settings.permissionListAncestorLimit == 16);
    assert(settings.dropOffsetFromLeft == 150.0);
    assert(settings.dropOffsetFromTop == 70.0);
    assert(settings.dropEdgeInset == 40.0);
    assert(settings.applicationActivationAttempts == 20);
    assert(settings.workspaceOpenTimeoutInterval == 5.0);
    assert(settings.mainRunLoopPollInterval == 0.01);
    assert(settings.paneWaitNanoseconds > settings.elementWaitNanoseconds);
    assert(settings.applicationActivationPollNanoseconds > 0);
    assert(settings.nativeDragTimeoutInterval == 5.0);
    assert(settings.pollNanoseconds > 0);

    PSTAuthorizationPromptPolicy *authorization = PSTCurrentAuthorizationPromptPolicy();
    NSArray<NSString *> *settingsAuthorizationText = @[
      @"Privacy & Security is trying to modify your system settings.",
      @"Enter your password to allow this."
    ];
    assert([authorization matchesCandidateText:settingsAuthorizationText]);
    assert([authorization matchesExpectedText:settingsAuthorizationText]);
    assert(![authorization
        matchesCandidateText:@[ @"A harmless password-manager window" ]]);
    NSArray<NSString *> *unrelatedAuthorizationText =
        @[ @"An administrator action from a different application", @"Password" ];
    assert(![authorization matchesExpectedText:unrelatedAuthorizationText]);
    assert(authorization.credentialRevealButtonTitles.count == 4);
    assert(authorization.processAgeToleranceNanoseconds > 0);
    assert(authorization.secureFieldAppearanceAttempts > 0);
  }
  return 0;
}
