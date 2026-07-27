#import <AppKit/AppKit.h>

#import "application/PSTAboutWindowController.h"
#import "application/PSTPermissionTargetsDocument.h"
#import "application/PSTPermissionTargetsEditorController.h"
#import "permissions/PSTPermissionManifest.h"

#include <assert.h>

@interface PSTPermissionTargetsEditorController (Testing)

- (void)updateEditorPresentation;

@end

static void PSTCollectTables(NSView *view, NSMutableArray<NSTableView *> *tables) {
  if ([view isKindOfClass:NSTableView.class]) {
    [tables addObject:(NSTableView *)view];
  }
  for (NSView *subview in view.subviews) {
    PSTCollectTables(subview, tables);
  }
}

static void PSTCollectButtons(NSView *view, NSMutableArray<NSButton *> *buttons) {
  if ([view isKindOfClass:NSButton.class]) {
    [buttons addObject:(NSButton *)view];
  }
  for (NSView *subview in view.subviews) {
    PSTCollectButtons(subview, buttons);
  }
}

static void PSTCollectLabels(NSView *view, NSMutableArray<NSTextField *> *labels) {
  if ([view isKindOfClass:NSTextField.class]) {
    [labels addObject:(NSTextField *)view];
  }
  for (NSView *subview in view.subviews) {
    PSTCollectLabels(subview, labels);
  }
}

static void PSTCollectImages(NSView *view, NSMutableArray<NSImageView *> *images) {
  if ([view isKindOfClass:NSImageView.class]) {
    [images addObject:(NSImageView *)view];
  }
  for (NSView *subview in view.subviews) {
    PSTCollectImages(subview, images);
  }
}

static NSButton *PSTButtonNamed(NSArray<NSButton *> *buttons, NSString *title) {
  for (NSButton *button in buttons) {
    if ([button.title isEqualToString:title]) {
      return button;
    }
  }
  return nil;
}

static BOOL PSTLabelsContain(NSArray<NSTextField *> *labels, NSString *text) {
  for (NSTextField *label in labels) {
    if ([label.stringValue isEqualToString:text]) {
      return YES;
    }
  }
  return NO;
}

static NSView *PSTViewNamed(NSView *view, NSUserInterfaceItemIdentifier identifier) {
  if ([view.identifier isEqualToString:identifier]) {
    return view;
  }
  for (NSView *subview in view.subviews) {
    NSView *match = PSTViewNamed(subview, identifier);
    if (match != nil) {
      return match;
    }
  }
  return nil;
}

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    assert(argc == 3);
    (void)NSApplication.sharedApplication;
    NSString *catalogPath = [NSString stringWithUTF8String:argv[1]];
    NSString *targetsPath = [NSString stringWithUTF8String:argv[2]];
    assert(catalogPath != nil);
    assert(targetsPath != nil);
    NSData *catalogData = [NSData dataWithContentsOfFile:catalogPath];
    NSData *targetsData = [NSData dataWithContentsOfFile:targetsPath];
    assert(catalogData != nil);
    assert(targetsData != nil);
    NSError *error = nil;
    PSTPermissionManifest *manifest =
        [PSTPermissionManifest manifestWithPermissionCatalogData:catalogData
                                                     targetsData:targetsData
                                                           error:&error];
    assert(manifest != nil);
    assert(error == nil);

    PSTPermissionTargetsEditorController *editor =
        [[PSTPermissionTargetsEditorController alloc]
            initWithServices:manifest.services];
    NSView *editorContent = editor.window.contentView;
    assert(editorContent != nil);
    [editorContent layoutSubtreeIfNeeded];
    assert(editorContent.frame.size.width >= 900);
    assert(editorContent.frame.size.height >= 620);

    editor.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    NSView *editorDetail = PSTViewNamed(editorContent, @"editor-detail");
    assert(editorDetail != nil);
    NSArray<NSAppearanceName> *appearanceNames =
        @[ NSAppearanceNameDarkAqua, NSAppearanceNameAqua ];
    NSAppearanceName matchedAppearance = [editorDetail.effectiveAppearance
        bestMatchFromAppearancesWithNames:appearanceNames];
    assert([matchedAppearance isEqualToString:NSAppearanceNameDarkAqua]);
    [editorDetail updateLayer];
    __block CGColorRef expectedDetailBackground = nil;
    [editorDetail.effectiveAppearance performAsCurrentDrawingAppearance:^{
      expectedDetailBackground =
          CGColorCreateCopy(NSColor.windowBackgroundColor.CGColor);
    }];
    assert(expectedDetailBackground != nil);
    assert(CGColorEqualToColor(editorDetail.layer.backgroundColor,
                               expectedDetailBackground));
    CGColorRelease(expectedDetailBackground);

    NSMutableArray<NSTableView *> *tables = [NSMutableArray array];
    PSTCollectTables(editorContent, tables);
    assert(tables.count == 1);
    NSTableView *targetsTable = tables.firstObject;
    assert([targetsTable.identifier isEqualToString:@"editor-targets"]);
    assert([targetsTable.dataSource numberOfRowsInTableView:targetsTable] == 0);

    NSMutableArray<NSButton *> *buttons = [NSMutableArray array];
    PSTCollectButtons(editorContent, buttons);
    assert(PSTButtonNamed(buttons, @"Add Application…") != nil);
    assert(PSTButtonNamed(buttons, @"Add Executable…") != nil);
    assert(PSTButtonNamed(buttons, @"Cancel") != nil);
    NSButton *save = PSTButtonNamed(buttons, @"Save…");
    NSButton *apply = PSTButtonNamed(buttons, @"Apply");
    NSButton *saveAndApply = PSTButtonNamed(buttons, @"Save & Apply…");
    assert(save != nil);
    assert(apply != nil);
    assert(saveAndApply != nil);
    assert(!save.enabled);
    assert(!apply.enabled);
    assert(!saveAndApply.enabled);
    assert([saveAndApply.keyEquivalent isEqualToString:@"\r"]);

    NSMutableArray<NSImageView *> *images = [NSMutableArray array];
    PSTCollectImages(editorContent, images);
    NSUInteger configuredImages = 0;
    for (NSImageView *imageView in images) {
      if (imageView.image != nil) {
        configuredImages++;
      }
    }
    assert(configuredImages >= manifest.services.count + 3);

    PSTPermissionTargetDraft *target = [[PSTPermissionTargetDraft alloc]
        initWithIdentifier:@"tool:permission-card-test"
                      name:@"Permission Card Test"
                      kind:PSTPermissionTargetKindExecutable
         bundleIdentifiers:@[]
            pathCandidates:@[ @"/usr/bin/true" ]
                  required:NO
        serviceIdentifiers:@[]];
    NSMutableArray<PSTPermissionTargetDraft *> *editorTargets =
        [editor valueForKey:@"targets"];
    assert(editorTargets != nil);
    [editorTargets addObject:target];
    [targetsTable reloadData];
    [targetsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0]
              byExtendingSelection:NO];
    [editor updateEditorPresentation];
    [editorContent layoutSubtreeIfNeeded];

    NSButton *accessibilityCheckbox = nil;
    for (NSButton *button in buttons) {
      if ([button.accessibilityLabel isEqualToString:@"Accessibility permission"]) {
        accessibilityCheckbox = button;
        break;
      }
    }
    assert(accessibilityCheckbox != nil);
    NSView *permissionCard = accessibilityCheckbox.superview;
    while (permissionCard != nil && ![permissionCard isKindOfClass:NSBox.class]) {
      permissionCard = permissionCard.superview;
    }
    assert(permissionCard != nil);
    NSMutableArray<NSTextField *> *permissionLabels = [NSMutableArray array];
    PSTCollectLabels(permissionCard, permissionLabels);
    NSTextField *accessibilityLabel = nil;
    for (NSTextField *label in permissionLabels) {
      if ([label.stringValue isEqualToString:@"Accessibility"]) {
        accessibilityLabel = label;
        break;
      }
    }
    assert(accessibilityLabel != nil);
    NSPoint labelCenter =
        [permissionCard convertPoint:NSMakePoint(NSMidX(accessibilityLabel.bounds),
                                                 NSMidY(accessibilityLabel.bounds))
                            fromView:accessibilityLabel];
    assert([permissionCard hitTest:labelCenter] == permissionCard);
    NSMutableArray<NSImageView *> *permissionCardImages = [NSMutableArray array];
    PSTCollectImages(permissionCard, permissionCardImages);
    NSImageView *permissionIcon = permissionCardImages.firstObject;
    assert(permissionIcon != nil);
    NSPoint iconCenter =
        [permissionCard convertPoint:NSMakePoint(NSMidX(permissionIcon.bounds),
                                                 NSMidY(permissionIcon.bounds))
                            fromView:permissionIcon];
    assert([permissionCard hitTest:iconCenter] == permissionCard);
    assert(accessibilityCheckbox.state == NSControlStateValueOff);
    NSEvent *cardClick = [NSEvent mouseEventWithType:NSEventTypeLeftMouseDown
                                            location:NSZeroPoint
                                       modifierFlags:0
                                           timestamp:0
                                        windowNumber:editor.window.windowNumber
                                             context:nil
                                         eventNumber:1
                                          clickCount:1
                                            pressure:1.0];
    assert(cardClick != nil);
    [permissionCard mouseDown:cardClick];
    assert(accessibilityCheckbox.state == NSControlStateValueOn);
    assert([target.serviceIdentifiers containsObject:@"accessibility"]);
    assert(save.enabled);
    assert(apply.enabled);
    assert(saveAndApply.enabled);

    PSTAboutWindowController *about = [[PSTAboutWindowController alloc] init];
    NSWindow *aboutWindow = about.window;
    NSView *aboutContent = aboutWindow.contentView;
    assert(aboutWindow != nil);
    assert(aboutContent != nil);
    [aboutContent layoutSubtreeIfNeeded];
    assert([aboutWindow.title isEqualToString:@"About Permstrap"]);
    assert(aboutContent.frame.size.width == 380);
    assert(aboutContent.frame.size.height == 310);
    NSMutableArray<NSTextField *> *labels = [NSMutableArray array];
    PSTCollectLabels(aboutContent, labels);
    assert(PSTLabelsContain(labels, @"Permstrap"));
    assert(PSTLabelsContain(labels, @"Created by 4evy"));
    assert(PSTLabelsContain(labels, @"Copyright © 2026 4evy"));
  }
  return 0;
}
