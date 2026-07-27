#import "application/PSTAppDelegate.h"

#import "application/PSTAboutWindowController.h"
#import "application/PSTApplicationModel.h"
#import "application/PSTPermissionConfirmationController.h"
#import "application/PSTPermissionTargetsDocument.h"
#import "application/PSTPermissionTargetsEditorController.h"
#import "application/PSTUIComponents.h"
#import "authorization/PSTAuthorizationInjector.h"
#import "automation/PSTAXUtilities.h"
#import "automation/PSTSystemSettingsUIProfile.h"
#import "permissions/PSTPermissionManifest.h"
#import "permissions/PSTPermissionWorkflow.h"
#import "security/PSTCredentialValidator.h"
#import "security/PSTSecureBuffer.h"

#include <string.h>

constexpr CGFloat PST_MAIN_WINDOW_WIDTH = 760.0;
constexpr CGFloat PST_MAIN_WINDOW_HEIGHT = 560.0;
constexpr CGFloat PST_MAIN_WINDOW_MINIMUM_WIDTH = 720.0;
constexpr CGFloat PST_MAIN_WINDOW_MINIMUM_HEIGHT = 540.0;
constexpr NSTimeInterval PST_TRUST_REFRESH_INTERVAL = 1.0;
constexpr CGFloat PST_PASSWORD_FIELD_WIDTH = 176.0;
constexpr CGFloat PST_REQUIREMENTS_CARD_HEIGHT = 222.0;
constexpr CGFloat PST_ACTIVITY_CARD_COLLAPSED_HEIGHT = 84.0;
constexpr CGFloat PST_ACTIVITY_LOG_HEIGHT = 140.0;

@interface PSTAppDelegate ()

@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) PSTPermissionManifest *catalog;
@property(nonatomic, strong) PSTPermissionManifest *manifest;
@property(nonatomic, strong, nullable) NSURL *targetsURL;
@property(nonatomic, strong) PSTPermissionTargetsStore *targetsStore;
@property(nonatomic, strong) NSTextField *summaryLabel;
@property(nonatomic, strong) NSTextField *targetFileStatus;
@property(nonatomic, strong) NSButton *chooseTargetsButton;
@property(nonatomic, strong) NSButton *createTargetsButton;
@property(nonatomic, strong) NSImageView *trustIcon;
@property(nonatomic, strong) NSTextField *trustStatus;
@property(nonatomic, strong) NSButton *trustButton;
@property(nonatomic, strong) NSImageView *credentialIcon;
@property(nonatomic, strong) NSTextField *credentialStatus;
@property(nonatomic, strong) NSSecureTextField *passwordField;
@property(nonatomic, strong) NSButton *validateButton;
@property(nonatomic, strong) NSButton *runButton;
@property(nonatomic, strong) NSButton *forgetButton;
@property(nonatomic, strong) NSImageView *activityIcon;
@property(nonatomic, strong) NSTextField *activityTitle;
@property(nonatomic, strong) NSTextField *activityDetail;
@property(nonatomic, strong) NSProgressIndicator *activityProgress;
@property(nonatomic, strong) NSButton *detailsButton;
@property(nonatomic, strong) NSScrollView *logScrollView;
@property(nonatomic, strong) NSLayoutConstraint *activityCardHeight;
@property(nonatomic, strong) NSTextView *logView;
@property(nonatomic, strong) NSTimer *trustTimer;
@property(nonatomic, strong) PSTPermissionWorkflow *workflow;
@property(nonatomic, strong)
    PSTPermissionConfirmationController *confirmationController;
@property(nonatomic, strong)
    PSTPermissionTargetsEditorController *targetsEditorController;
@property(nonatomic, strong) PSTAboutWindowController *aboutWindowController;
@property(nonatomic, assign) BOOL activityDetailsVisible;
@property(nonatomic, assign) BOOL started;
@property(nonatomic, assign) BOOL pendingReviewRequested;
@property(nonatomic, assign) char *credentialArgument;

- (BOOL)loadCredentialArgument;
- (BOOL)loadTargetsURL:(NSURL *)targetsURL showAlert:(BOOL)showAlert;
- (BOOL)loadTargetsData:(NSData *)targetsData
              sourceURL:(nullable NSURL *)sourceURL
              showAlert:(BOOL)showAlert;
- (void)tryPresentPendingReview;
- (void)updateTargetConfigurationPresentation;
- (void)validateCredentialInSecureBuffer;
- (void)beginPermissionWorkflowWithManifest:(PSTPermissionManifest *)manifest;
- (void)setActivityTitle:(NSString *)title
                  detail:(NSString *)detail
                  symbol:(NSString *)symbol
                    tint:(NSColor *)tint;
- (void)setBusyActivityTitle:(NSString *)title detail:(NSString *)detail;

@end

@implementation PSTAppDelegate {
  PSTApplicationModel _model;
  PSTSecureBuffer _credential;
}

static NSBox *PSTCardWithContent(NSView *cardContent) {
  PSTUIFlippedView *wrapper = [[PSTUIFlippedView alloc] initWithFrame:NSZeroRect];
  wrapper.translatesAutoresizingMaskIntoConstraints = YES;
  wrapper.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  [wrapper addSubview:cardContent];
  [NSLayoutConstraint activateConstraints:@[
    [cardContent.topAnchor constraintEqualToAnchor:wrapper.topAnchor],
    [cardContent.leadingAnchor constraintEqualToAnchor:wrapper.leadingAnchor],
    [cardContent.trailingAnchor constraintEqualToAnchor:wrapper.trailingAnchor],
    [cardContent.bottomAnchor constraintEqualToAnchor:wrapper.bottomAnchor],
  ]];

  NSBox *card = [[NSBox alloc] initWithFrame:NSZeroRect];
  card.translatesAutoresizingMaskIntoConstraints = NO;
  card.boxType = NSBoxCustom;
  card.titlePosition = NSNoTitle;
  card.borderWidth = 0.0;
  card.cornerRadius = 16.0;
  card.borderColor = [NSColor.separatorColor colorWithAlphaComponent:0.35];
  card.fillColor = NSColor.controlBackgroundColor;
  card.contentViewMargins = NSMakeSize(20.0, 18.0);
  card.contentView = wrapper;
  return card;
}

static NSStackView *PSTStatusText(NSString *titleText, NSTextField *status) {
  NSTextField *title = PSTUILabel(titleText);
  title.font = [NSFont systemFontOfSize:14.0 weight:NSFontWeightMedium];
  status.font = [NSFont systemFontOfSize:12.0];
  status.textColor = NSColor.secondaryLabelColor;
  return PSTUIVerticalStack(@[ title, status ], 3.0);
}

static NSStackView *PSTRequirementRow(NSImageView *icon, NSView *text,
                                      NSArray<NSView *> *actions,
                                      BOOL detachesHiddenViews) {
  NSMutableArray<NSView *> *views =
      [NSMutableArray arrayWithObjects:icon, text, PSTUIFlexibleSpace(), nil];
  [views addObjectsFromArray:actions];
  NSStackView *row = [NSStackView stackViewWithViews:views];
  row.translatesAutoresizingMaskIntoConstraints = NO;
  row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  row.alignment = NSLayoutAttributeCenterY;
  row.spacing = 12.0;
  row.detachesHiddenViews = detachesHiddenViews;
  [row.heightAnchor constraintGreaterThanOrEqualToConstant:48.0].active = YES;
  return row;
}

static NSString *PSTString(const char *text) {
  NSString *value = text != nullptr ? [NSString stringWithUTF8String:text] : nil;
  return value != nil ? value : @"";
}

static NSUInteger PSTUsedServiceCount(PSTPermissionManifest *manifest) {
  NSMutableSet<NSString *> *usedServiceIdentifiers = [NSMutableSet set];
  for (PSTPermissionTarget *target in manifest.targets) {
    [usedServiceIdentifiers addObjectsFromArray:target.serviceIdentifiers];
  }
  return usedServiceIdentifiers.count;
}

static NSString *PSTManifestSummary(PSTPermissionManifest *manifest) {
  NSUInteger serviceCount = PSTUsedServiceCount(manifest);
  NSUInteger targetCount = manifest.targets.count;
  return
      [NSString stringWithFormat:@"Prepare %lu permission %@ across %lu %@.",
                                 (unsigned long)serviceCount,
                                 serviceCount == 1 ? @"type" : @"types",
                                 (unsigned long)targetCount,
                                 targetCount == 1 ? @"app or tool" : @"apps and tools"];
}

static NSColor *PSTColor(PSTPresentationTone tone) {
  switch (tone) {
  case PST_PRESENTATION_TONE_SUCCESS:
    return NSColor.systemGreenColor;
  case PST_PRESENTATION_TONE_WARNING:
    return NSColor.systemOrangeColor;
  case PST_PRESENTATION_TONE_ERROR:
    return NSColor.systemRedColor;
  case PST_PRESENTATION_TONE_NEUTRAL:
    return NSColor.secondaryLabelColor;
  }
  return NSColor.secondaryLabelColor;
}

- (instancetype)init {
  return [self initWithCredentialArgument:nullptr targetsURL:nil];
}

- (instancetype)initWithCredentialArgument:(char *)credential_argument
                                targetsURL:(nullable NSURL *)targetsURL {
  self = [super init];
  if (self != nil) {
    _credentialArgument = credential_argument;
    _targetsURL = targetsURL;
    _targetsStore = [[PSTPermissionTargetsStore alloc] init];
  }
  return self;
}

- (void)start {
  if (self.started) {
    return;
  }
  self.started = YES;
  if (!pst_secure_buffer_init(&_credential, PST_CREDENTIAL_BUFFER_CAPACITY)) {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Unable to lock credential memory";
    alert.informativeText =
        @"The bootstrap will not run with pageable password memory.";
    [alert runModal];
    [NSApp terminate:nil];
    return;
  }
  [self buildWindow];
  [self updateTrustState];
  self.trustTimer = [NSTimer scheduledTimerWithTimeInterval:PST_TRUST_REFRESH_INTERVAL
                                                     target:self
                                                   selector:@selector(updateTrustState)
                                                   userInfo:nil
                                                    repeats:YES];
  [self.window makeKeyAndOrderFront:nil];
  [NSApp activateIgnoringOtherApps:YES];
  if ([self loadCredentialArgument]) {
    [self validateCredentialInSecureBuffer];
  }
}

- (void)buildWindow {
  self.window = [[NSWindow alloc]
      initWithContentRect:NSMakeRect(0, 0, PST_MAIN_WINDOW_WIDTH,
                                     PST_MAIN_WINDOW_HEIGHT)
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                          NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  self.window.title = @"Permstrap";
  self.window.titlebarSeparatorStyle = NSTitlebarSeparatorStyleShadow;
  self.window.delegate = self;
  self.window.restorable = NO;
  self.window.contentMinSize =
      NSMakeSize(PST_MAIN_WINDOW_MINIMUM_WIDTH, PST_MAIN_WINDOW_MINIMUM_HEIGHT);
  [self.window center];

  PSTUIFlippedView *content = [[PSTUIFlippedView alloc]
      initWithFrame:NSMakeRect(0, 0, PST_MAIN_WINDOW_WIDTH, PST_MAIN_WINDOW_HEIGHT)];
  self.window.contentView = content;

  NSError *manifestError = nil;
  PSTPermissionManifest *catalog =
      [PSTPermissionManifest bundledCatalogWithError:&manifestError];
  self.catalog = catalog;
  _model = pst_application_model_make(NO);

  NSImageView *headerIcon = [[NSImageView alloc] initWithFrame:NSZeroRect];
  headerIcon.translatesAutoresizingMaskIntoConstraints = NO;
  headerIcon.image = NSApp.applicationIconImage;
  headerIcon.imageScaling = NSImageScaleProportionallyUpOrDown;
  [headerIcon setAccessibilityLabel:@"Permstrap"];
  [NSLayoutConstraint activateConstraints:@[
    [headerIcon.widthAnchor constraintEqualToConstant:58.0],
    [headerIcon.heightAnchor constraintEqualToConstant:58.0],
  ]];

  NSTextField *title = PSTUILabel(@"Permission Setup");
  title.font = [NSFont systemFontOfSize:26.0 weight:NSFontWeightSemibold];

  NSString *summaryText = nil;
  if (self.manifest != nil) {
    summaryText = PSTManifestSummary(self.manifest);
  } else {
    summaryText =
        @"Choose what to configure, confirm access, then review every change.";
  }
  self.summaryLabel = PSTUILabel(summaryText);
  self.summaryLabel.font = [NSFont systemFontOfSize:13.0 weight:NSFontWeightRegular];
  self.summaryLabel.textColor = NSColor.secondaryLabelColor;
  self.summaryLabel.maximumNumberOfLines = 2;
  self.summaryLabel.lineBreakMode = NSLineBreakByWordWrapping;

  NSStackView *titleStack = PSTUIVerticalStack(@[ title, self.summaryLabel ], 5.0);
  NSStackView *headerStack = [NSStackView stackViewWithViews:@[
    headerIcon,
    titleStack,
  ]];
  headerStack.translatesAutoresizingMaskIntoConstraints = NO;
  headerStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  headerStack.alignment = NSLayoutAttributeCenterY;
  headerStack.spacing = 18.0;

  NSTextField *requirementsHeading = PSTUILabel(@"Before You Begin");
  requirementsHeading.font = [NSFont systemFontOfSize:13.0 weight:NSFontWeightSemibold];
  requirementsHeading.textColor = NSColor.secondaryLabelColor;

  self.trustIcon = PSTUISymbolView(@"ellipsis.circle", @"Checking automation access",
                                   21.0, NSColor.secondaryLabelColor);
  self.trustStatus = PSTUILabel(@"Checking…");
  self.trustStatus.lineBreakMode = NSLineBreakByTruncatingTail;
  NSStackView *trustText = PSTStatusText(@"Automation Access", self.trustStatus);

  self.trustButton = [NSButton buttonWithTitle:@"Open System Settings…"
                                        target:self
                                        action:@selector(openAccessibilitySettings:)];
  self.trustButton.translatesAutoresizingMaskIntoConstraints = NO;
  self.trustButton.image =
      PSTUISymbol(@"gear", @"Open Automation Settings", 13.0, NSFontWeightRegular);
  self.trustButton.imagePosition = NSImageLeading;
  self.trustButton.imageHugsTitle = YES;
  PSTUIConfigureButton(self.trustButton, NO);
  [self.trustButton.widthAnchor constraintGreaterThanOrEqualToConstant:156.0].active =
      YES;

  NSStackView *trustRow =
      PSTRequirementRow(self.trustIcon, trustText, @[ self.trustButton ], YES);

  self.credentialIcon = PSTUISymbolView(@"lock.fill", @"Administrator password", 21.0,
                                        NSColor.secondaryLabelColor);
  self.credentialStatus = PSTUILabel(@"Kept in locked memory and never saved");
  self.credentialStatus.lineBreakMode = NSLineBreakByTruncatingTail;
  NSStackView *passwordText =
      PSTStatusText(@"Administrator Password", self.credentialStatus);
  [passwordText.widthAnchor constraintGreaterThanOrEqualToConstant:238.0].active = YES;

  self.passwordField = [[NSSecureTextField alloc] initWithFrame:NSZeroRect];
  self.passwordField.translatesAutoresizingMaskIntoConstraints = NO;
  self.passwordField.placeholderString = @"Password";
  self.passwordField.target = self;
  self.passwordField.action = @selector(validatePassword:);
  self.passwordField.controlSize = NSControlSizeLarge;
  [self.passwordField.widthAnchor constraintEqualToConstant:PST_PASSWORD_FIELD_WIDTH]
      .active = YES;

  self.validateButton = [NSButton buttonWithTitle:@"Validate"
                                           target:self
                                           action:@selector(validatePassword:)];
  self.validateButton.translatesAutoresizingMaskIntoConstraints = NO;
  self.validateButton.controlSize = NSControlSizeLarge;
  PSTUIConfigureButton(self.validateButton, NO);
  [self.validateButton.widthAnchor constraintGreaterThanOrEqualToConstant:82.0].active =
      YES;

  self.forgetButton = [NSButton buttonWithTitle:@"Forget"
                                         target:self
                                         action:@selector(forgetPassword:)];
  self.forgetButton.translatesAutoresizingMaskIntoConstraints = NO;
  self.forgetButton.image =
      PSTUISymbol(@"xmark", @"Forget stored password", 11.0, NSFontWeightMedium);
  self.forgetButton.imagePosition = NSImageLeading;
  self.forgetButton.imageHugsTitle = YES;
  self.forgetButton.controlSize = NSControlSizeLarge;
  PSTUIConfigureButton(self.forgetButton, NO);
  self.forgetButton.hidden = YES;

  NSStackView *passwordRow = PSTRequirementRow(
      self.credentialIcon, passwordText,
      @[ self.passwordField, self.validateButton, self.forgetButton ], YES);

  NSImageView *targetIcon =
      PSTUISymbolView(@"square.stack.3d.up.fill", @"Target configuration", 21.0,
                      NSColor.secondaryLabelColor);
  self.targetFileStatus = PSTUILabel(
      [NSString stringWithFormat:@"Choose a %@ file", PSTPermissionTargetsFilename]);
  self.targetFileStatus.lineBreakMode = NSLineBreakByTruncatingMiddle;
  NSStackView *targetText = PSTStatusText(@"Permission Targets", self.targetFileStatus);
  self.chooseTargetsButton = [NSButton buttonWithTitle:@"Open…"
                                                target:self
                                                action:@selector(chooseTargets:)];
  self.chooseTargetsButton.translatesAutoresizingMaskIntoConstraints = NO;
  self.chooseTargetsButton.image =
      PSTUISymbol(@"folder", @"Open target file", 13.0, NSFontWeightRegular);
  self.chooseTargetsButton.imagePosition = NSImageLeading;
  self.chooseTargetsButton.imageHugsTitle = YES;
  PSTUIConfigureButton(self.chooseTargetsButton, NO);
  [self.chooseTargetsButton.widthAnchor constraintGreaterThanOrEqualToConstant:106.0]
      .active = YES;
  self.createTargetsButton = [NSButton buttonWithTitle:@"New…"
                                                target:self
                                                action:@selector(createTargets:)];
  self.createTargetsButton.translatesAutoresizingMaskIntoConstraints = NO;
  self.createTargetsButton.image =
      PSTUISymbol(@"doc.badge.plus", @"Create target file", 13.0, NSFontWeightRegular);
  self.createTargetsButton.imagePosition = NSImageLeading;
  self.createTargetsButton.imageHugsTitle = YES;
  self.createTargetsButton.enabled = catalog != nil;
  PSTUIConfigureButton(self.createTargetsButton, NO);
  [self.createTargetsButton.widthAnchor constraintGreaterThanOrEqualToConstant:106.0]
      .active = YES;
  NSStackView *targetRow =
      PSTRequirementRow(targetIcon, targetText,
                        @[ self.createTargetsButton, self.chooseTargetsButton ], NO);

  NSBox *targetSeparator = PSTUISeparator();
  NSBox *passwordSeparator = PSTUISeparator();
  NSStackView *requirementsStack = PSTUIVerticalStack(
      @[ targetRow, targetSeparator, trustRow, passwordSeparator, passwordRow ], 11.0);
  requirementsStack.alignment = NSLayoutAttributeLeading;
  [targetRow.widthAnchor constraintEqualToAnchor:requirementsStack.widthAnchor].active =
      YES;
  [targetSeparator.widthAnchor constraintEqualToAnchor:requirementsStack.widthAnchor]
      .active = YES;
  [trustRow.widthAnchor constraintEqualToAnchor:requirementsStack.widthAnchor].active =
      YES;
  [passwordSeparator.widthAnchor constraintEqualToAnchor:requirementsStack.widthAnchor]
      .active = YES;
  [passwordRow.widthAnchor constraintEqualToAnchor:requirementsStack.widthAnchor]
      .active = YES;
  NSBox *requirementsCard = PSTCardWithContent(requirementsStack);
  [requirementsCard.heightAnchor constraintEqualToConstant:PST_REQUIREMENTS_CARD_HEIGHT]
      .active = YES;

  NSImageView *securityIcon =
      PSTUISymbolView(@"checkmark.circle", @"Review before granting", 13.0,
                      NSColor.secondaryLabelColor);
  NSTextField *securityText =
      PSTUILabel(@"Nothing changes until you confirm the review.");
  securityText.font = [NSFont systemFontOfSize:12.0];
  securityText.textColor = NSColor.secondaryLabelColor;
  securityText.maximumNumberOfLines = 2;
  securityText.lineBreakMode = NSLineBreakByWordWrapping;
  NSStackView *securityStack =
      [NSStackView stackViewWithViews:@[ securityIcon, securityText ]];
  securityStack.translatesAutoresizingMaskIntoConstraints = NO;
  securityStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  securityStack.alignment = NSLayoutAttributeCenterY;
  securityStack.spacing = 7.0;

  self.runButton = [NSButton buttonWithTitle:@"Review Changes…"
                                      target:self
                                      action:@selector(runWorkflow:)];
  self.runButton.translatesAutoresizingMaskIntoConstraints = NO;
  self.runButton.controlSize = NSControlSizeLarge;
  self.runButton.image = PSTUISymbol(
      @"list.bullet.clipboard", @"Review permission changes", 14.0, NSFontWeightMedium);
  self.runButton.imagePosition = NSImageLeading;
  self.runButton.imageHugsTitle = YES;
  self.runButton.keyEquivalent = @"\r";
  self.runButton.enabled = NO;
  PSTUIConfigureButton(self.runButton, YES);

  NSStackView *actionRow = [NSStackView stackViewWithViews:@[
    securityStack,
    PSTUIFlexibleSpace(),
    self.runButton,
  ]];
  actionRow.translatesAutoresizingMaskIntoConstraints = NO;
  actionRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  actionRow.alignment = NSLayoutAttributeCenterY;
  actionRow.spacing = 16.0;

  self.detailsButton = [NSButton buttonWithTitle:@"View Log"
                                          target:self
                                          action:@selector(toggleActivityDetails:)];
  self.detailsButton.translatesAutoresizingMaskIntoConstraints = NO;
  [self.detailsButton setButtonType:NSButtonTypeOnOff];
  self.detailsButton.bordered = NO;
  self.detailsButton.image =
      PSTUISymbol(@"chevron.right", @"Show details", 10.0, NSFontWeightSemibold);
  self.detailsButton.imagePosition = NSImageLeading;
  self.detailsButton.imageHugsTitle = YES;
  self.detailsButton.toolTip = @"Show or hide detailed activity";
  self.detailsButton.controlSize = NSControlSizeSmall;

  self.activityIcon = PSTUISymbolView(@"ellipsis.circle", @"Current status", 21.0,
                                      NSColor.secondaryLabelColor);
  self.activityTitle = PSTUILabel(@"Checking Requirements");
  self.activityTitle.font = [NSFont systemFontOfSize:14.0 weight:NSFontWeightMedium];
  self.activityDetail = PSTUILabel(@"Checking Accessibility access…");
  self.activityDetail.font = [NSFont systemFontOfSize:12.0];
  self.activityDetail.textColor = NSColor.secondaryLabelColor;
  self.activityDetail.maximumNumberOfLines = 2;
  self.activityDetail.lineBreakMode = NSLineBreakByWordWrapping;
  NSStackView *activityText =
      PSTUIVerticalStack(@[ self.activityTitle, self.activityDetail ], 2.0);

  self.activityProgress = [[NSProgressIndicator alloc] initWithFrame:NSZeroRect];
  self.activityProgress.translatesAutoresizingMaskIntoConstraints = NO;
  self.activityProgress.style = NSProgressIndicatorStyleSpinning;
  self.activityProgress.controlSize = NSControlSizeSmall;
  self.activityProgress.displayedWhenStopped = NO;
  self.activityProgress.hidden = YES;

  NSStackView *activityStatusRow = [NSStackView stackViewWithViews:@[
    self.activityIcon,
    self.activityProgress,
    activityText,
    PSTUIFlexibleSpace(),
    self.detailsButton,
  ]];
  activityStatusRow.translatesAutoresizingMaskIntoConstraints = NO;
  activityStatusRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  activityStatusRow.alignment = NSLayoutAttributeCenterY;
  activityStatusRow.spacing = 12.0;
  activityStatusRow.detachesHiddenViews = YES;

  self.logScrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
  self.logScrollView.translatesAutoresizingMaskIntoConstraints = NO;
  self.logScrollView.hasVerticalScroller = YES;
  self.logScrollView.autohidesScrollers = YES;
  self.logScrollView.borderType = NSNoBorder;
  self.logScrollView.drawsBackground = YES;
  self.logScrollView.backgroundColor = NSColor.textBackgroundColor;
  self.logScrollView.hidden = YES;
  [self.logScrollView.heightAnchor constraintEqualToConstant:PST_ACTIVITY_LOG_HEIGHT]
      .active = YES;

  self.logView = [[NSTextView alloc] initWithFrame:NSZeroRect];
  self.logView.editable = NO;
  self.logView.selectable = YES;
  self.logView.font = [NSFont monospacedSystemFontOfSize:11.0
                                                  weight:NSFontWeightRegular];
  self.logView.drawsBackground = YES;
  self.logView.backgroundColor = NSColor.textBackgroundColor;
  self.logView.textColor = NSColor.textColor;
  self.logView.verticallyResizable = YES;
  self.logView.horizontallyResizable = NO;
  self.logView.autoresizingMask = NSViewWidthSizable;
  self.logView.textContainer.widthTracksTextView = YES;
  self.logView.textContainerInset = NSMakeSize(8.0, 7.0);
  NSFont *logFont = self.logView.font;
  if (logFont == nil) {
    logFont = [NSFont monospacedSystemFontOfSize:11.0 weight:NSFontWeightRegular];
  }
  NSDictionary<NSAttributedStringKey, id> *logAttributes = @{
    NSFontAttributeName : logFont,
    NSForegroundColorAttributeName : NSColor.textColor,
  };
  [self.logView.textStorage
      setAttributedString:[[NSAttributedString alloc] initWithString:@"App launched.\n"
                                                          attributes:logAttributes]];
  self.logScrollView.documentView = self.logView;

  NSStackView *activityStack =
      PSTUIVerticalStack(@[ activityStatusRow, self.logScrollView ], 14.0);
  activityStack.detachesHiddenViews = YES;
  [activityStatusRow.widthAnchor constraintEqualToAnchor:activityStack.widthAnchor]
      .active = YES;
  [self.logScrollView.widthAnchor constraintEqualToAnchor:activityStack.widthAnchor]
      .active = YES;
  NSBox *activityCard = PSTCardWithContent(activityStack);
  self.activityCardHeight = [activityCard.heightAnchor
      constraintEqualToConstant:PST_ACTIVITY_CARD_COLLAPSED_HEIGHT];
  self.activityCardHeight.active = YES;

  NSStackView *root = PSTUIVerticalStack(
      @[
        headerStack,
        requirementsHeading,
        requirementsCard,
        activityCard,
        actionRow,
      ],
      16.0);
  [root setCustomSpacing:24.0 afterView:headerStack];
  [root setCustomSpacing:14.0 afterView:requirementsCard];
  [root setCustomSpacing:20.0 afterView:activityCard];
  [content addSubview:root];

  [NSLayoutConstraint activateConstraints:@[
    [root.topAnchor constraintEqualToAnchor:content.topAnchor constant:32.0],
    [root.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:36.0],
    [root.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-36.0],
    [root.bottomAnchor constraintLessThanOrEqualToAnchor:content.bottomAnchor
                                                constant:-28.0],
    [headerStack.widthAnchor constraintEqualToAnchor:root.widthAnchor],
    [requirementsCard.widthAnchor constraintEqualToAnchor:root.widthAnchor],
    [activityCard.widthAnchor constraintEqualToAnchor:root.widthAnchor],
    [actionRow.widthAnchor constraintEqualToAnchor:root.widthAnchor],
  ]];

  self.passwordField.nextKeyView = self.validateButton;
  self.validateButton.nextKeyView = self.runButton;
  NSURL *initialTargetsURL =
      self.targetsURL != nil ? self.targetsURL : [self.targetsStore existingTargetsURL];
  if (catalog != nil && initialTargetsURL != nil) {
    [self loadTargetsURL:initialTargetsURL showAlert:NO];
  } else {
    [self updateTargetConfigurationPresentation];
  }
  if (catalog == nil) {
    NSString *description = manifestError.localizedDescription;
    [self setActivityTitle:@"Configuration Unavailable"
                    detail:description != nil
                               ? description
                               : @"The permission catalog could not be loaded."
                    symbol:@"exclamationmark.triangle.fill"
                      tint:NSColor.systemRedColor];
  }
}

- (BOOL)loadTargetsURL:(NSURL *)targetsURL showAlert:(BOOL)showAlert {
  NSError *error = nil;
  PSTPermissionManifest *manifest =
      [PSTPermissionManifest bundledManifestWithTargetsURL:targetsURL error:&error];
  if (manifest == nil) {
    if (showAlert) {
      NSAlert *alert = [[NSAlert alloc] init];
      alert.alertStyle = NSAlertStyleWarning;
      alert.messageText = @"Unable to Load Permission Targets";
      alert.informativeText =
          error.localizedDescription != nil
              ? error.localizedDescription
              : @"The selected file is not a valid target configuration.";
      [alert beginSheetModalForWindow:self.window completionHandler:nil];
    }
    if (self.manifest == nil) {
      pst_application_model_set_configuration_available(&_model, false);
    }
    return NO;
  }

  self.pendingReviewRequested = NO;
  self.targetsURL = targetsURL;
  self.manifest = manifest;
  pst_application_model_set_configuration_available(&_model, true);
  if (self.targetFileStatus != nil) {
    [self updateTargetConfigurationPresentation];
    [self appendStatus:[NSString
                           stringWithFormat:@"Loaded %lu permission targets from %@.",
                                            (unsigned long)manifest.targets.count,
                                            targetsURL.path]];
    [self updateTrustState];
  }
  return YES;
}

- (BOOL)loadTargetsData:(NSData *)targetsData
              sourceURL:(nullable NSURL *)sourceURL
              showAlert:(BOOL)showAlert {
  NSError *error = nil;
  PSTPermissionManifest *manifest =
      [PSTPermissionManifest bundledManifestWithTargetsData:targetsData error:&error];
  if (manifest == nil) {
    if (showAlert) {
      NSAlert *alert = [[NSAlert alloc] init];
      alert.alertStyle = NSAlertStyleWarning;
      alert.messageText = @"Unable to Apply Permission Targets";
      alert.informativeText = error.localizedDescription != nil
                                  ? error.localizedDescription
                                  : @"The edited target configuration is not valid.";
      [alert beginSheetModalForWindow:self.window completionHandler:nil];
    }
    if (self.manifest == nil) {
      pst_application_model_set_configuration_available(&_model, false);
    }
    return NO;
  }

  self.pendingReviewRequested = NO;
  self.targetsURL = sourceURL;
  self.manifest = manifest;
  pst_application_model_set_configuration_available(&_model, true);
  [self updateTargetConfigurationPresentation];
  NSString *sourceDescription =
      sourceURL.path.length > 0 ? sourceURL.path : @"the in-memory editor";
  [self appendStatus:[NSString
                         stringWithFormat:@"Applied %lu permission targets from %@.",
                                          (unsigned long)manifest.targets.count,
                                          sourceDescription]];
  [self updateTrustState];
  return YES;
}

- (void)updateTargetConfigurationPresentation {
  if (self.manifest == nil) {
    self.targetFileStatus.stringValue =
        [NSString stringWithFormat:@"Choose a %@ file", PSTPermissionTargetsFilename];
    self.chooseTargetsButton.title = @"Open…";
    self.summaryLabel.stringValue =
        @"Choose what to configure, confirm access, then review every change.";
    return;
  }
  self.targetFileStatus.stringValue =
      self.targetsURL.path != nil ? self.targetsURL.path : @"Runtime targets loaded";
  self.chooseTargetsButton.title = @"Change…";
  self.summaryLabel.stringValue = PSTManifestSummary(self.manifest);
}

- (void)chooseTargets:(id)sender {
  (void)sender;
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  panel.title = @"Choose Permission Targets";
  panel.message = [NSString
      stringWithFormat:@"Select a %@ file. It is validated before any permission "
                        "changes are shown or attempted.",
                       PSTPermissionTargetsFilename];
  panel.prompt = @"Load Targets";
  panel.canChooseDirectories = NO;
  panel.canChooseFiles = YES;
  panel.allowsMultipleSelection = NO;
  if (self.targetsURL != nil) {
    panel.directoryURL = [self.targetsURL URLByDeletingLastPathComponent];
  }
  __weak PSTAppDelegate *weakSelf = self;
  [panel
      beginSheetModalForWindow:self.window
             completionHandler:^(NSModalResponse response) {
               PSTAppDelegate *strongSelf = weakSelf;
               NSURL *URL = panel.URL;
               if (strongSelf == nil || response != NSModalResponseOK || URL == nil) {
                 return;
               }
               [strongSelf loadTargetsURL:URL showAlert:YES];
             }];
}

- (void)createTargets:(id)sender {
  (void)sender;
  if (self.catalog == nil) {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = @"Unable to Create Permission Targets";
    alert.informativeText =
        @"The bundled permission catalog is unavailable, so the editor cannot list "
         "supported permissions.";
    [alert beginSheetModalForWindow:self.window completionHandler:nil];
    return;
  }
  if (self.targetsEditorController != nil) {
    return;
  }

  PSTPermissionTargetsEditorController *controller =
      [[PSTPermissionTargetsEditorController alloc]
          initWithServices:self.catalog.services];
  self.targetsEditorController = controller;
  __weak PSTAppDelegate *weakSelf = self;
  [controller
      presentForWindow:self.window
            completion:^(PSTPermissionTargetsEditorResult *_Nullable result) {
              PSTAppDelegate *strongSelf = weakSelf;
              if (strongSelf == nil) {
                return;
              }
              strongSelf.targetsEditorController = nil;
              if (result == nil) {
                return;
              }
              PSTPermissionTargetsEditorResult *editorResult =
                  (PSTPermissionTargetsEditorResult *_Nonnull)result;

              NSError *storeError = nil;
              NSURL *managedURL = nil;
              if ([strongSelf.targetsStore saveTargetsData:editorResult.targetsData
                                                     error:&storeError]) {
                managedURL = strongSelf.targetsStore.targetsURL;
                [strongSelf
                    appendStatus:[NSString
                                     stringWithFormat:
                                         @"Updated the automatic target configuration "
                                          "at %@.",
                                         managedURL.path]];
              } else {
                NSAlert *alert = [[NSAlert alloc] init];
                alert.alertStyle = NSAlertStyleWarning;
                alert.messageText = @"Unable to Save Automatic Permission Targets";
                alert.informativeText =
                    storeError.localizedDescription != nil
                        ? storeError.localizedDescription
                        : @"The app-managed target configuration could not "
                           "be saved for the next launch.";
                [alert beginSheetModalForWindow:strongSelf.window
                              completionHandler:nil];
              }

              if (!editorResult.shouldApply) {
                strongSelf.pendingReviewRequested = NO;
                [strongSelf
                    appendStatus:@"Permission targets were saved without applying "
                                  "them to the current session."];
                return;
              }
              NSURL *sourceURL =
                  editorResult.savedURL != nil ? editorResult.savedURL : managedURL;
              if ([strongSelf loadTargetsData:editorResult.targetsData
                                    sourceURL:sourceURL
                                    showAlert:YES]) {
                strongSelf.pendingReviewRequested = YES;
                [strongSelf tryPresentPendingReview];
              }
            }];
}

- (void)showAboutWindow:(id)sender {
  (void)sender;
  if (self.aboutWindowController == nil) {
    self.aboutWindowController = [[PSTAboutWindowController alloc] init];
  }
  [self.aboutWindowController showWindow:nil];
  [self.aboutWindowController.window center];
  [self.aboutWindowController.window makeKeyAndOrderFront:nil];
  [NSApp activateIgnoringOtherApps:YES];
}

- (void)setActivityTitle:(NSString *)title
                  detail:(NSString *)detail
                  symbol:(NSString *)symbol
                    tint:(NSColor *)tint {
  [self.activityProgress stopAnimation:nil];
  self.activityProgress.hidden = YES;
  self.activityIcon.hidden = NO;
  self.activityIcon.image = PSTUISymbol(symbol, title, 21.0, NSFontWeightMedium);
  self.activityIcon.contentTintColor = tint;
  [self.activityIcon setAccessibilityLabel:title];
  self.activityTitle.stringValue = title;
  self.activityDetail.stringValue = detail;
}

- (void)setBusyActivityTitle:(NSString *)title detail:(NSString *)detail {
  self.activityIcon.hidden = YES;
  self.activityProgress.hidden = NO;
  [self.activityProgress setAccessibilityLabel:title];
  [self.activityProgress startAnimation:nil];
  self.activityTitle.stringValue = title;
  self.activityDetail.stringValue = detail;
}

- (void)appendStatus:(NSString *)message {
  dispatch_async(dispatch_get_main_queue(), ^{
    NSString *line = [NSString stringWithFormat:@"%@\n", message];
    NSFont *logFont = self.logView.font;
    if (logFont == nil) {
      logFont = [NSFont monospacedSystemFontOfSize:11.0 weight:NSFontWeightRegular];
    }
    NSDictionary<NSAttributedStringKey, id> *attributes = @{
      NSFontAttributeName : logFont,
      NSForegroundColorAttributeName : NSColor.textColor,
    };
    [self.logView.textStorage
        appendAttributedString:[[NSAttributedString alloc] initWithString:line
                                                               attributes:attributes]];
    [self.logView scrollRangeToVisible:NSMakeRange(self.logView.string.length, 0)];
  });
}

- (void)toggleActivityDetails:(id)sender {
  (void)sender;
  BOOL showDetails = !self.activityDetailsVisible;
  self.activityDetailsVisible = showDetails;
  self.detailsButton.state =
      showDetails ? NSControlStateValueOn : NSControlStateValueOff;
  self.detailsButton.title = showDetails ? @"Hide Log" : @"View Log";
  self.detailsButton.image = PSTUISymbol(
      showDetails ? @"chevron.down" : @"chevron.right",
      showDetails ? @"Hide details" : @"Show details", 10.0, NSFontWeightSemibold);
  self.logScrollView.hidden = !showDetails;
  self.activityCardHeight.constant = showDetails ? 232.0 : 84.0;

  CGFloat heightChange = 148.0;
  NSRect frame = self.window.frame;
  if (showDetails) {
    frame.origin.y -= heightChange;
    frame.size.height += heightChange;
  } else {
    frame.origin.y += heightChange;
    frame.size.height -= heightChange;
  }
  NSScreen *screen =
      self.window.screen != nil ? self.window.screen : NSScreen.mainScreen;
  if (screen != nil && frame.origin.y < NSMinY(screen.visibleFrame)) {
    frame.origin.y = NSMinY(screen.visibleFrame);
  }
  [self.window setFrame:frame display:YES animate:YES];
}

- (void)updateTrustState {
  BOOL trusted = pst_ax_is_trusted(false) && CGPreflightPostEventAccess();
  pst_application_model_set_accessibility(&_model, trusted);
  PSTApplicationPresentation presentation = pst_application_model_present(&_model);

  self.trustStatus.stringValue = PSTString(presentation.trust_status);
  self.trustStatus.textColor = NSColor.secondaryLabelColor;
  self.trustIcon.image = PSTUISymbol(PSTString(presentation.trust_symbol),
                                     PSTString(presentation.trust_symbol_description),
                                     21.0, NSFontWeightMedium);
  [self.trustIcon
      setAccessibilityLabel:PSTString(presentation.trust_symbol_description)];
  self.trustIcon.contentTintColor = PSTColor(presentation.trust_tone);
  self.trustButton.hidden = !presentation.trust_button_visible;

  self.passwordField.hidden = !presentation.password_entry_visible;
  self.validateButton.hidden = !presentation.password_entry_visible;
  self.passwordField.enabled = presentation.password_entry_enabled;
  self.validateButton.enabled = presentation.password_entry_enabled;
  self.forgetButton.hidden = !presentation.forget_button_visible;
  self.forgetButton.enabled = presentation.forget_button_enabled;

  self.credentialStatus.stringValue = PSTString(presentation.credential_status);
  self.credentialIcon.image = PSTUISymbol(
      PSTString(presentation.credential_symbol),
      PSTString(presentation.credential_symbol_description), 21.0, NSFontWeightMedium);
  [self.credentialIcon
      setAccessibilityLabel:PSTString(presentation.credential_symbol_description)];
  self.credentialIcon.contentTintColor = PSTColor(presentation.credential_tone);

  self.runButton.title = PSTString(presentation.run_button_title);
  self.runButton.enabled = presentation.run_button_enabled;

  if (_model.workflow == PST_WORKFLOW_RUNNING ||
      _model.credential == PST_CREDENTIAL_VALIDATING) {
    return;
  }
  [self setActivityTitle:PSTString(presentation.activity_title)
                  detail:PSTString(presentation.activity_detail)
                  symbol:PSTString(presentation.activity_symbol)
                    tint:PSTColor(presentation.activity_tone)];
  [self tryPresentPendingReview];
}

- (void)tryPresentPendingReview {
  if (!self.pendingReviewRequested || self.confirmationController != nil ||
      self.targetsEditorController != nil || self.workflow != nil ||
      !pst_application_model_can_begin_workflow(&_model)) {
    return;
  }
  self.pendingReviewRequested = NO;
  [self runWorkflow:nil];
}

- (void)openAccessibilitySettings:(id)sender {
  (void)sender;
  (void)pst_ax_is_trusted(true);
  (void)CGRequestPostEventAccess();
  PSTSystemSettingsUIProfile *profile = PSTCurrentSystemSettingsUIProfile();
  NSURL *url = [profile privacyPaneURLForRoute:profile.accessibilityBootstrapRoute];
  if (url != nil) {
    [NSWorkspace.sharedWorkspace openURL:url];
  }
  [self appendStatus:@"Grant Accessibility control to Permstrap, including the "
                      "event-posting prompt, then return here."];
  [self setActivityTitle:@"Allow Accessibility Control"
                  detail:@"Approve the prompt and enable this app in System Settings."
                  symbol:@"gear"
                    tint:NSColor.systemOrangeColor];
}

- (BOOL)copyPasswordFieldIntoSecureBuffer {
  pst_secure_buffer_clear(&_credential);
  NSString *field_value = self.passwordField.stringValue;
  if (field_value.length == 0 ||
      [field_value maximumLengthOfBytesUsingEncoding:NSUTF8StringEncoding] >
          _credential.capacity) {
    self.passwordField.stringValue = @"";
    return NO;
  }
  BOOL copied = [field_value getCString:(char *)_credential.bytes
                              maxLength:_credential.capacity + 1
                               encoding:NSUTF8StringEncoding];
  self.passwordField.stringValue = @"";
  if (!copied) {
    pst_secure_buffer_clear(&_credential);
    return NO;
  }
  _credential.data_length = strlen((const char *)_credential.bytes);
  return _credential.data_length > 0;
}

- (BOOL)loadCredentialArgument {
  char *credential_argument = self.credentialArgument;
  if (credential_argument == nullptr) {
    return NO;
  }
  self.credentialArgument = nullptr;
  size_t credential_length = strlen(credential_argument);
  BOOL copied =
      pst_secure_buffer_move(&_credential, credential_argument, credential_length);
  if (copied && _credential.data_length > 0) {
    self.passwordField.placeholderString = @"Loaded from command line";
    [self appendStatus:@"Administrator password copied from the command line into "
                        "locked memory."];
    return YES;
  }
  self.passwordField.placeholderString = @"Memory only (argument failed)";
  [self appendStatus:@"Unable to load --password: the value was empty or exceeded "
                      "the locked buffer capacity."];
  return NO;
}

- (void)validateCredentialInSecureBuffer {
  if (_credential.data_length == 0 ||
      !pst_application_model_begin_credential_validation(&_model)) {
    return;
  }
  [self updateTrustState];
  [self setBusyActivityTitle:@"Validating Password"
                      detail:@"Checking the credential with macOS…"];
  [self appendStatus:@"Validating the password with macOS Authorization Services…"];
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    char error_buffer[PST_CREDENTIAL_VALIDATION_ERROR_CAPACITY] = {};
    PSTCredentialValidationResult result = pst_validate_administrator_credential(
        &self->_credential, error_buffer, sizeof(error_buffer));
    NSString *error_text = [NSString stringWithCString:error_buffer
                                              encoding:NSUTF8StringEncoding];
    if (error_text == nil) {
      error_text = @"macOS rejected the credential.";
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      BOOL accepted = result == PST_CREDENTIAL_VALIDATION_OK;
      pst_application_model_finish_credential_validation(&self->_model, accepted);
      if (accepted) {
        self.passwordField.placeholderString = @"Stored in locked memory";
        [self appendStatus:@"Password validated and retained in locked memory."];
        self.forgetButton.enabled = YES;
      } else {
        pst_secure_buffer_clear(&self->_credential);
        self.passwordField.placeholderString = @"Memory only";
        [self
            appendStatus:[NSString stringWithFormat:
                                       @"Password validation failed: %@",
                                       [error_text
                                           stringByTrimmingCharactersInSet:
                                               NSCharacterSet
                                                   .whitespaceAndNewlineCharacterSet]]];
      }
      [self updateTrustState];
      if (!accepted) {
        [self.window makeFirstResponder:self.passwordField];
      }
    });
  });
}

- (void)validatePassword:(id)sender {
  (void)sender;
  pst_application_model_set_accessibility(&_model, pst_ax_is_trusted(false) &&
                                                       CGPreflightPostEventAccess());
  if (!pst_application_model_can_validate_credential(&_model)) {
    return;
  }
  if (![self copyPasswordFieldIntoSecureBuffer]) {
    pst_application_model_mark_credential_input_invalid(&_model);
    [self appendStatus:@"Password was empty, too long, or could not be encoded."];
    [self updateTrustState];
    [self.window makeFirstResponder:self.passwordField];
    return;
  }

  [self validateCredentialInSecureBuffer];
}

- (void)forgetPassword:(id)sender {
  (void)sender;
  if (!pst_application_model_forget_credential(&_model)) {
    return;
  }
  pst_secure_buffer_clear(&_credential);
  self.passwordField.placeholderString = @"Memory only";
  [self appendStatus:@"The in-memory password was erased."];
  [self updateTrustState];
  [self.window makeFirstResponder:self.passwordField];
}

- (void)runWorkflow:(id)sender {
  (void)sender;
  self.pendingReviewRequested = NO;
  pst_application_model_set_accessibility(&_model, pst_ax_is_trusted(false) &&
                                                       CGPreflightPostEventAccess());
  if (!pst_application_model_can_begin_workflow(&_model)) {
    return;
  }

  PSTPermissionManifest *manifest = self.manifest;
  if (manifest == nil) {
    [self appendStatus:@"Unable to load the permission manifest."];
    return;
  }

  PSTPermissionConfirmationController *controller =
      [[PSTPermissionConfirmationController alloc] initWithManifest:manifest];
  self.confirmationController = controller;
  __weak PSTAppDelegate *weakSelf = self;
  [controller presentForWindow:self.window
                    completion:^(BOOL confirmed) {
                      PSTAppDelegate *strongSelf = weakSelf;
                      if (strongSelf == nil) {
                        return;
                      }
                      strongSelf.confirmationController = nil;
                      if (confirmed) {
                        [strongSelf beginPermissionWorkflowWithManifest:manifest];
                      }
                    }];
}

- (void)beginPermissionWorkflowWithManifest:(PSTPermissionManifest *)manifest {
  if (!pst_application_model_begin_workflow(&_model)) {
    return;
  }
  PSTAuthorizationInjector *injector =
      [[PSTAuthorizationInjector alloc] initWithCredential:&_credential];
  PSTPermissionWorkflow *workflow =
      [[PSTPermissionWorkflow alloc] initWithInjector:injector manifest:manifest];
  self.workflow = workflow;

  [self updateTrustState];
  [self
      setBusyActivityTitle:@"Granting Permissions"
                    detail:@"System Settings may open while permissions are updated."];
  [self appendStatus:@"Starting the permission workflow."];
  __weak PSTAppDelegate *weak_self = self;
  [workflow
      runWithStatus:^(NSString *message) {
        [weak_self appendStatus:message];
        dispatch_async(dispatch_get_main_queue(), ^{
          PSTAppDelegate *strong_self = weak_self;
          if (strong_self != nil &&
              strong_self->_model.workflow == PST_WORKFLOW_RUNNING) {
            strong_self.activityDetail.stringValue = message;
          }
        });
      }
      completion:^(BOOL success, NSString *summary) {
        dispatch_async(dispatch_get_main_queue(), ^{
          PSTAppDelegate *strong_self = weak_self;
          if (strong_self == nil) {
            return;
          }
          pst_application_model_finish_workflow(&strong_self->_model, success);
          [strong_self appendStatus:summary];
          [strong_self
              appendStatus:success ? @"Permission workflow finished."
                                   : @"Permission workflow ended with failures; its "
                                      "validation rules were not broadened."];
          strong_self.workflow = nil;
          [strong_self updateTrustState];
        });
      }];
}

- (BOOL)windowShouldClose:(NSWindow *)sender {
  (void)sender;
  if (_model.workflow == PST_WORKFLOW_RUNNING) {
    [self appendStatus:@"Wait for the permission workflow to finish before closing."];
    [self setBusyActivityTitle:@"Permission Changes in Progress"
                        detail:
                            @"Wait for the workflow to finish before closing the app."];
    return NO;
  }
  return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
  (void)notification;
  [self.trustTimer invalidate];
  self.trustTimer = nil;
  pst_secure_buffer_destroy(&_credential);
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
  (void)sender;
  return YES;
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
  (void)app;
  return YES;
}

@end
