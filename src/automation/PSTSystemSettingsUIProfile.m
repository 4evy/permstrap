#import "automation/PSTSystemSettingsUIProfile.h"

#import "policy/PSTRuntimePolicy.h"

#include "core/PSTTime.h"

@interface PSTSystemSettingsUIProfile ()

- (instancetype)initWithConfiguration:(NSDictionary<NSString *, id> *)configuration
    NS_DESIGNATED_INITIALIZER;

@end

static uint64_t PSTMillisecondsToNanoseconds(NSNumber *milliseconds) {
  return milliseconds.unsignedLongLongValue * PST_NANOSECONDS_PER_MILLISECOND;
}

static NSTimeInterval PSTMillisecondsToTimeInterval(NSNumber *milliseconds) {
  return milliseconds.doubleValue / (NSTimeInterval)PST_MILLISECONDS_PER_SECOND;
}

static id _Nonnull PSTRequiredConfigurationValue(
    NSDictionary<NSString *, id> *configuration, NSString *key) {
  id value = configuration[key];
  if (value == nil) {
    [NSException raise:NSInvalidArgumentException
                format:@"Validated runtime policy is missing %@", key];
  }
  return value;
}

@implementation PSTSystemSettingsUIProfile

- (instancetype)initWithConfiguration:(NSDictionary<NSString *, id> *)configuration {
  self = [super init];
  if (self != nil) {
    NSDictionary<NSString *, id> *interaction =
        PSTRequiredConfigurationValue(configuration, @"interaction");
    NSDictionary<NSString *, NSNumber *> *timing =
        PSTRequiredConfigurationValue(configuration, @"timing");

    _bundleIdentifier =
        [PSTRequiredConfigurationValue(configuration, @"bundleIdentifier") copy];
    _privacyPaneURLPrefix =
        [PSTRequiredConfigurationValue(configuration, @"privacyPaneURLPrefix") copy];
    _accessibilityBootstrapRoute =
        [PSTRequiredConfigurationValue(configuration, @"accessibilityBootstrapRoute")
            copy];
    _restartLaterButtonTitle =
        [PSTRequiredConfigurationValue(configuration, @"restartLaterButtonTitle") copy];
    _applicationSwitchSuffix =
        [PSTRequiredConfigurationValue(configuration, @"applicationSwitchSuffix") copy];
    _automationRowSuffix =
        [PSTRequiredConfigurationValue(configuration, @"automationRowSuffix") copy];
    _automationToggleRole =
        [PSTRequiredConfigurationValue(configuration, @"automationToggleRole") copy];
    _automationDisclosureRole =
        [PSTRequiredConfigurationValue(configuration, @"automationDisclosureRole")
            copy];
    _permissionListRoles =
        [PSTRequiredConfigurationValue(interaction, @"permissionListRoles") copy];
    _permissionListMinimumWidth =
        [PSTRequiredConfigurationValue(interaction, @"permissionListMinimumWidth")
            doubleValue];
    _permissionListMinimumHeight =
        [PSTRequiredConfigurationValue(interaction, @"permissionListMinimumHeight")
            doubleValue];
    _permissionListFrameTolerance =
        [PSTRequiredConfigurationValue(interaction, @"permissionListFrameTolerance")
            doubleValue];
    _permissionListAncestorLimit =
        [PSTRequiredConfigurationValue(interaction, @"permissionListAncestorLimit")
            unsignedIntegerValue];
    _dropOffsetFromLeft =
        [PSTRequiredConfigurationValue(interaction, @"dropOffsetFromLeft") doubleValue];
    _dropOffsetFromTop =
        [PSTRequiredConfigurationValue(interaction, @"dropOffsetFromTop") doubleValue];
    _dropEdgeInset =
        [PSTRequiredConfigurationValue(interaction, @"dropEdgeInset") doubleValue];
    _applicationActivationAttempts =
        [PSTRequiredConfigurationValue(interaction, @"applicationActivationAttempts")
            unsignedIntegerValue];

    _workspaceOpenTimeoutInterval = PSTMillisecondsToTimeInterval(
        PSTRequiredConfigurationValue(timing, @"workspaceOpenTimeoutMilliseconds"));
    _mainRunLoopPollInterval = PSTMillisecondsToTimeInterval(
        PSTRequiredConfigurationValue(timing, @"mainRunLoopPollMilliseconds"));
    _paneWaitNanoseconds = PSTMillisecondsToNanoseconds(
        PSTRequiredConfigurationValue(timing, @"paneWaitMilliseconds"));
    _elementWaitNanoseconds = PSTMillisecondsToNanoseconds(
        PSTRequiredConfigurationValue(timing, @"elementWaitMilliseconds"));
    _authorizationWaitNanoseconds = PSTMillisecondsToNanoseconds(
        PSTRequiredConfigurationValue(timing, @"authorizationWaitMilliseconds"));
    _applicationActivationPollNanoseconds =
        PSTMillisecondsToNanoseconds(PSTRequiredConfigurationValue(
            timing, @"applicationActivationPollMilliseconds"));
    _nativeDragTimeoutInterval = PSTMillisecondsToTimeInterval(
        PSTRequiredConfigurationValue(timing, @"nativeDragTimeoutMilliseconds"));
    _disclosureSettleNanoseconds = PSTMillisecondsToNanoseconds(
        PSTRequiredConfigurationValue(timing, @"disclosureSettleMilliseconds"));
    _pollNanoseconds = PSTMillisecondsToNanoseconds(
        PSTRequiredConfigurationValue(timing, @"pollMilliseconds"));
  }
  return self;
}

- (nullable NSURL *)privacyPaneURLForRoute:(NSString *)route {
  return
      [NSURL URLWithString:[self.privacyPaneURLPrefix stringByAppendingString:route]];
}

- (NSString *)switchIdentifierForApplicationPath:(NSString *)applicationPath {
  return [applicationPath.lastPathComponent
      stringByAppendingString:self.applicationSwitchSuffix];
}

- (NSString *)automationRowNameForTargetName:(NSString *)targetName {
  return [targetName stringByAppendingString:self.automationRowSuffix];
}

@end

PSTSystemSettingsUIProfile *PSTCurrentSystemSettingsUIProfile(void) {
  static PSTSystemSettingsUIProfile *profile;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSDictionary<NSString *, id> *configuration =
        PSTCurrentRuntimePolicy().systemSettings;
    profile = [[PSTSystemSettingsUIProfile alloc] initWithConfiguration:configuration];
  });
  return profile;
}
