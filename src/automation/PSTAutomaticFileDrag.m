#import "automation/PSTAutomaticFileDrag.h"

#include <math.h>
#include <unistd.h>

NSErrorDomain const PSTAutomaticFileDragErrorDomain =
    @"dev.4evy.permstrap.automatic-file-drag";

typedef struct PSTAutomaticDragConfiguration {
  CGFloat source_window_size;
  CGFloat image_size;
  NSUInteger motion_step_count;
  useconds_t session_settle_microseconds;
  useconds_t motion_step_microseconds;
  useconds_t mouse_down_settle_microseconds;
  useconds_t mouse_drag_settle_microseconds;
  NSPoint synthetic_drag_event_offset;
  int64_t cancellation_wait_nanoseconds;
} PSTAutomaticDragConfiguration;

static const PSTAutomaticDragConfiguration PST_AUTOMATIC_DRAG_CONFIGURATION = {
    .source_window_size = 18.0,
    .image_size = 48.0,
    .motion_step_count = 28,
    .session_settle_microseconds = 75'000,
    .motion_step_microseconds = 8'000,
    .mouse_down_settle_microseconds = 30'000,
    .mouse_drag_settle_microseconds = 35'000,
    .synthetic_drag_event_offset = {7.0, 1.0},
    .cancellation_wait_nanoseconds = 250 * NSEC_PER_MSEC,
};

static NSPasteboardType const PSTPromisedFileURLPasteboardType =
    @"com.apple.pasteboard.promised-file-url";
static NSPasteboardType const PSTFilenamesPasteboardType = @"NSFilenamesPboardType";
static NSString *const PSTScreenNumberDeviceDescriptionKey = @"NSScreenNumber";

static NSError *PSTAutomaticDragError(PSTAutomaticFileDragError code,
                                      NSString *description) {
  return [NSError errorWithDomain:PSTAutomaticFileDragErrorDomain
                             code:code
                         userInfo:@{NSLocalizedDescriptionKey : description}];
}

@interface PSTFileURLPasteboardWriter ()

@property(nonatomic, copy) NSURL *fileURL;

@end

@implementation PSTFileURLPasteboardWriter

- (instancetype)initWithFileURL:(NSURL *)file_url {
  self = [super init];
  if (self != nil) {
    _fileURL = [file_url copy];
  }
  return self;
}

- (NSArray<NSPasteboardType> *)writableTypesForPasteboard:(NSPasteboard *)pasteboard {
  (void)pasteboard;
  return @[
    NSPasteboardTypeFileURL,
    NSPasteboardTypeURL,
    PSTPromisedFileURLPasteboardType,
    NSPasteboardTypeString,
  ];
}

- (nullable id)pasteboardPropertyListForType:(NSPasteboardType)type {
  if ([type isEqualToString:NSPasteboardTypeFileURL] ||
      [type isEqualToString:NSPasteboardTypeURL] ||
      [type isEqualToString:PSTPromisedFileURLPasteboardType]) {
    return self.fileURL.absoluteString;
  }
  if ([type isEqualToString:PSTFilenamesPasteboardType]) {
    NSString *path = self.fileURL.path;
    return path != nil ? @[ path ] : nil;
  }
  if ([type isEqualToString:NSPasteboardTypeString]) {
    return self.fileURL.path;
  }
  return nil;
}

@end

@class PSTAutomaticFileDrag;

@interface PSTAutomaticFileDragSourceView : NSView

@property(nonatomic, weak) PSTAutomaticFileDrag *dragController;

@end

@interface PSTAutomaticFileDrag () <NSDraggingSource>

@property(nonatomic, strong, nullable) NSPanel *sourcePanel;
@property(nonatomic, strong, nullable) PSTAutomaticFileDragSourceView *sourceView;
@property(nonatomic, copy) NSArray<NSURL *> *fileURLs;
@property(nonatomic) CGPoint sourceQuartzPoint;
@property(nonatomic) CGPoint destinationQuartzPoint;
@property(nonatomic) NSDragOperation completedOperation;
@property(nonatomic) BOOL sessionBegan;
@property(nonatomic, strong, nullable) dispatch_semaphore_t completion;

- (void)beginDraggingWithEvent:(NSEvent *)event;

@end

@implementation PSTAutomaticFileDragSourceView

- (void)mouseDragged:(NSEvent *)event {
  [self.dragController beginDraggingWithEvent:event];
}

@end

static NSPoint PSTDragAppKitPointFromQuartzPoint(CGPoint point) {
  for (NSScreen *screen in NSScreen.screens) {
    NSNumber *screen_number =
        screen.deviceDescription[PSTScreenNumberDeviceDescriptionKey];
    if (screen_number == nil) {
      continue;
    }
    const CGDirectDisplayID display_identifier = screen_number.unsignedIntValue;
    const CGRect quartz_bounds = CGDisplayBounds(display_identifier);
    if (!CGRectContainsPoint(quartz_bounds, point)) {
      continue;
    }
    return NSMakePoint(screen.frame.origin.x + point.x - quartz_bounds.origin.x,
                       screen.frame.origin.y + quartz_bounds.size.height -
                           (point.y - quartz_bounds.origin.y));
  }
  NSScreen *main_screen = NSScreen.mainScreen;
  return NSMakePoint(point.x, NSMaxY(main_screen.frame) - point.y);
}

static BOOL PSTPostGlobalMouseEvent(CGEventType type, CGPoint point) {
  CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
  if (source == nullptr) {
    return NO;
  }
  CGEventRef event = CGEventCreateMouseEvent(source, type, point, kCGMouseButtonLeft);
  CFRelease(source);
  if (event == nullptr) {
    return NO;
  }
  CGEventSetIntegerValueField(event, kCGMouseEventButtonNumber,
                              (int64_t)kCGMouseButtonLeft);
  CGEventPost(kCGHIDEventTap, event);
  CFRelease(event);
  return YES;
}

@implementation PSTAutomaticFileDrag

- (instancetype)init {
  self = [super init];
  if (self != nil) {
    _fileURLs = @[];
  }
  return self;
}

- (void)prepareSourcePanel {
  const NSPoint source = PSTDragAppKitPointFromQuartzPoint(self.sourceQuartzPoint);
  const CGFloat source_size = PST_AUTOMATIC_DRAG_CONFIGURATION.source_window_size;
  const NSRect frame =
      NSMakeRect(source.x - source_size / 2.0, source.y - source_size / 2.0,
                 source_size, source_size);
  self.sourcePanel =
      [[NSPanel alloc] initWithContentRect:frame
                                 styleMask:NSWindowStyleMaskBorderless |
                                           NSWindowStyleMaskNonactivatingPanel
                                   backing:NSBackingStoreBuffered
                                     defer:NO];
  self.sourcePanel.opaque = NO;
  self.sourcePanel.backgroundColor = NSColor.clearColor;
  self.sourcePanel.hasShadow = NO;
  self.sourcePanel.hidesOnDeactivate = NO;
  self.sourcePanel.level = NSFloatingWindowLevel;
  self.sourcePanel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
                                        NSWindowCollectionBehaviorFullScreenAuxiliary |
                                        NSWindowCollectionBehaviorStationary |
                                        NSWindowCollectionBehaviorIgnoresCycle;
  self.sourceView = [[PSTAutomaticFileDragSourceView alloc]
      initWithFrame:NSMakeRect(0.0, 0.0, source_size, source_size)];
  self.sourceView.dragController = self;
  self.sourcePanel.contentView = self.sourceView;
  [self.sourcePanel orderFrontRegardless];
}

- (void)driveDraggingSession {
  const CGPoint start = self.sourceQuartzPoint;
  const CGPoint destination = self.destinationQuartzPoint;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
    (void)usleep(PST_AUTOMATIC_DRAG_CONFIGURATION.session_settle_microseconds);
    for (NSUInteger step = 1;
         step <= PST_AUTOMATIC_DRAG_CONFIGURATION.motion_step_count; ++step) {
      const CGFloat progress =
          (CGFloat)step / (CGFloat)PST_AUTOMATIC_DRAG_CONFIGURATION.motion_step_count;
      const CGFloat eased = progress * progress * (3.0 - 2.0 * progress);
      const CGPoint point = CGPointMake(start.x + (destination.x - start.x) * eased,
                                        start.y + (destination.y - start.y) * eased);
      if (!PSTPostGlobalMouseEvent(kCGEventLeftMouseDragged, point)) {
        break;
      }
      (void)usleep(PST_AUTOMATIC_DRAG_CONFIGURATION.motion_step_microseconds);
    }
    (void)PSTPostGlobalMouseEvent(kCGEventLeftMouseUp, destination);
  });
}

- (void)beginDraggingWithEvent:(NSEvent *)event {
  if (self.sessionBegan || self.sourceView == nil || self.fileURLs.count == 0) {
    return;
  }
  self.sessionBegan = YES;
  NSMutableArray<NSDraggingItem *> *dragging_items =
      [NSMutableArray arrayWithCapacity:self.fileURLs.count];
  const NSPoint location = [self.sourceView convertPoint:event.locationInWindow
                                                fromView:nil];
  for (NSURL *file_url in self.fileURLs) {
    NSString *path = file_url.path;
    if (path == nil) {
      continue;
    }
    PSTFileURLPasteboardWriter *writer =
        [[PSTFileURLPasteboardWriter alloc] initWithFileURL:file_url];
    NSDraggingItem *item = [[NSDraggingItem alloc] initWithPasteboardWriter:writer];
    NSImage *icon = [NSWorkspace.sharedWorkspace iconForFile:path];
    const CGFloat image_size = PST_AUTOMATIC_DRAG_CONFIGURATION.image_size;
    icon.size = NSMakeSize(image_size, image_size);
    const NSRect image_frame =
        NSMakeRect(location.x - image_size / 2.0, location.y - image_size / 2.0,
                   image_size, image_size);
    [item setDraggingFrame:image_frame contents:icon];
    [dragging_items addObject:item];
  }
  NSDraggingSession *session =
      [self.sourceView beginDraggingSessionWithItems:dragging_items
                                               event:event
                                              source:self];
  session.animatesToStartingPositionsOnCancelOrFail = NO;
  session.draggingFormation =
      dragging_items.count > 1 ? NSDraggingFormationStack : NSDraggingFormationNone;
}

- (NSDragOperation)draggingSession:(NSDraggingSession *)session
    sourceOperationMaskForDraggingContext:(NSDraggingContext)context {
  (void)session;
  (void)context;
  return NSDragOperationCopy;
}

- (BOOL)ignoreModifierKeysForDraggingSession:(NSDraggingSession *)session {
  (void)session;
  return YES;
}

- (void)draggingSession:(NSDraggingSession *)session
       willBeginAtPoint:(NSPoint)screen_point {
  (void)session;
  (void)screen_point;
  [self.sourcePanel orderOut:nil];
  [self driveDraggingSession];
}

- (void)draggingSession:(NSDraggingSession *)session
           endedAtPoint:(NSPoint)screen_point
              operation:(NSDragOperation)operation {
  (void)session;
  (void)screen_point;
  self.completedOperation = operation;
  dispatch_semaphore_t completion = self.completion;
  if (completion != nil) {
    dispatch_semaphore_signal(completion);
  }
}

- (BOOL)dragFileURLs:(NSArray<NSURL *> *)file_urls
       toQuartzPoint:(CGPoint)destination
             timeout:(NSTimeInterval)timeout
               error:(NSError **)error {
  if (NSThread.isMainThread || file_urls.count == 0 || timeout <= 0.0 ||
      !isfinite(destination.x) || !isfinite(destination.y)) {
    if (error != nullptr) {
      *error = PSTAutomaticDragError(
          PSTAutomaticFileDragErrorInvalidInput,
          @"An automatic file drag requires a background caller, files, and a "
           "finite destination.");
    }
    return NO;
  }
  if (!CGPreflightPostEventAccess()) {
    if (error != nullptr) {
      *error = PSTAutomaticDragError(
          PSTAutomaticFileDragErrorUnavailable,
          @"macOS has not granted permission to post native drag events.");
    }
    return NO;
  }
  for (NSURL *file_url in file_urls) {
    NSString *path = file_url.path;
    if (!file_url.isFileURL || path == nil ||
        ![NSFileManager.defaultManager fileExistsAtPath:path]) {
      if (error != nullptr) {
        *error = PSTAutomaticDragError(
            PSTAutomaticFileDragErrorInvalidInput,
            @"An automatic file drag received a missing or non-file URL.");
      }
      return NO;
    }
  }

  CGEventRef current_event = CGEventCreate(nullptr);
  if (current_event == nullptr) {
    if (error != nullptr) {
      *error = PSTAutomaticDragError(PSTAutomaticFileDragErrorUnavailable,
                                     @"Unable to read the current pointer location.");
    }
    return NO;
  }
  self.sourceQuartzPoint = CGEventGetLocation(current_event);
  CFRelease(current_event);
  self.destinationQuartzPoint = destination;
  self.fileURLs = [file_urls copy];
  self.completedOperation = NSDragOperationNone;
  self.sessionBegan = NO;
  self.completion = dispatch_semaphore_create(0);

  dispatch_sync(dispatch_get_main_queue(), ^{
    [self prepareSourcePanel];
  });
  (void)usleep(PST_AUTOMATIC_DRAG_CONFIGURATION.mouse_down_settle_microseconds);
  BOOL began_input =
      PSTPostGlobalMouseEvent(kCGEventLeftMouseDown, self.sourceQuartzPoint);
  (void)usleep(PST_AUTOMATIC_DRAG_CONFIGURATION.mouse_drag_settle_microseconds);
  if (began_input) {
    dispatch_sync(dispatch_get_main_queue(), ^{
      NSPanel *source_panel = self.sourcePanel;
      if (source_panel == nil) {
        return;
      }
      const CGFloat source_center =
          PST_AUTOMATIC_DRAG_CONFIGURATION.source_window_size / 2.0;
      const NSPoint event_offset =
          PST_AUTOMATIC_DRAG_CONFIGURATION.synthetic_drag_event_offset;
      NSEvent *mouse_dragged =
          [NSEvent mouseEventWithType:NSEventTypeLeftMouseDragged
                             location:NSMakePoint(source_center + event_offset.x,
                                                  source_center + event_offset.y)
                        modifierFlags:0
                            timestamp:NSProcessInfo.processInfo.systemUptime
                         windowNumber:source_panel.windowNumber
                              context:nil
                          eventNumber:0
                           clickCount:1
                             pressure:1.0];
      if (mouse_dragged != nil) {
        [self beginDraggingWithEvent:mouse_dragged];
      }
    });
    began_input = self.sessionBegan;
  }
  if (!began_input) {
    (void)PSTPostGlobalMouseEvent(kCGEventLeftMouseUp, self.sourceQuartzPoint);
    dispatch_sync(dispatch_get_main_queue(), ^{
      [self.sourcePanel orderOut:nil];
      self.sourcePanel = nil;
      self.sourceView = nil;
    });
    if (error != nullptr) {
      *error = PSTAutomaticDragError(PSTAutomaticFileDragErrorUnavailable,
                                     @"Unable to begin a native file drag.");
    }
    return NO;
  }

  dispatch_time_t deadline = dispatch_time(
      DISPATCH_TIME_NOW, (int64_t)(timeout * (NSTimeInterval)NSEC_PER_SEC));
  dispatch_semaphore_t completion = self.completion;
  BOOL completed =
      completion != nil && dispatch_semaphore_wait(completion, deadline) == 0;
  if (!completed) {
    (void)PSTPostGlobalMouseEvent(kCGEventLeftMouseUp, self.destinationQuartzPoint);
    dispatch_time_t cancellation_deadline =
        dispatch_time(DISPATCH_TIME_NOW,
                      PST_AUTOMATIC_DRAG_CONFIGURATION.cancellation_wait_nanoseconds);
    completed = completion != nil &&
                dispatch_semaphore_wait(completion, cancellation_deadline) == 0;
  }
  dispatch_sync(dispatch_get_main_queue(), ^{
    [self.sourcePanel orderOut:nil];
    self.sourcePanel = nil;
    self.sourceView = nil;
  });
  (void)CGWarpMouseCursorPosition(self.sourceQuartzPoint);
  self.completion = nil;
  if (!completed) {
    if (error != nullptr) {
      *error = PSTAutomaticDragError(PSTAutomaticFileDragErrorTimedOut,
                                     @"The native file drag did not finish.");
    }
    return NO;
  }
  if (self.completedOperation == NSDragOperationNone) {
    if (error != nullptr) {
      *error = PSTAutomaticDragError(
          PSTAutomaticFileDragErrorRejected,
          @"The destination did not accept the native file drag.");
    }
    return NO;
  }
  return YES;
}

@end
