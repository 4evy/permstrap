#import <AppKit/AppKit.h>

#import "application/PSTPermissionConfirmationController.h"
#import "permissions/PSTPermissionManifest.h"

#include <assert.h>
#include <stdlib.h>

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

    PSTPermissionConfirmationController *controller =
        [[PSTPermissionConfirmationController alloc] initWithManifest:manifest];
    NSView *content = controller.window.contentView;
    assert(content != nil);
    if (getenv("PST_PERMISSION_UI_PREVIEW") != nullptr) {
      (void)[NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
      [NSApp finishLaunching];
      [controller.window setContentSize:controller.window.contentMinSize];
      [controller.window makeKeyAndOrderFront:nil];
      [NSApp activateIgnoringOtherApps:YES];
      [NSApp run];
      return 0;
    }

    assert(content.frame.size.width == 820);
    assert(content.frame.size.height == 570);
    assert(NSEqualSizes(controller.window.contentMinSize, NSMakeSize(820, 570)));
    [content layoutSubtreeIfNeeded];
    assert(content.frame.size.width == 820);
    assert(content.frame.size.height == 570);

    NSMutableArray<NSTextField *> *labels = [NSMutableArray array];
    PSTCollectLabels(content, labels);
    assert(PSTLabelsContain(labels, @"14 targets  •  9 permission types"));

    NSMutableArray<NSTableView *> *tables = [NSMutableArray array];
    PSTCollectTables(content, tables);
    assert(tables.count == 2);
    for (NSTableView *table in tables) {
      NSInteger rows = [table.dataSource numberOfRowsInTableView:table];
      assert(table.enclosingScrollView.frame.size.height == 299);
      if ([table.identifier isEqualToString:@"permissions"]) {
        assert(rows == 9);
        assert(table.enclosingScrollView.hasVerticalScroller);
        assert(table.rowHeight == 58);
        NSView *rowView = [table.delegate tableView:table
                                 viewForTableColumn:table.tableColumns.firstObject
                                                row:0];
        assert(rowView != nil);
        NSMutableArray<NSTextField *> *rowLabels = [NSMutableArray array];
        PSTCollectLabels(rowView, rowLabels);
        assert(PSTLabelsContain(rowLabels, manifest.services.firstObject.name));
        assert(PSTLabelsContain(rowLabels,
                                manifest.services.firstObject.serviceDescription));
        NSMutableArray<NSImageView *> *rowImages = [NSMutableArray array];
        PSTCollectImages(rowView, rowImages);
        assert(rowImages.count == 1);
        assert(rowImages.firstObject.image != nil);
      } else if ([table.identifier isEqualToString:@"targets"]) {
        assert(rows == 15);
        assert(table.enclosingScrollView.hasVerticalScroller);
        assert(table.rowHeight == 44);
      } else {
        assert(false);
      }
      assert(table.style == ([table.identifier isEqualToString:@"targets"]
                                 ? NSTableViewStyleInset
                                 : NSTableViewStyleFullWidth));
      assert(!table.usesAlternatingRowBackgroundColors);
      assert(table.gridStyleMask == NSTableViewGridNone);
    }

    NSMutableArray<NSButton *> *buttons = [NSMutableArray array];
    PSTCollectButtons(content, buttons);
    NSButton *cancel = PSTButtonNamed(buttons, @"Cancel");
    NSButton *grant = PSTButtonNamed(buttons, @"Grant Permissions");
    assert(cancel != nil);
    assert(grant != nil);
    assert(NSMaxY(cancel.frame) <= content.bounds.size.height);
    assert(NSMaxY(grant.frame) <= content.bounds.size.height);
    assert([cancel.keyEquivalent isEqualToString:@"\033"]);
    assert([grant.keyEquivalent isEqualToString:@"\r"]);
    assert(cancel.controlSize == NSControlSizeLarge);
    assert(grant.controlSize == NSControlSizeLarge);
  }
  return 0;
}
