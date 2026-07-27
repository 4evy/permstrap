#import "application/PSTAboutWindowController.h"

#import "application/PSTUIComponents.h"

@implementation PSTAboutWindowController

static NSTextField *PSTAboutLabel(NSString *text) {
  NSTextField *label = PSTUILabel(text);
  label.alignment = NSTextAlignmentCenter;
  return label;
}

- (instancetype)init {
  NSWindow *window = [[NSWindow alloc]
      initWithContentRect:NSMakeRect(0, 0, 380, 310)
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  self = [super initWithWindow:window];
  if (self == nil) {
    return nil;
  }

  window.title = @"About Permstrap";
  window.restorable = NO;
  window.releasedWhenClosed = NO;
  [window center];

  NSView *content = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 380, 310)];
  window.contentView = content;

  NSImageView *icon = [[NSImageView alloc] initWithFrame:NSZeroRect];
  icon.translatesAutoresizingMaskIntoConstraints = NO;
  icon.image = NSApp.applicationIconImage;
  icon.imageScaling = NSImageScaleProportionallyUpOrDown;
  [icon setAccessibilityLabel:@"Permstrap"];
  [NSLayoutConstraint activateConstraints:@[
    [icon.widthAnchor constraintEqualToConstant:96.0],
    [icon.heightAnchor constraintEqualToConstant:96.0],
  ]];

  NSTextField *name = PSTAboutLabel(@"Permstrap");
  name.font = [NSFont systemFontOfSize:24.0 weight:NSFontWeightSemibold];

  NSString *version =
      [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
  NSString *build = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"];
  NSString *versionText = nil;
  if (version.length > 0 && build.length > 0) {
    versionText = [NSString stringWithFormat:@"Version %@ (%@)", version, build];
  } else if (version.length > 0) {
    versionText = [NSString stringWithFormat:@"Version %@", version];
  } else {
    versionText = @"macOS permission setup utility";
  }
  NSTextField *versionLabel = PSTAboutLabel(versionText);
  versionLabel.font = [NSFont systemFontOfSize:13.0];
  versionLabel.textColor = NSColor.secondaryLabelColor;

  NSTextField *credit = PSTAboutLabel(@"Created by 4evy");
  credit.font = [NSFont systemFontOfSize:15.0 weight:NSFontWeightSemibold];

  NSTextField *copyright = PSTAboutLabel(@"Copyright © 2026 4evy");
  copyright.font = [NSFont systemFontOfSize:11.0];
  copyright.textColor = NSColor.tertiaryLabelColor;

  NSStackView *stack =
      [NSStackView stackViewWithViews:@[ icon, name, versionLabel, credit, copyright ]];
  stack.translatesAutoresizingMaskIntoConstraints = NO;
  stack.orientation = NSUserInterfaceLayoutOrientationVertical;
  stack.alignment = NSLayoutAttributeCenterX;
  stack.spacing = 6.0;
  [stack setCustomSpacing:12.0 afterView:versionLabel];
  [stack setCustomSpacing:14.0 afterView:credit];
  [content addSubview:stack];
  [NSLayoutConstraint activateConstraints:@[
    [stack.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],
    [stack.centerYAnchor constraintEqualToAnchor:content.centerYAnchor constant:-2.0],
    [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:content.leadingAnchor
                                                     constant:24.0],
    [stack.trailingAnchor constraintLessThanOrEqualToAnchor:content.trailingAnchor
                                                   constant:-24.0],
  ]];
  return self;
}

@end
