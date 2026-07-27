#import "application/PSTUIComponents.h"

@implementation PSTUIFlippedView

- (BOOL)isFlipped {
  return YES;
}

@end

@interface PSTUIGroupPanelView : PSTUIFlippedView
@end

@implementation PSTUIGroupPanelView

- (instancetype)initWithFrame:(NSRect)frameRect {
  self = [super initWithFrame:frameRect];
  if (self != nil) {
    self.wantsLayer = YES;
  }
  return self;
}

- (BOOL)wantsUpdateLayer {
  return YES;
}

- (void)updateLayer {
  CALayer *layer = self.layer;
  if (layer == nil) {
    return;
  }
  [self.effectiveAppearance performAsCurrentDrawingAppearance:^{
    layer.backgroundColor = NSColor.controlBackgroundColor.CGColor;
    layer.borderColor = [NSColor.separatorColor colorWithAlphaComponent:0.75].CGColor;
  }];
  layer.borderWidth = 1.0;
  layer.cornerRadius = 10.0;
  layer.masksToBounds = YES;
}

- (void)viewDidChangeEffectiveAppearance {
  [super viewDidChangeEffectiveAppearance];
  self.needsDisplay = YES;
}

@end

NSTextField *PSTUILabel(NSString *text) {
  NSTextField *label = [NSTextField labelWithString:text];
  label.translatesAutoresizingMaskIntoConstraints = NO;
  [label
      setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                               forOrientation:NSLayoutConstraintOrientationHorizontal];
  return label;
}

NSImage *PSTUISymbol(NSString *name, NSString *accessibilityDescription,
                     CGFloat pointSize, NSFontWeight weight) {
  NSImage *image = [NSImage imageWithSystemSymbolName:name
                             accessibilityDescription:accessibilityDescription];
  if (image == nil) {
    image = [[NSImage alloc] initWithSize:NSMakeSize(pointSize, pointSize)];
  }
  NSImageSymbolConfiguration *configuration =
      [NSImageSymbolConfiguration configurationWithPointSize:pointSize weight:weight];
  NSImage *configuredImage = [image imageWithSymbolConfiguration:configuration];
  return configuredImage != nil ? configuredImage : image;
}

NSImageView *PSTUISymbolView(NSString *name, NSString *accessibilityDescription,
                             CGFloat pointSize, NSColor *tint) {
  NSImageView *imageView = [[NSImageView alloc] initWithFrame:NSZeroRect];
  imageView.translatesAutoresizingMaskIntoConstraints = NO;
  imageView.image =
      PSTUISymbol(name, accessibilityDescription, pointSize, NSFontWeightMedium);
  imageView.contentTintColor = tint;
  imageView.imageScaling = NSImageScaleProportionallyDown;
  [imageView setAccessibilityLabel:accessibilityDescription];
  [NSLayoutConstraint activateConstraints:@[
    [imageView.widthAnchor constraintEqualToConstant:pointSize + 4.0],
    [imageView.heightAnchor constraintEqualToConstant:pointSize + 4.0],
  ]];
  return imageView;
}

NSView *PSTUIFlexibleSpace(void) {
  NSView *space = [[NSView alloc] initWithFrame:NSZeroRect];
  space.translatesAutoresizingMaskIntoConstraints = NO;
  [space setContentHuggingPriority:NSLayoutPriorityDefaultLow
                    forOrientation:NSLayoutConstraintOrientationHorizontal];
  [space
      setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                               forOrientation:NSLayoutConstraintOrientationHorizontal];
  return space;
}

NSStackView *PSTUIVerticalStack(NSArray<NSView *> *views, CGFloat spacing) {
  NSStackView *stack = [NSStackView stackViewWithViews:views];
  stack.translatesAutoresizingMaskIntoConstraints = NO;
  stack.orientation = NSUserInterfaceLayoutOrientationVertical;
  stack.alignment = NSLayoutAttributeLeading;
  stack.spacing = spacing;
  return stack;
}

void PSTUIConfigureButton(NSButton *button, BOOL primary) {
  button.bezelStyle = NSBezelStyleFlexiblePush;
  if (@available(macOS 26.0, *)) {
    button.tintProminence =
        primary ? NSTintProminencePrimary : NSTintProminenceAutomatic;
  }
}

NSBox *PSTUISeparator(void) {
  NSBox *separator = [[NSBox alloc] initWithFrame:NSZeroRect];
  separator.translatesAutoresizingMaskIntoConstraints = NO;
  separator.boxType = NSBoxSeparator;
  return separator;
}

NSView *PSTUIGroupPanel(NSTextField *heading, NSView *content) {
  PSTUIGroupPanelView *panel = [[PSTUIGroupPanelView alloc] initWithFrame:NSZeroRect];
  panel.translatesAutoresizingMaskIntoConstraints = NO;

  NSView *header = [[NSView alloc] initWithFrame:NSZeroRect];
  header.translatesAutoresizingMaskIntoConstraints = NO;
  NSBox *separator = PSTUISeparator();
  [header addSubview:heading];
  [panel addSubview:header];
  [panel addSubview:separator];
  [panel addSubview:content];

  [NSLayoutConstraint activateConstraints:@[
    [header.topAnchor constraintEqualToAnchor:panel.topAnchor constant:1.0],
    [header.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:1.0],
    [header.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-1.0],
    [header.heightAnchor constraintEqualToConstant:38.0],
    [heading.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:13.0],
    [heading.trailingAnchor constraintLessThanOrEqualToAnchor:header.trailingAnchor
                                                     constant:-13.0],
    [heading.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
    [separator.topAnchor constraintEqualToAnchor:header.bottomAnchor],
    [separator.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:1.0],
    [separator.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor
                                             constant:-1.0],
    [separator.heightAnchor constraintEqualToConstant:1.0],
    [content.topAnchor constraintEqualToAnchor:separator.bottomAnchor],
    [content.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:1.0],
    [content.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-1.0],
    [content.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-1.0],
  ]];
  return panel;
}

NSString *PSTUICountPhrase(NSUInteger count, NSString *singular, NSString *plural) {
  return [NSString
      stringWithFormat:@"%lu %@", (unsigned long)count, count == 1 ? singular : plural];
}

NSImage *PSTUITargetIcon(NSArray<NSString *> *pathCandidates, BOOL executable,
                         CGFloat size) {
  NSFileManager *fileManager = NSFileManager.defaultManager;
  for (NSString *candidate in pathCandidates) {
    NSString *expanded = candidate.stringByExpandingTildeInPath;
    if (![fileManager fileExistsAtPath:expanded]) {
      continue;
    }
    NSImage *icon = [[NSWorkspace.sharedWorkspace iconForFile:expanded] copy];
    if (icon != nil) {
      icon.size = NSMakeSize(size, size);
      return icon;
    }
  }

  NSImage *fallback = executable ? PSTUISymbol(@"terminal.fill", @"Command-line tool",
                                               size, NSFontWeightRegular)
                                 : [NSImage imageNamed:NSImageNameApplicationIcon];
  if (fallback == nil) {
    fallback = [[NSImage alloc] initWithSize:NSMakeSize(size, size)];
  } else {
    fallback = [fallback copy];
  }
  fallback.size = NSMakeSize(size, size);
  return fallback;
}
