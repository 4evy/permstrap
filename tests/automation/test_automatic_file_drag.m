#import "automation/PSTAutomaticFileDrag.h"

#include <assert.h>

static void test_file_url_writer_exposes_finder_compatible_payload(void) {
  NSURL *file_url = [NSURL fileURLWithPath:@"/System/Applications/Calculator.app"];
  PSTFileURLPasteboardWriter *writer =
      [[PSTFileURLPasteboardWriter alloc] initWithFileURL:file_url];
  NSPasteboard *pasteboard = [NSPasteboard pasteboardWithUniqueName];
  NSArray<NSPasteboardType> *types = [writer writableTypesForPasteboard:pasteboard];

  assert([types containsObject:NSPasteboardTypeFileURL]);
  assert([types containsObject:NSPasteboardTypeURL]);
  assert([types containsObject:NSPasteboardTypeString]);
  assert([types containsObject:@"com.apple.pasteboard.promised-file-url"]);
  assert([[writer pasteboardPropertyListForType:NSPasteboardTypeFileURL]
      isEqual:file_url.absoluteString]);
  assert([[writer pasteboardPropertyListForType:NSPasteboardTypeURL]
      isEqual:file_url.absoluteString]);
  assert([[writer pasteboardPropertyListForType:NSPasteboardTypeString]
      isEqual:file_url.path]);
}

int main(void) {
  @autoreleasepool {
    test_file_url_writer_exposes_finder_compatible_payload();
  }
  return 0;
}
