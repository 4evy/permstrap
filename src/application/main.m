#import <AppKit/AppKit.h>

#import "application/PSTAppDelegate.h"
#import "application/PSTCommandLine.h"
#import "application/PSTUIComponents.h"
#import "automation/PSTAXUtilities.h"
#import "automation/PSTSystemSettingsAutomator.h"
#import "permissions/PSTPermissionManifest.h"
#import "policy/PSTRuntimePolicy.h"
#import "security/PSTSecureBuffer.h"
#import "security/PSTTrustedProcess.h"

#include "PSTVersion.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>

static void pst_disable_core_dumps(void) {
  struct rlimit limit = {.rlim_cur = 0, .rlim_max = 0};
  (void)setrlimit(RLIMIT_CORE, &limit);
}

static NSMenuItem *pst_menu_item(NSString *title, SEL action,
                                 NSString *key_equivalent) {
  NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title
                                                action:action
                                         keyEquivalent:key_equivalent];
  item.target = nil;
  return item;
}

static NSMenuItem *pst_symbol_menu_item(NSString *title, SEL action,
                                        NSString *key_equivalent, NSString *symbol) {
  NSMenuItem *item = pst_menu_item(title, action, key_equivalent);
  item.image = PSTUISymbol(symbol, title, 13.0, NSFontWeightRegular);
  return item;
}

static void pst_install_application_menu(NSApplication *application,
                                         PSTAppDelegate *delegate) {
  NSString *bundle_name =
      [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleDisplayName"];
  NSString *application_name = bundle_name.length > 0 ? bundle_name : @"Permstrap";
  NSMenu *main_menu = [[NSMenu alloc] initWithTitle:@""];

  NSMenuItem *application_item = [[NSMenuItem alloc] initWithTitle:application_name
                                                            action:nil
                                                     keyEquivalent:@""];
  NSMenu *application_menu = [[NSMenu alloc] initWithTitle:application_name];
  NSMenuItem *about_item =
      pst_symbol_menu_item([@"About " stringByAppendingString:application_name],
                           @selector(showAboutWindow:), @"", @"info.circle");
  about_item.target = delegate;
  [application_menu addItem:about_item];
  [application_menu addItem:NSMenuItem.separatorItem];

  NSMenuItem *services_item = [[NSMenuItem alloc] initWithTitle:@"Services"
                                                         action:nil
                                                  keyEquivalent:@""];
  NSMenu *services_menu = [[NSMenu alloc] initWithTitle:@"Services"];
  services_item.submenu = services_menu;
  [application_menu addItem:services_item];
  application.servicesMenu = services_menu;
  [application_menu addItem:NSMenuItem.separatorItem];

  [application_menu
      addItem:pst_symbol_menu_item([@"Hide " stringByAppendingString:application_name],
                                   @selector(hide:), @"h", @"eye.slash")];
  NSMenuItem *hide_others = pst_symbol_menu_item(
      @"Hide Others", @selector(hideOtherApplications:), @"h", @"eye.slash.fill");
  hide_others.keyEquivalentModifierMask =
      NSEventModifierFlagCommand | NSEventModifierFlagOption;
  [application_menu addItem:hide_others];
  [application_menu
      addItem:pst_symbol_menu_item(@"Show All", @selector(unhideAllApplications:), @"",
                                   @"eye")];
  [application_menu addItem:NSMenuItem.separatorItem];

  NSMenuItem *quit_item =
      pst_symbol_menu_item([@"Quit " stringByAppendingString:application_name],
                           @selector(terminate:), @"q", @"power");
  [application_menu addItem:quit_item];
  application_item.submenu = application_menu;
  [main_menu addItem:application_item];

  NSMenuItem *file_item = [[NSMenuItem alloc] initWithTitle:@"File"
                                                     action:nil
                                              keyEquivalent:@""];
  NSMenu *file_menu = [[NSMenu alloc] initWithTitle:@"File"];
  NSMenuItem *new_targets = pst_symbol_menu_item(
      @"New Permission Targets…", @selector(createTargets:), @"n", @"doc.badge.plus");
  new_targets.target = delegate;
  [file_menu addItem:new_targets];
  NSMenuItem *open_targets = pst_symbol_menu_item(
      @"Open Permission Targets…", @selector(chooseTargets:), @"o", @"folder");
  open_targets.target = delegate;
  [file_menu addItem:open_targets];
  [file_menu addItem:NSMenuItem.separatorItem];
  [file_menu addItem:pst_symbol_menu_item(@"Close Window", @selector(performClose:),
                                          @"w", @"xmark")];
  file_item.submenu = file_menu;
  [main_menu addItem:file_item];

  NSMenuItem *edit_item = [[NSMenuItem alloc] initWithTitle:@"Edit"
                                                     action:nil
                                              keyEquivalent:@""];
  NSMenu *edit_menu = [[NSMenu alloc] initWithTitle:@"Edit"];
  [edit_menu addItem:pst_symbol_menu_item(@"Undo", @selector(undo:), @"z",
                                          @"arrow.uturn.backward")];
  NSMenuItem *redo_item =
      pst_symbol_menu_item(@"Redo", @selector(redo:), @"Z", @"arrow.uturn.forward");
  redo_item.keyEquivalentModifierMask =
      NSEventModifierFlagCommand | NSEventModifierFlagShift;
  [edit_menu addItem:redo_item];
  [edit_menu addItem:NSMenuItem.separatorItem];
  [edit_menu addItem:pst_symbol_menu_item(@"Cut", @selector(cut:), @"x", @"scissors")];
  [edit_menu addItem:pst_symbol_menu_item(@"Copy", @selector(copy:), @"c",
                                          @"document.on.document")];
  [edit_menu
      addItem:pst_symbol_menu_item(@"Paste", @selector(paste:), @"v", @"clipboard")];
  [edit_menu
      addItem:pst_symbol_menu_item(@"Delete", @selector(delete:), @"", @"delete.left")];
  [edit_menu addItem:NSMenuItem.separatorItem];
  [edit_menu addItem:pst_symbol_menu_item(@"Select All", @selector(selectAll:), @"a",
                                          @"selection.pin.in.out")];
  edit_item.submenu = edit_menu;
  [main_menu addItem:edit_item];

  NSMenuItem *window_item = [[NSMenuItem alloc] initWithTitle:@"Window"
                                                       action:nil
                                                keyEquivalent:@""];
  NSMenu *window_menu = [[NSMenu alloc] initWithTitle:@"Window"];
  [window_menu addItem:pst_symbol_menu_item(@"Minimize", @selector(performMiniaturize:),
                                            @"m", @"minus")];
  [window_menu addItem:pst_symbol_menu_item(@"Zoom", @selector(performZoom:), @"",
                                            @"arrow.up.left.and.arrow.down.right")];
  [window_menu addItem:NSMenuItem.separatorItem];
  NSMenuItem *full_screen =
      pst_symbol_menu_item(@"Enter Full Screen", @selector(toggleFullScreen:), @"f",
                           @"arrow.up.left.and.arrow.down.right");
  full_screen.keyEquivalentModifierMask =
      NSEventModifierFlagCommand | NSEventModifierFlagControl;
  [window_menu addItem:full_screen];
  [window_menu addItem:NSMenuItem.separatorItem];
  [window_menu
      addItem:pst_symbol_menu_item(@"Bring All to Front", @selector(arrangeInFront:),
                                   @"", @"rectangle.on.rectangle")];
  window_item.submenu = window_menu;
  [main_menu addItem:window_item];
  application.windowsMenu = window_menu;

  application.mainMenu = main_menu;
}

static bool pst_load_runtime_policy(const char *path) {
  NSURL *URL = nil;
  if (path != nullptr) {
    NSString *filePath =
        [NSFileManager.defaultManager stringWithFileSystemRepresentation:path
                                                                  length:strlen(path)];
    if (filePath == nil) {
      (void)fprintf(stderr, "runtime policy path is not valid UTF-8\n");
      return false;
    }
    URL = [NSURL fileURLWithPath:[filePath stringByExpandingTildeInPath]];
  }
  NSError *error = nil;
  if (!PSTLoadRuntimePolicy(URL, &error)) {
    NSString *description = error.localizedDescription;
    (void)fprintf(stderr, "runtime policy failed validation: %s\n",
                  (description != nil ? description : @"unknown runtime policy error")
                      .UTF8String);
    return false;
  }
  return true;
}

static NSURL *_Nullable pst_file_url(const char *path, const char *label) {
  if (path == nullptr) {
    return nil;
  }
  NSString *filePath =
      [NSFileManager.defaultManager stringWithFileSystemRepresentation:path
                                                                length:strlen(path)];
  if (filePath == nil) {
    (void)fprintf(stderr, "%s path is not valid UTF-8\n", label);
    return nil;
  }
  return [NSURL fileURLWithPath:[filePath stringByExpandingTildeInPath]];
}

static int pst_self_check(NSURL *_Nullable targetsURL) {
  constexpr size_t locked_memory_probe_capacity = 64;
  PSTSecureBuffer buffer;
  if (!pst_secure_buffer_init(&buffer, locked_memory_probe_capacity)) {
    (void)fprintf(stderr, "locked-memory self-check failed\n");
    return EXIT_FAILURE;
  }
  pst_secure_buffer_destroy(&buffer);

  NSError *manifest_error = nil;
  PSTPermissionManifest *manifest = nil;
  if (targetsURL != nil) {
    NSURL *configurationURL = (NSURL *_Nonnull)targetsURL;
    manifest = [PSTPermissionManifest bundledManifestWithTargetsURL:configurationURL
                                                              error:&manifest_error];
  } else {
    manifest = [PSTPermissionManifest bundledCatalogWithError:&manifest_error];
  }
  if (manifest == nil) {
    NSString *description = manifest_error.localizedDescription;
    (void)fprintf(
        stderr, "permission manifest failed validation: %s\n",
        (description != nil ? description : @"unknown manifest error").UTF8String);
    return EXIT_FAILURE;
  }
  NSSet<NSNumber *> *supported_modes = PSTSystemSettingsAutomator.supportedServiceModes;
  for (PSTPermissionService *service in manifest.services) {
    if (![supported_modes containsObject:@(service.mode)]) {
      (void)fprintf(stderr, "permission manifest mode has no execution strategy: %s\n",
                    service.modeIdentifier.UTF8String);
      return EXIT_FAILURE;
    }
  }
  (void)printf("bundle=%s accessibility=%s post-events=%s locked-memory=ok catalog=ok "
               "runtime-policy=ok strategies=ok%s\n",
               NSBundle.mainBundle.bundleIdentifier.UTF8String,
               pst_ax_is_trusted(false) ? "granted" : "not-granted",
               CGPreflightPostEventAccess() ? "granted" : "not-granted",
               targetsURL != nil ? " targets=ok" : "");
  return EXIT_SUCCESS;
}

static int pst_dump_ax_tree(pid_t process_identifier) {
  if (!pst_ax_is_trusted(false)) {
    (void)fprintf(stderr, "Accessibility permission is not granted\n");
    return EXIT_FAILURE;
  }
  AXUIElementRef application = pst_ax_copy_application(process_identifier);
  if (application == nullptr) {
    (void)fprintf(stderr, "unable to create accessibility element\n");
    return EXIT_FAILURE;
  }
  CFStringRef treeDescription = pst_ax_copy_tree_description(application);
  CFRelease(application);
  NSString *tree =
      treeDescription != nullptr ? CFBridgingRelease(treeDescription) : @"";
  (void)fputs(tree.UTF8String, stdout);
  return EXIT_SUCCESS;
}

static int pst_verify_authorization_agent(pid_t process_identifier) {
  NSError *error = nil;
  if (!PSTValidateTrustedProcess(process_identifier, 0, &error)) {
    NSString *description = error.localizedDescription;
    (void)fprintf(stderr, "%s\n",
                  (description != nil ? description : @"trusted UI identity rejected")
                      .UTF8String);
    return EXIT_FAILURE;
  }
  (void)printf("authorization-agent=%d identity=valid\n", process_identifier);
  return EXIT_SUCCESS;
}

int main(int argc, char *argv[]) {
  pst_disable_core_dumps();
  @autoreleasepool {
    PSTCommandLine command = pst_command_line_parse(argc, argv);
    if (command.mode == PST_COMMAND_INVALID) {
      (void)fprintf(stderr, "%s: %s\n", argv[0],
                    pst_command_line_error_description(command.error));
      (void)fprintf(stderr, "Try '%s --help' for more information.\n", argv[0]);
      return EXIT_FAILURE;
    }
    if (command.mode == PST_COMMAND_HELP) {
      pst_command_line_print_help(stdout, argv[0]);
      return EXIT_SUCCESS;
    }
    if (command.mode == PST_COMMAND_VERSION) {
      (void)printf("permstrap %s\n", PST_VERSION);
      return EXIT_SUCCESS;
    }
    if (!pst_load_runtime_policy(command.runtime_policy_path)) {
      return EXIT_FAILURE;
    }
    NSURL *targetsURL = pst_file_url(command.targets_path, "permission targets");
    if (command.targets_path != nullptr && targetsURL == nil) {
      return EXIT_FAILURE;
    }
    if (command.mode == PST_COMMAND_SELF_CHECK) {
      return pst_self_check(targetsURL);
    }
    if (command.mode == PST_COMMAND_DUMP_AX) {
      return pst_dump_ax_tree(command.process_identifier);
    }
    if (command.mode == PST_COMMAND_VERIFY_AGENT) {
      return pst_verify_authorization_agent(command.process_identifier);
    }

    NSApplication *application = NSApplication.sharedApplication;
    (void)[application setActivationPolicy:NSApplicationActivationPolicyRegular];
    PSTAppDelegate *delegate =
        [[PSTAppDelegate alloc] initWithCredentialArgument:command.password
                                                targetsURL:targetsURL];
    application.delegate = delegate;
    pst_install_application_menu(application, delegate);
    [application finishLaunching];
    [delegate start];
    [application run];
    (void)delegate;
  }
  return EXIT_SUCCESS;
}
