#import "automation/PSTAutomaticFileDrag.h"

#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>

@interface PSTAutomaticDragDestinationView : NSView

@property(nonatomic, copy) NSURL *expectedURL;
@property(nonatomic) BOOL acceptedExpectedURL;

@end

@interface PSTAutomaticDragProbeWindow : NSWindow

@property(nonatomic, copy, nullable) dispatch_block_t returnHandler;

@end

@implementation PSTAutomaticDragProbeWindow

- (void)keyDown:(NSEvent *)event {
  if (event.keyCode == 36 && self.returnHandler != nil) {
    dispatch_block_t handler = self.returnHandler;
    self.returnHandler = nil;
    handler();
    return;
  }
  [super keyDown:event];
}

@end

@interface PSTAutomaticDragProbeTrigger : NSObject

@property(nonatomic, copy, nullable) dispatch_block_t handler;

- (void)runProbe:(id)sender;

@end

@implementation PSTAutomaticDragProbeTrigger

- (void)runProbe:(id)sender {
  (void)sender;
  if (self.handler == nil) {
    return;
  }
  dispatch_block_t handler = self.handler;
  self.handler = nil;
  handler();
}

@end

@implementation PSTAutomaticDragDestinationView

- (instancetype)initWithFrame:(NSRect)frame_rect {
  self = [super initWithFrame:frame_rect];
  if (self != nil) {
    [self registerForDraggedTypes:@[
      NSPasteboardTypeFileURL,
      NSPasteboardTypeURL,
      @"NSFilenamesPboardType",
    ]];
  }
  return self;
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
  (void)sender;
  self.layer.backgroundColor = NSColor.systemGreenColor.CGColor;
  return NSDragOperationCopy;
}

- (void)draggingExited:(nullable id<NSDraggingInfo>)sender {
  (void)sender;
  self.layer.backgroundColor = NSColor.systemBlueColor.CGColor;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
  NSDictionary<NSPasteboardReadingOptionKey, id> *options =
      @{NSPasteboardURLReadingFileURLsOnlyKey : @YES};
  NSArray *objects = [sender.draggingPasteboard readObjectsForClasses:@[ NSURL.class ]
                                                              options:options];
  for (id object in objects) {
    if ([object isKindOfClass:NSURL.class] &&
        [(NSURL *)object isEqual:self.expectedURL]) {
      self.acceptedExpectedURL = YES;
      return YES;
    }
  }
  return NO;
}

@end

static CGPoint PSTQuartzPointFromAppKitPoint(NSPoint point) {
  for (NSScreen *screen in NSScreen.screens) {
    if (!NSPointInRect(point, screen.frame)) {
      continue;
    }
    NSNumber *screen_number = screen.deviceDescription[@"NSScreenNumber"];
    if (screen_number == nil) {
      continue;
    }
    const CGRect quartz_bounds = CGDisplayBounds(screen_number.unsignedIntValue);
    return CGPointMake(quartz_bounds.origin.x + point.x - screen.frame.origin.x,
                       quartz_bounds.origin.y + quartz_bounds.size.height -
                           (point.y - screen.frame.origin.y));
  }
  NSScreen *main_screen = NSScreen.mainScreen;
  return CGPointMake(point.x, NSMaxY(main_screen.frame) - point.y);
}

int main(void) {
  @autoreleasepool {
    (void)fprintf(stderr, "post-event-access=%s\n",
                  CGPreflightPostEventAccess() ? "granted" : "not-granted");
    NSApplication *application = NSApplication.sharedApplication;
    application.activationPolicy = NSApplicationActivationPolicyRegular;

    PSTAutomaticDragProbeWindow *window = [[PSTAutomaticDragProbeWindow alloc]
        initWithContentRect:NSMakeRect(0.0, 0.0, 320.0, 220.0)
                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                    backing:NSBackingStoreBuffered
                      defer:NO];
    window.title = @"Automatic native drag probe — press Return";
    window.level = NSFloatingWindowLevel;
    PSTAutomaticDragDestinationView *destination =
        [[PSTAutomaticDragDestinationView alloc]
            initWithFrame:window.contentView.bounds];
    destination.wantsLayer = YES;
    destination.layer.backgroundColor = NSColor.systemBlueColor.CGColor;
    destination.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    PSTAutomaticDragProbeTrigger *trigger = [[PSTAutomaticDragProbeTrigger alloc] init];
    NSButton *run_button = [NSButton buttonWithTitle:@"Run isolated drag probe"
                                              target:trigger
                                              action:@selector(runProbe:)];
    run_button.frame = NSMakeRect(60.0, 135.0, 200.0, 34.0);
    [destination addSubview:run_button];
    NSURL *file_url = [NSURL fileURLWithPath:@"/System/Applications/Calculator.app"];
    destination.expectedURL = file_url;
    window.contentView = destination;
    [window center];
    [application activate];
    [window makeKeyAndOrderFront:nil];

    const NSPoint drop_point = NSMakePoint(NSMidX(destination.bounds), 55.0);
    const NSPoint window_point = [destination convertPoint:drop_point toView:nil];
    const NSPoint screen_point = [window convertPointToScreen:window_point];
    const CGPoint quartz_destination = PSTQuartzPointFromAppKitPoint(screen_point);
    __block int result = EXIT_FAILURE;
    dispatch_block_t start_probe = ^{
      dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        PSTAutomaticFileDrag *drag = [[PSTAutomaticFileDrag alloc] init];
        NSError *error = nil;
        BOOL completed = [drag dragFileURLs:@[ file_url ]
                              toQuartzPoint:quartz_destination
                                    timeout:5.0
                                      error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
          if (completed && destination.acceptedExpectedURL) {
            (void)puts("automatic native file drag accepted");
            result = EXIT_SUCCESS;
          } else {
            (void)fprintf(stderr, "automatic native file drag failed: %s\n",
                          error.localizedDescription.UTF8String);
          }
          [application stop:nil];
          NSEvent *wake_event =
              [NSEvent otherEventWithType:NSEventTypeApplicationDefined
                                 location:NSZeroPoint
                            modifierFlags:0
                                timestamp:0.0
                             windowNumber:0
                                  context:nil
                                  subtype:0
                                    data1:0
                                    data2:0];
          [application postEvent:wake_event atStart:NO];
        });
      });
    };
    window.returnHandler = start_probe;
    trigger.handler = start_probe;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
      if (getchar() != EOF) {
        dispatch_async(dispatch_get_main_queue(), ^{
          [trigger runProbe:nil];
        });
      }
    });
    [application run];
    return result;
  }
}
