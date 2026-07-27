#import <AVFoundation/AVFoundation.h>
#import <ApplicationServices/ApplicationServices.h>
#import <Contacts/Contacts.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <CoreLocation/CoreLocation.h>
#import <EventKit/EventKit.h>
#import <Foundation/Foundation.h>
#import <Photos/Photos.h>
#import <Speech/Speech.h>

#include "PSTVersion.h"
#include "probe/PSTProbeCommandLine.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static NSDictionary<NSString *, id> *pst_authorization_snapshot(void) {
  CLLocationManager *location_manager = [[CLLocationManager alloc] init];
  return @{
    @"pid" : @(getpid()),
    @"parentPid" : @(getppid()),
    @"camera" : @([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo]),
    @"microphone" :
        @([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio]),
    @"contacts" :
        @([CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts]),
    @"calendars" : @([EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent]),
    @"reminders" :
        @([EKEventStore authorizationStatusForEntityType:EKEntityTypeReminder]),
    @"photosReadWrite" :
        @([PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelReadWrite]),
    @"speechRecognition" : @([SFSpeechRecognizer authorizationStatus]),
    @"location" : @(location_manager.authorizationStatus),
    @"bluetooth" : @([CBManager authorization]),
    @"screenCapture" : @(CGPreflightScreenCaptureAccess()),
    @"inputMonitoring" : @(CGPreflightListenEventAccess()),
    @"accessibility" : @(AXIsProcessTrusted()),
  };
}

static NSString *pst_default_output_path(void) {
  NSArray<NSString *> *cache_paths =
      NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
  NSString *cache_root = cache_paths.firstObject != nil
                             ? cache_paths.firstObject
                             : [NSTemporaryDirectory() stringByStandardizingPath];
  return [[cache_root stringByAppendingPathComponent:@"dev.4evy.permstrap"]
      stringByAppendingPathComponent:@"GhosttyProbeStatus.json"];
}

static int pst_write_snapshot(NSString *output_path) {
  NSError *json_error = nil;
  NSData *json = [NSJSONSerialization
      dataWithJSONObject:pst_authorization_snapshot()
                 options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                   error:&json_error];
  if (json == nil) {
    (void)fprintf(stderr, "unable to encode status: %s\n",
                  json_error.localizedDescription.UTF8String);
    return EXIT_FAILURE;
  }

  (void)fwrite(json.bytes, 1, json.length, stdout);
  (void)fputc('\n', stdout);
  if (output_path == nil) {
    return EXIT_SUCCESS;
  }
  NSError *write_error = nil;
  NSString *output_directory = [output_path stringByDeletingLastPathComponent];
  if (![NSFileManager.defaultManager createDirectoryAtPath:output_directory
                               withIntermediateDirectories:YES
                                                attributes:nil
                                                     error:&write_error]) {
    (void)fprintf(stderr, "unable to create status directory: %s\n",
                  write_error.localizedDescription.UTF8String);
    return EXIT_FAILURE;
  }
  write_error = nil;
  if (![json writeToFile:output_path options:NSDataWritingAtomic error:&write_error]) {
    (void)fprintf(stderr, "unable to write status: %s\n",
                  write_error.localizedDescription.UTF8String);
    return EXIT_FAILURE;
  }
  return EXIT_SUCCESS;
}

int main(int argc, char *argv[]) {
  @autoreleasepool {
    PSTProbeCommandLine command = pst_probe_command_line_parse(argc, argv);
    if (command.mode == PST_PROBE_COMMAND_INVALID) {
      (void)fprintf(stderr, "%s: %s\n", argv[0],
                    pst_probe_command_line_error_description(command.error));
      (void)fprintf(stderr, "Try '%s --help' for more information.\n", argv[0]);
      return EXIT_FAILURE;
    }
    if (command.mode == PST_PROBE_COMMAND_HELP) {
      pst_probe_command_line_print_help(stdout, argv[0]);
      return EXIT_SUCCESS;
    }
    if (command.mode == PST_PROBE_COMMAND_VERSION) {
      (void)printf("permstrap-probe %s\n", PST_VERSION);
      return EXIT_SUCCESS;
    }

    NSString *output_path = pst_default_output_path();
    if (command.mode == PST_PROBE_COMMAND_WRITE_PATH) {
      output_path = [NSFileManager.defaultManager
          stringWithFileSystemRepresentation:command.output_path
                                      length:strlen(command.output_path)];
      if (output_path == nil) {
        (void)fprintf(stderr, "status JSON path is not valid UTF-8\n");
        return EXIT_FAILURE;
      }
    } else if (command.mode == PST_PROBE_COMMAND_WRITE_STDOUT) {
      output_path = nil;
    }
    return pst_write_snapshot(output_path);
  }
}
