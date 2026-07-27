#import "application/PSTPermissionTargetsEditorController.h"

#import "application/PSTPermissionTargetsDocument.h"
#import "application/PSTUIComponents.h"
#import "permissions/PSTPermissionManifest.h"

#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

static NSUserInterfaceItemIdentifier const PSTEditorTargetsTableIdentifier =
    @"editor-targets";
static NSUserInterfaceItemIdentifier const PSTEditorDetailIdentifier = @"editor-detail";
constexpr CGFloat PST_EDITOR_WINDOW_WIDTH = 980.0;
constexpr CGFloat PST_EDITOR_WINDOW_HEIGHT = 680.0;
constexpr CGFloat PST_EDITOR_WINDOW_MINIMUM_WIDTH = 900.0;
constexpr CGFloat PST_EDITOR_WINDOW_MINIMUM_HEIGHT = 620.0;
constexpr CGFloat PST_EDITOR_SIDEBAR_WIDTH = 286.0;
constexpr CGFloat PST_EDITOR_TARGET_ROW_HEIGHT = 56.0;
constexpr CGFloat PST_EDITOR_TARGET_TABLE_INITIAL_HEIGHT = 480.0;
constexpr CGFloat PST_EDITOR_FOOTER_HEIGHT = 62.0;

typedef struct {
  NSString *identifierPrefix;
  NSString *displayName;
  NSString *compactName;
  NSString *accessibilityName;
  NSString *pickerTitle;
  NSString *pickerMessage;
  NSString *invalidSelectionMessage;
  UTType *contentType;
  BOOL applicationBundle;
} PSTEditorTargetKindProfile;

static PSTEditorTargetKindProfile
PSTEditorTargetKindProfileForKind(PSTPermissionTargetKind kind) {
  switch (kind) {
  case PSTPermissionTargetKindApplicationBundle:
    return (PSTEditorTargetKindProfile){
        .identifierPrefix = @"app",
        .displayName = @"Application",
        .compactName = @"Application",
        .accessibilityName = @"Application",
        .pickerTitle = @"Add Applications",
        .pickerMessage = @"Choose one or more apps to include in the target file.",
        .invalidSelectionMessage =
            @"The selected items do not contain readable app bundles.",
        .contentType = UTTypeApplication,
        .applicationBundle = YES,
    };
  case PSTPermissionTargetKindExecutable:
    return (PSTEditorTargetKindProfile){
        .identifierPrefix = @"tool",
        .displayName = @"Command-line tool",
        .compactName = @"Tool",
        .accessibilityName = @"Executable",
        .pickerTitle = @"Add Executables",
        .pickerMessage =
            @"Choose one or more command-line executables to include in the target "
             "file.",
        .invalidSelectionMessage =
            @"The selected items do not contain executable files.",
        .contentType = UTTypeUnixExecutable,
        .applicationBundle = NO,
    };
  }
  unreachable();
}

@interface PSTEditorBackgroundView : NSView
@end

@implementation PSTEditorBackgroundView

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
    layer.backgroundColor = NSColor.windowBackgroundColor.CGColor;
  }];
}

- (void)viewDidChangeEffectiveAppearance {
  [super viewDidChangeEffectiveAppearance];
  self.needsDisplay = YES;
}

@end

@interface PSTPermissionTargetsEditorResult ()

- (instancetype)initWithTargetsData:(NSData *)targetsData
                           savedURL:(nullable NSURL *)savedURL
                        shouldApply:(BOOL)shouldApply NS_DESIGNATED_INITIALIZER;

@end

@implementation PSTPermissionTargetsEditorResult

- (instancetype)initWithTargetsData:(NSData *)targetsData
                           savedURL:(nullable NSURL *)savedURL
                        shouldApply:(BOOL)shouldApply {
  self = [super init];
  if (self != nil) {
    _targetsData = [targetsData copy];
    _savedURL = [savedURL copy];
    _shouldApply = shouldApply;
  }
  return self;
}

@end

@interface PSTPermissionSelectionCard : NSBox

@property(nonatomic, weak) NSButton *toggleButton;

@end

@implementation PSTPermissionSelectionCard

- (nullable NSView *)hitTest:(NSPoint)point {
  NSView *hitView = [super hitTest:point];
  if (hitView == nil) {
    return nil;
  }

  NSButton *toggleButton = self.toggleButton;
  if (toggleButton != nil) {
    NSPoint togglePoint = [toggleButton convertPoint:point fromView:self];
    if (NSPointInRect(togglePoint, toggleButton.bounds)) {
      return hitView;
    }
  }
  return self;
}

- (void)mouseDown:(NSEvent *)event {
  (void)event;
  NSButton *toggleButton = self.toggleButton;
  if (toggleButton.enabled) {
    [toggleButton performClick:self];
  }
}

@end

@interface PSTPermissionTargetsEditorController ()

@property(nonatomic, copy) NSArray<PSTPermissionService *> *services;
@property(nonatomic, copy) NSSet<NSString *> *allowedServiceIdentifiers;
@property(nonatomic, strong) NSMutableArray<PSTPermissionTargetDraft *> *targets;
@property(nonatomic, strong) NSTableView *targetsTable;
@property(nonatomic, strong) NSTextField *targetCountLabel;
@property(nonatomic, strong) NSView *sidebarEmptyState;
@property(nonatomic, strong) NSView *detailEmptyState;
@property(nonatomic, strong) NSView *detailEditor;
@property(nonatomic, strong) NSImageView *targetIcon;
@property(nonatomic, strong) NSTextField *targetTitle;
@property(nonatomic, strong) NSTextField *targetSubtitle;
@property(nonatomic, strong) NSTextField *nameField;
@property(nonatomic, strong) NSTextField *identifierField;
@property(nonatomic, strong) NSTextField *sourceLabel;
@property(nonatomic, strong) NSButton *requiredCheckbox;
@property(nonatomic, strong) NSButton *removeButton;
@property(nonatomic, strong) NSButton *selectAllButton;
@property(nonatomic, strong) NSButton *clearButton;
@property(nonatomic, strong) NSTextField *permissionCountLabel;
@property(nonatomic, strong) NSMutableArray<NSButton *> *permissionButtons;
@property(nonatomic, strong) NSMutableArray<NSImageView *> *permissionIcons;
@property(nonatomic, strong) NSMutableArray<NSBox *> *permissionCards;
@property(nonatomic, strong) NSButton *saveButton;
@property(nonatomic, strong) NSButton *applyButton;
@property(nonatomic, strong) NSButton *saveAndApplyButton;
@property(nonatomic, strong) NSImageView *validationIcon;
@property(nonatomic, strong) NSTextField *validationLabel;
@property(nonatomic, copy) PSTPermissionTargetsEditorHandler completion;
@property(nonatomic, strong, nullable) PSTPermissionTargetsEditorResult *result;

- (void)buildContent;
- (void)updateEditorPresentation;
- (void)updateValidationPresentation;
- (nullable PSTPermissionTargetDraft *)selectedTarget;
- (NSString *)uniqueIdentifierWithPrefix:(NSString *)prefix base:(NSString *)base;
- (BOOL)addTargetFromURL:(NSURL *)URL kind:(PSTPermissionTargetKind)kind;
- (void)addTargetsOfKind:(PSTPermissionTargetKind)kind;
- (void)addApplication:(nullable id)sender;
- (void)addExecutable:(nullable id)sender;
- (void)removeTarget:(nullable id)sender;
- (void)togglePermission:(NSButton *)sender;
- (void)selectAllPermissions:(nullable id)sender;
- (void)clearPermissions:(nullable id)sender;
- (void)toggleRequired:(nullable id)sender;
- (void)cancelEditor:(nullable id)sender;
- (void)saveTargets:(nullable id)sender;
- (void)applyTargets:(nullable id)sender;
- (void)saveAndApplyTargets:(nullable id)sender;

@end

@implementation PSTPermissionTargetsEditorController

static NSScrollView *PSTEditorScrollView(NSTableView *table) {
  NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
  scrollView.translatesAutoresizingMaskIntoConstraints = NO;
  scrollView.hasVerticalScroller = YES;
  scrollView.autohidesScrollers = YES;
  scrollView.borderType = NSNoBorder;
  scrollView.drawsBackground = NO;
  scrollView.documentView = table;
  return scrollView;
}

static NSStackView *PSTEditorFormRow(NSString *title, NSView *valueView,
                                     NSLayoutAttribute alignment) {
  NSTextField *label = PSTUILabel(title);
  label.alignment = NSTextAlignmentRight;
  label.textColor = NSColor.secondaryLabelColor;
  [label.widthAnchor constraintEqualToConstant:70.0].active = YES;
  NSStackView *row = [NSStackView stackViewWithViews:@[ label, valueView ]];
  row.translatesAutoresizingMaskIntoConstraints = NO;
  row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  row.alignment = alignment;
  row.spacing = 10.0;
  return row;
}

static NSImage *PSTEditorImageForTarget(PSTPermissionTargetDraft *target,
                                        CGFloat size) {
  return PSTUITargetIcon(target.pathCandidates,
                         target.kind == PSTPermissionTargetKindExecutable, size);
}

static NSView *PSTEditorEmptyState(NSString *symbol, NSString *titleText,
                                   NSString *detailText, NSArray<NSButton *> *buttons) {
  NSImageView *icon = [[NSImageView alloc] initWithFrame:NSZeroRect];
  icon.translatesAutoresizingMaskIntoConstraints = NO;
  icon.image = PSTUISymbol(symbol, titleText, 42.0, NSFontWeightRegular);
  icon.contentTintColor = NSColor.tertiaryLabelColor;
  icon.imageScaling = NSImageScaleProportionallyDown;
  [NSLayoutConstraint activateConstraints:@[
    [icon.widthAnchor constraintEqualToConstant:58.0],
    [icon.heightAnchor constraintEqualToConstant:58.0],
  ]];

  NSTextField *title = PSTUILabel(titleText);
  title.font = [NSFont systemFontOfSize:20.0 weight:NSFontWeightSemibold];
  title.alignment = NSTextAlignmentCenter;
  NSTextField *detail = PSTUILabel(detailText);
  detail.font = [NSFont systemFontOfSize:13.0];
  detail.textColor = NSColor.secondaryLabelColor;
  detail.alignment = NSTextAlignmentCenter;
  detail.maximumNumberOfLines = 3;
  detail.lineBreakMode = NSLineBreakByWordWrapping;
  [detail.widthAnchor constraintLessThanOrEqualToConstant:390.0].active = YES;

  NSMutableArray<NSView *> *content =
      [NSMutableArray arrayWithObjects:icon, title, detail, nil];
  if (buttons.count > 0) {
    NSStackView *actions = [NSStackView stackViewWithViews:buttons];
    actions.translatesAutoresizingMaskIntoConstraints = NO;
    actions.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    actions.alignment = NSLayoutAttributeCenterY;
    actions.spacing = 10.0;
    [content addObject:actions];
  }

  NSStackView *stack = PSTUIVerticalStack(content, 7.0);
  stack.alignment = NSLayoutAttributeCenterX;
  [stack setCustomSpacing:16.0 afterView:detail];

  NSView *container = [[NSView alloc] initWithFrame:NSZeroRect];
  container.translatesAutoresizingMaskIntoConstraints = NO;
  [container addSubview:stack];
  [NSLayoutConstraint activateConstraints:@[
    [stack.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
    [stack.centerYAnchor constraintEqualToAnchor:container.centerYAnchor constant:-8.0],
    [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:container.leadingAnchor
                                                     constant:28.0],
    [stack.trailingAnchor constraintLessThanOrEqualToAnchor:container.trailingAnchor
                                                   constant:-28.0],
  ]];
  return container;
}

- (instancetype)initWithServices:(NSArray<PSTPermissionService *> *)services {
  NSWindow *sheet = [[NSWindow alloc]
      initWithContentRect:NSMakeRect(0, 0, PST_EDITOR_WINDOW_WIDTH,
                                     PST_EDITOR_WINDOW_HEIGHT)
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskResizable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  self = [super initWithWindow:sheet];
  if (self == nil) {
    return nil;
  }

  _services = [services copy];
  NSMutableSet<NSString *> *serviceIdentifiers = [NSMutableSet set];
  for (PSTPermissionService *service in services) {
    [serviceIdentifiers addObject:service.identifier];
  }
  _allowedServiceIdentifiers = [serviceIdentifiers copy];
  _targets = [NSMutableArray array];
  _permissionButtons = [NSMutableArray array];
  _permissionIcons = [NSMutableArray array];
  _permissionCards = [NSMutableArray array];

  sheet.title = @"New Permission Targets";
  sheet.restorable = NO;
  sheet.contentMinSize =
      NSMakeSize(PST_EDITOR_WINDOW_MINIMUM_WIDTH, PST_EDITOR_WINDOW_MINIMUM_HEIGHT);
  sheet.titlebarSeparatorStyle = NSTitlebarSeparatorStyleNone;
  [self buildContent];
  return self;
}

- (NSView *)buildSidebar {
  NSVisualEffectView *sidebar = [[NSVisualEffectView alloc] initWithFrame:NSZeroRect];
  sidebar.translatesAutoresizingMaskIntoConstraints = NO;
  sidebar.material = NSVisualEffectMaterialSidebar;
  sidebar.blendingMode = NSVisualEffectBlendingModeBehindWindow;
  sidebar.state = NSVisualEffectStateFollowsWindowActiveState;

  NSTextField *heading = PSTUILabel(@"Targets");
  heading.font = [NSFont systemFontOfSize:16.0 weight:NSFontWeightSemibold];
  self.targetCountLabel = PSTUILabel(@"No targets");
  self.targetCountLabel.font = [NSFont systemFontOfSize:11.0];
  self.targetCountLabel.textColor = NSColor.secondaryLabelColor;
  NSStackView *headingStack =
      PSTUIVerticalStack(@[ heading, self.targetCountLabel ], 2.0);

  self.targetsTable = [[NSTableView alloc]
      initWithFrame:NSMakeRect(0, 0, PST_EDITOR_SIDEBAR_WIDTH,
                               PST_EDITOR_TARGET_TABLE_INITIAL_HEIGHT)];
  self.targetsTable.identifier = PSTEditorTargetsTableIdentifier;
  self.targetsTable.headerView = nil;
  self.targetsTable.rowHeight = PST_EDITOR_TARGET_ROW_HEIGHT;
  self.targetsTable.rowSizeStyle = NSTableViewRowSizeStyleCustom;
  self.targetsTable.intercellSpacing = NSMakeSize(0, 2.0);
  self.targetsTable.backgroundColor = NSColor.clearColor;
  self.targetsTable.style = NSTableViewStyleSourceList;
  self.targetsTable.selectionHighlightStyle = NSTableViewSelectionHighlightStyleRegular;
  self.targetsTable.allowsMultipleSelection = NO;
  self.targetsTable.allowsEmptySelection = NO;
  self.targetsTable.dataSource = self;
  self.targetsTable.delegate = self;
  [self.targetsTable setAccessibilityLabel:@"Permission targets"];
  [self.targetsTable registerForDraggedTypes:@[ NSPasteboardTypeFileURL ]];
  NSTableColumn *targetColumn =
      [[NSTableColumn alloc] initWithIdentifier:PSTEditorTargetsTableIdentifier];
  targetColumn.resizingMask = NSTableColumnAutoresizingMask;
  [self.targetsTable addTableColumn:targetColumn];

  NSScrollView *targetScrollView = PSTEditorScrollView(self.targetsTable);

  NSTextField *sidebarEmptyTitle = PSTUILabel(@"No Targets");
  sidebarEmptyTitle.font = [NSFont systemFontOfSize:13.0 weight:NSFontWeightMedium];
  sidebarEmptyTitle.alignment = NSTextAlignmentCenter;
  NSTextField *sidebarEmptyDetail = PSTUILabel(@"Apps and tools you add appear here.");
  sidebarEmptyDetail.font = [NSFont systemFontOfSize:11.0];
  sidebarEmptyDetail.textColor = NSColor.secondaryLabelColor;
  sidebarEmptyDetail.alignment = NSTextAlignmentCenter;
  sidebarEmptyDetail.maximumNumberOfLines = 2;
  sidebarEmptyDetail.lineBreakMode = NSLineBreakByWordWrapping;
  NSImageView *sidebarEmptyIcon = [[NSImageView alloc] initWithFrame:NSZeroRect];
  sidebarEmptyIcon.translatesAutoresizingMaskIntoConstraints = NO;
  sidebarEmptyIcon.image =
      PSTUISymbol(@"square.stack.3d.up", @"No targets", 25.0, NSFontWeightRegular);
  sidebarEmptyIcon.contentTintColor = NSColor.tertiaryLabelColor;
  [sidebarEmptyIcon.widthAnchor constraintEqualToConstant:34.0].active = YES;
  [sidebarEmptyIcon.heightAnchor constraintEqualToConstant:34.0].active = YES;
  NSStackView *sidebarEmptyStack = PSTUIVerticalStack(
      @[ sidebarEmptyIcon, sidebarEmptyTitle, sidebarEmptyDetail ], 5.0);
  sidebarEmptyStack.alignment = NSLayoutAttributeCenterX;
  NSView *sidebarEmpty = [[NSView alloc] initWithFrame:NSZeroRect];
  sidebarEmpty.translatesAutoresizingMaskIntoConstraints = NO;
  [sidebarEmpty addSubview:sidebarEmptyStack];
  [NSLayoutConstraint activateConstraints:@[
    [sidebarEmptyStack.centerXAnchor
        constraintEqualToAnchor:sidebarEmpty.centerXAnchor],
    [sidebarEmptyStack.centerYAnchor constraintEqualToAnchor:sidebarEmpty.centerYAnchor
                                                    constant:-10.0],
    [sidebarEmptyStack.leadingAnchor
        constraintGreaterThanOrEqualToAnchor:sidebarEmpty.leadingAnchor
                                    constant:20.0],
    [sidebarEmptyStack.trailingAnchor
        constraintLessThanOrEqualToAnchor:sidebarEmpty.trailingAnchor
                                 constant:-20.0],
  ]];
  self.sidebarEmptyState = sidebarEmpty;

  NSPopUpButton *addButton = [[NSPopUpButton alloc] initWithFrame:NSZeroRect
                                                        pullsDown:YES];
  addButton.translatesAutoresizingMaskIntoConstraints = NO;
  addButton.controlSize = NSControlSizeRegular;
  [addButton setAccessibilityLabel:@"Add Target"];
  addButton.toolTip = @"Add an application or executable";
  NSMenu *addMenu = [[NSMenu alloc] initWithTitle:@"Add Target"];
  NSMenuItem *menuTitle = [[NSMenuItem alloc] initWithTitle:@"Add Target"
                                                     action:nil
                                              keyEquivalent:@""];
  menuTitle.image = PSTUISymbol(@"plus", @"Add Target", 12.0, NSFontWeightSemibold);
  [addMenu addItem:menuTitle];
  NSMenuItem *addApplication =
      [[NSMenuItem alloc] initWithTitle:@"Add Application…"
                                 action:@selector(addApplication:)
                          keyEquivalent:@""];
  addApplication.target = self;
  addApplication.image =
      PSTUISymbol(@"plus.app", @"Add Application", 13.0, NSFontWeightRegular);
  [addMenu addItem:addApplication];
  NSMenuItem *addExecutable =
      [[NSMenuItem alloc] initWithTitle:@"Add Executable…"
                                 action:@selector(addExecutable:)
                          keyEquivalent:@""];
  addExecutable.target = self;
  addExecutable.image =
      PSTUISymbol(@"terminal", @"Add Executable", 13.0, NSFontWeightRegular);
  [addMenu addItem:addExecutable];
  addButton.menu = addMenu;

  self.removeButton = [NSButton buttonWithImage:PSTUISymbol(@"minus", @"Remove Target",
                                                            11.0, NSFontWeightSemibold)
                                         target:self
                                         action:@selector(removeTarget:)];
  self.removeButton.translatesAutoresizingMaskIntoConstraints = NO;
  self.removeButton.bordered = NO;
  self.removeButton.toolTip = @"Remove selected target";
  [self.removeButton setAccessibilityLabel:@"Remove Target"];
  [self.removeButton.widthAnchor constraintEqualToConstant:28.0].active = YES;
  [self.removeButton.heightAnchor constraintEqualToConstant:28.0].active = YES;

  NSStackView *sidebarActions = [NSStackView stackViewWithViews:@[
    addButton,
    PSTUIFlexibleSpace(),
    self.removeButton,
  ]];
  sidebarActions.translatesAutoresizingMaskIntoConstraints = NO;
  sidebarActions.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  sidebarActions.alignment = NSLayoutAttributeCenterY;
  sidebarActions.spacing = 8.0;

  NSBox *footerSeparator = PSTUISeparator();
  [sidebar addSubview:headingStack];
  [sidebar addSubview:targetScrollView];
  [sidebar addSubview:self.sidebarEmptyState];
  [sidebar addSubview:footerSeparator];
  [sidebar addSubview:sidebarActions];
  [NSLayoutConstraint activateConstraints:@[
    [headingStack.topAnchor constraintEqualToAnchor:sidebar.topAnchor constant:20.0],
    [headingStack.leadingAnchor constraintEqualToAnchor:sidebar.leadingAnchor
                                               constant:20.0],
    [headingStack.trailingAnchor
        constraintLessThanOrEqualToAnchor:sidebar.trailingAnchor
                                 constant:-20.0],
    [targetScrollView.topAnchor constraintEqualToAnchor:headingStack.bottomAnchor
                                               constant:14.0],
    [targetScrollView.leadingAnchor constraintEqualToAnchor:sidebar.leadingAnchor
                                                   constant:8.0],
    [targetScrollView.trailingAnchor constraintEqualToAnchor:sidebar.trailingAnchor
                                                    constant:-8.0],
    [targetScrollView.bottomAnchor constraintEqualToAnchor:footerSeparator.topAnchor],
    [self.sidebarEmptyState.topAnchor
        constraintEqualToAnchor:targetScrollView.topAnchor],
    [self.sidebarEmptyState.leadingAnchor
        constraintEqualToAnchor:targetScrollView.leadingAnchor],
    [self.sidebarEmptyState.trailingAnchor
        constraintEqualToAnchor:targetScrollView.trailingAnchor],
    [self.sidebarEmptyState.bottomAnchor
        constraintEqualToAnchor:targetScrollView.bottomAnchor],
    [footerSeparator.leadingAnchor constraintEqualToAnchor:sidebar.leadingAnchor],
    [footerSeparator.trailingAnchor constraintEqualToAnchor:sidebar.trailingAnchor],
    [sidebarActions.topAnchor constraintEqualToAnchor:footerSeparator.bottomAnchor
                                             constant:10.0],
    [sidebarActions.leadingAnchor constraintEqualToAnchor:sidebar.leadingAnchor
                                                 constant:14.0],
    [sidebarActions.trailingAnchor constraintEqualToAnchor:sidebar.trailingAnchor
                                                  constant:-14.0],
    [sidebarActions.bottomAnchor constraintEqualToAnchor:sidebar.bottomAnchor
                                                constant:-10.0],
    [sidebarActions.heightAnchor constraintEqualToConstant:30.0],
  ]];
  return sidebar;
}

- (NSBox *)permissionCardForService:(PSTPermissionService *)service
                              index:(NSUInteger)index {
  PSTPermissionSelectionCard *card =
      [[PSTPermissionSelectionCard alloc] initWithFrame:NSZeroRect];
  card.translatesAutoresizingMaskIntoConstraints = NO;
  card.boxType = NSBoxCustom;
  card.titlePosition = NSNoTitle;
  card.contentViewMargins = NSMakeSize(12.0, 9.0);
  card.borderWidth = 0.0;
  card.cornerRadius = 10.0;
  card.borderColor = [NSColor.separatorColor colorWithAlphaComponent:0.55];
  card.fillColor = NSColor.controlBackgroundColor;
  [card.heightAnchor constraintEqualToConstant:61.0].active = YES;

  NSImageView *icon = [[NSImageView alloc] initWithFrame:NSZeroRect];
  icon.translatesAutoresizingMaskIntoConstraints = NO;
  icon.image = PSTUISymbol(service.symbolName, service.name, 19.0, NSFontWeightMedium);
  icon.contentTintColor = NSColor.secondaryLabelColor;
  icon.imageScaling = NSImageScaleProportionallyDown;
  [icon.widthAnchor constraintEqualToConstant:28.0].active = YES;
  [icon.heightAnchor constraintEqualToConstant:28.0].active = YES;

  NSTextField *name = PSTUILabel(service.name);
  name.font = [NSFont systemFontOfSize:12.0 weight:NSFontWeightMedium];
  name.lineBreakMode = NSLineBreakByTruncatingTail;
  NSTextField *description =
      PSTUILabel(service.serviceDescription != nil ? service.serviceDescription
                                                   : service.identifier);
  description.font = [NSFont systemFontOfSize:10.0];
  description.textColor = NSColor.secondaryLabelColor;
  description.maximumNumberOfLines = 2;
  description.lineBreakMode = NSLineBreakByWordWrapping;
  NSStackView *text = PSTUIVerticalStack(@[ name, description ], 2.0);

  NSButton *checkbox = [NSButton checkboxWithTitle:@""
                                            target:self
                                            action:@selector(togglePermission:)];
  checkbox.translatesAutoresizingMaskIntoConstraints = NO;
  checkbox.tag = (NSInteger)index;
  checkbox.toolTip = [NSString stringWithFormat:@"Include %@", service.name];
  [checkbox
      setAccessibilityLabel:[NSString stringWithFormat:@"%@ permission", service.name]];
  [checkbox.widthAnchor constraintEqualToConstant:18.0].active = YES;
  card.toggleButton = checkbox;
  card.toolTip = checkbox.toolTip;

  NSStackView *row =
      [NSStackView stackViewWithViews:@[ icon, text, PSTUIFlexibleSpace(), checkbox ]];
  row.translatesAutoresizingMaskIntoConstraints = NO;
  row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  row.alignment = NSLayoutAttributeCenterY;
  row.spacing = 9.0;
  NSView *cardContent = card.contentView;
  [cardContent addSubview:row];
  [NSLayoutConstraint activateConstraints:@[
    [row.topAnchor constraintEqualToAnchor:cardContent.topAnchor],
    [row.leadingAnchor constraintEqualToAnchor:cardContent.leadingAnchor],
    [row.trailingAnchor constraintEqualToAnchor:cardContent.trailingAnchor],
    [row.bottomAnchor constraintEqualToAnchor:cardContent.bottomAnchor],
  ]];

  [self.permissionButtons addObject:checkbox];
  [self.permissionIcons addObject:icon];
  [self.permissionCards addObject:card];
  return card;
}

- (NSView *)buildPermissionGrid {
  NSMutableArray<NSView *> *rows = [NSMutableArray array];
  for (NSUInteger index = 0; index < self.services.count; index += 2) {
    NSBox *leading = [self permissionCardForService:self.services[index] index:index];
    NSView *trailing = nil;
    if (index + 1 < self.services.count) {
      trailing = [self permissionCardForService:self.services[index + 1]
                                          index:index + 1];
    } else {
      trailing = [[NSView alloc] initWithFrame:NSZeroRect];
      trailing.translatesAutoresizingMaskIntoConstraints = NO;
    }
    NSStackView *row = [NSStackView stackViewWithViews:@[ leading, trailing ]];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeTop;
    row.distribution = NSStackViewDistributionFillEqually;
    row.spacing = 10.0;
    [leading.widthAnchor constraintEqualToAnchor:trailing.widthAnchor].active = YES;
    [rows addObject:row];
  }
  NSStackView *grid = PSTUIVerticalStack(rows, 7.0);
  for (NSView *row in rows) {
    [row.widthAnchor constraintEqualToAnchor:grid.widthAnchor].active = YES;
  }
  return grid;
}

- (NSView *)buildDetailEditor {
  self.targetIcon = [[NSImageView alloc] initWithFrame:NSZeroRect];
  self.targetIcon.translatesAutoresizingMaskIntoConstraints = NO;
  self.targetIcon.imageScaling = NSImageScaleProportionallyUpOrDown;
  [self.targetIcon setAccessibilityLabel:@"Selected target"];
  [NSLayoutConstraint activateConstraints:@[
    [self.targetIcon.widthAnchor constraintEqualToConstant:56.0],
    [self.targetIcon.heightAnchor constraintEqualToConstant:56.0],
  ]];

  self.targetTitle = PSTUILabel(@"Target");
  self.targetTitle.font = [NSFont systemFontOfSize:20.0 weight:NSFontWeightSemibold];
  self.targetTitle.lineBreakMode = NSLineBreakByTruncatingTail;
  self.targetSubtitle = PSTUILabel(@"Application");
  self.targetSubtitle.font = [NSFont systemFontOfSize:12.0];
  self.targetSubtitle.textColor = NSColor.secondaryLabelColor;
  self.targetSubtitle.lineBreakMode = NSLineBreakByTruncatingMiddle;
  NSStackView *targetText =
      PSTUIVerticalStack(@[ self.targetTitle, self.targetSubtitle ], 4.0);

  self.requiredCheckbox = [NSButton checkboxWithTitle:@"Required for this workflow"
                                               target:self
                                               action:@selector(toggleRequired:)];
  self.requiredCheckbox.translatesAutoresizingMaskIntoConstraints = NO;
  self.requiredCheckbox.toolTip =
      @"Stop the workflow if this target cannot be resolved";
  NSStackView *hero = [NSStackView stackViewWithViews:@[
    self.targetIcon,
    targetText,
    PSTUIFlexibleSpace(),
    self.requiredCheckbox,
  ]];
  hero.translatesAutoresizingMaskIntoConstraints = NO;
  hero.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  hero.alignment = NSLayoutAttributeCenterY;
  hero.spacing = 14.0;

  NSTextField *detailsHeading = PSTUILabel(@"Details");
  detailsHeading.font = [NSFont systemFontOfSize:15.0 weight:NSFontWeightSemibold];

  self.nameField = [[NSTextField alloc] initWithFrame:NSZeroRect];
  self.nameField.translatesAutoresizingMaskIntoConstraints = NO;
  self.nameField.placeholderString = @"Display name";
  self.nameField.delegate = self;
  [self.nameField setAccessibilityLabel:@"Target name"];

  self.identifierField = [[NSTextField alloc] initWithFrame:NSZeroRect];
  self.identifierField.translatesAutoresizingMaskIntoConstraints = NO;
  self.identifierField.placeholderString = @"Unique identifier";
  self.identifierField.delegate = self;
  [self.identifierField setAccessibilityLabel:@"Target identifier"];

  self.sourceLabel = PSTUILabel(@"");
  self.sourceLabel.font = [NSFont monospacedSystemFontOfSize:10.0
                                                      weight:NSFontWeightRegular];
  self.sourceLabel.textColor = NSColor.secondaryLabelColor;
  self.sourceLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
  self.sourceLabel.selectable = YES;
  [self.sourceLabel
      setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                               forOrientation:NSLayoutConstraintOrientationHorizontal];
  NSStackView *nameRow =
      PSTEditorFormRow(@"Name", self.nameField, NSLayoutAttributeCenterY);
  NSStackView *identifierRow =
      PSTEditorFormRow(@"Identifier", self.identifierField, NSLayoutAttributeCenterY);
  NSStackView *sourceRow =
      PSTEditorFormRow(@"Source", self.sourceLabel, NSLayoutAttributeFirstBaseline);

  NSStackView *details =
      PSTUIVerticalStack(@[ detailsHeading, nameRow, identifierRow, sourceRow ], 8.0);
  [details setCustomSpacing:10.0 afterView:detailsHeading];
  [nameRow.widthAnchor constraintEqualToAnchor:details.widthAnchor].active = YES;
  [identifierRow.widthAnchor constraintEqualToAnchor:details.widthAnchor].active = YES;
  [sourceRow.widthAnchor constraintEqualToAnchor:details.widthAnchor].active = YES;

  NSTextField *permissionsHeading = PSTUILabel(@"Permissions");
  permissionsHeading.font = [NSFont systemFontOfSize:15.0 weight:NSFontWeightSemibold];
  self.permissionCountLabel = PSTUILabel(@"0 selected");
  self.permissionCountLabel.font = [NSFont systemFontOfSize:11.0];
  self.permissionCountLabel.textColor = NSColor.secondaryLabelColor;
  self.selectAllButton = [NSButton buttonWithTitle:@"Select All"
                                            target:self
                                            action:@selector(selectAllPermissions:)];
  self.selectAllButton.translatesAutoresizingMaskIntoConstraints = NO;
  self.selectAllButton.bordered = NO;
  self.selectAllButton.controlSize = NSControlSizeSmall;
  self.clearButton = [NSButton buttonWithTitle:@"Clear"
                                        target:self
                                        action:@selector(clearPermissions:)];
  self.clearButton.translatesAutoresizingMaskIntoConstraints = NO;
  self.clearButton.bordered = NO;
  self.clearButton.controlSize = NSControlSizeSmall;
  NSStackView *permissionHeader = [NSStackView stackViewWithViews:@[
    permissionsHeading,
    self.permissionCountLabel,
    PSTUIFlexibleSpace(),
    self.selectAllButton,
    self.clearButton,
  ]];
  permissionHeader.translatesAutoresizingMaskIntoConstraints = NO;
  permissionHeader.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  permissionHeader.alignment = NSLayoutAttributeCenterY;
  permissionHeader.spacing = 9.0;

  NSView *permissionGrid = [self buildPermissionGrid];
  NSStackView *root = PSTUIVerticalStack(
      @[ hero, PSTUISeparator(), details, permissionHeader, permissionGrid ], 13.0);
  [root setCustomSpacing:15.0 afterView:hero];
  [root setCustomSpacing:15.0 afterView:details];
  for (NSView *view in root.arrangedSubviews) {
    [view.widthAnchor constraintEqualToAnchor:root.widthAnchor].active = YES;
  }

  NSView *container = [[NSView alloc] initWithFrame:NSZeroRect];
  container.translatesAutoresizingMaskIntoConstraints = NO;
  [container addSubview:root];
  [NSLayoutConstraint activateConstraints:@[
    [root.topAnchor constraintEqualToAnchor:container.topAnchor constant:22.0],
    [root.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:26.0],
    [root.trailingAnchor constraintEqualToAnchor:container.trailingAnchor
                                        constant:-26.0],
    [root.bottomAnchor constraintLessThanOrEqualToAnchor:container.bottomAnchor
                                                constant:-20.0],
  ]];
  return container;
}

- (NSView *)buildDetail {
  NSView *detail = [[PSTEditorBackgroundView alloc] initWithFrame:NSZeroRect];
  detail.translatesAutoresizingMaskIntoConstraints = NO;
  detail.identifier = PSTEditorDetailIdentifier;

  NSButton *addApplicationButton =
      [NSButton buttonWithTitle:@"Add Application…"
                         target:self
                         action:@selector(addApplication:)];
  addApplicationButton.translatesAutoresizingMaskIntoConstraints = NO;
  addApplicationButton.image =
      PSTUISymbol(@"plus.app", @"Add Application", 13.0, NSFontWeightRegular);
  addApplicationButton.imagePosition = NSImageLeading;
  addApplicationButton.imageHugsTitle = YES;
  PSTUIConfigureButton(addApplicationButton, NO);

  NSButton *addExecutableButton = [NSButton buttonWithTitle:@"Add Executable…"
                                                     target:self
                                                     action:@selector(addExecutable:)];
  addExecutableButton.translatesAutoresizingMaskIntoConstraints = NO;
  addExecutableButton.image =
      PSTUISymbol(@"terminal", @"Add Executable", 13.0, NSFontWeightRegular);
  addExecutableButton.imagePosition = NSImageLeading;
  addExecutableButton.imageHugsTitle = YES;
  PSTUIConfigureButton(addExecutableButton, NO);

  self.detailEmptyState = PSTEditorEmptyState(
      @"app.badge", @"Add Your First Target",
      @"Choose one or more applications or command-line tools. Then select the "
       "permissions each target needs.",
      @[ addApplicationButton, addExecutableButton ]);
  self.detailEditor = [self buildDetailEditor];
  [detail addSubview:self.detailEmptyState];
  [detail addSubview:self.detailEditor];
  [NSLayoutConstraint activateConstraints:@[
    [self.detailEmptyState.topAnchor constraintEqualToAnchor:detail.topAnchor],
    [self.detailEmptyState.leadingAnchor constraintEqualToAnchor:detail.leadingAnchor],
    [self.detailEmptyState.trailingAnchor
        constraintEqualToAnchor:detail.trailingAnchor],
    [self.detailEmptyState.bottomAnchor constraintEqualToAnchor:detail.bottomAnchor],
    [self.detailEditor.topAnchor constraintEqualToAnchor:detail.topAnchor],
    [self.detailEditor.leadingAnchor constraintEqualToAnchor:detail.leadingAnchor],
    [self.detailEditor.trailingAnchor constraintEqualToAnchor:detail.trailingAnchor],
    [self.detailEditor.bottomAnchor constraintEqualToAnchor:detail.bottomAnchor],
  ]];
  return detail;
}

- (NSView *)buildFooter {
  NSVisualEffectView *footer = [[NSVisualEffectView alloc] initWithFrame:NSZeroRect];
  footer.translatesAutoresizingMaskIntoConstraints = NO;
  footer.material = NSVisualEffectMaterialHeaderView;
  footer.blendingMode = NSVisualEffectBlendingModeWithinWindow;
  footer.state = NSVisualEffectStateFollowsWindowActiveState;

  self.validationIcon = [[NSImageView alloc] initWithFrame:NSZeroRect];
  self.validationIcon.translatesAutoresizingMaskIntoConstraints = NO;
  self.validationIcon.image =
      PSTUISymbol(@"info.circle", @"Editor status", 14.0, NSFontWeightMedium);
  self.validationIcon.contentTintColor = NSColor.secondaryLabelColor;
  [self.validationIcon.widthAnchor constraintEqualToConstant:18.0].active = YES;
  [self.validationIcon.heightAnchor constraintEqualToConstant:18.0].active = YES;

  self.validationLabel = PSTUILabel(@"Add at least one application or executable.");
  self.validationLabel.font = [NSFont systemFontOfSize:12.0];
  self.validationLabel.textColor = NSColor.secondaryLabelColor;
  self.validationLabel.maximumNumberOfLines = 2;
  self.validationLabel.lineBreakMode = NSLineBreakByWordWrapping;

  NSButton *cancelButton = [NSButton buttonWithTitle:@"Cancel"
                                              target:self
                                              action:@selector(cancelEditor:)];
  cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
  cancelButton.controlSize = NSControlSizeLarge;
  cancelButton.keyEquivalent = @"\033";
  PSTUIConfigureButton(cancelButton, NO);

  self.saveButton = [NSButton buttonWithTitle:@"Save…"
                                       target:self
                                       action:@selector(saveTargets:)];
  self.saveButton.translatesAutoresizingMaskIntoConstraints = NO;
  self.saveButton.controlSize = NSControlSizeLarge;
  self.saveButton.image =
      PSTUISymbol(@"square.and.arrow.down", @"Save Targets", 13.0, NSFontWeightMedium);
  self.saveButton.imagePosition = NSImageLeading;
  self.saveButton.imageHugsTitle = YES;
  PSTUIConfigureButton(self.saveButton, NO);

  self.applyButton = [NSButton buttonWithTitle:@"Apply"
                                        target:self
                                        action:@selector(applyTargets:)];
  self.applyButton.translatesAutoresizingMaskIntoConstraints = NO;
  self.applyButton.controlSize = NSControlSizeLarge;
  self.applyButton.image =
      PSTUISymbol(@"checkmark", @"Apply Targets", 13.0, NSFontWeightMedium);
  self.applyButton.imagePosition = NSImageLeading;
  self.applyButton.imageHugsTitle = YES;
  self.applyButton.toolTip = @"Use these targets without choosing a separate file";
  PSTUIConfigureButton(self.applyButton, NO);

  self.saveAndApplyButton = [NSButton buttonWithTitle:@"Save & Apply…"
                                               target:self
                                               action:@selector(saveAndApplyTargets:)];
  self.saveAndApplyButton.translatesAutoresizingMaskIntoConstraints = NO;
  self.saveAndApplyButton.controlSize = NSControlSizeLarge;
  self.saveAndApplyButton.keyEquivalent = @"\r";
  self.saveAndApplyButton.image = PSTUISymbol(
      @"checkmark.circle", @"Save and Apply Targets", 13.0, NSFontWeightMedium);
  self.saveAndApplyButton.imagePosition = NSImageLeading;
  self.saveAndApplyButton.imageHugsTitle = YES;
  PSTUIConfigureButton(self.saveAndApplyButton, YES);

  NSStackView *row = [NSStackView stackViewWithViews:@[
    self.validationIcon,
    self.validationLabel,
    PSTUIFlexibleSpace(),
    cancelButton,
    self.saveButton,
    self.applyButton,
    self.saveAndApplyButton,
  ]];
  row.translatesAutoresizingMaskIntoConstraints = NO;
  row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  row.alignment = NSLayoutAttributeCenterY;
  row.spacing = 10.0;

  NSBox *separator = PSTUISeparator();
  [footer addSubview:separator];
  [footer addSubview:row];
  [NSLayoutConstraint activateConstraints:@[
    [separator.topAnchor constraintEqualToAnchor:footer.topAnchor],
    [separator.leadingAnchor constraintEqualToAnchor:footer.leadingAnchor],
    [separator.trailingAnchor constraintEqualToAnchor:footer.trailingAnchor],
    [row.topAnchor constraintEqualToAnchor:separator.bottomAnchor constant:10.0],
    [row.leadingAnchor constraintEqualToAnchor:footer.leadingAnchor constant:18.0],
    [row.trailingAnchor constraintEqualToAnchor:footer.trailingAnchor constant:-18.0],
    [row.bottomAnchor constraintEqualToAnchor:footer.bottomAnchor constant:-10.0],
  ]];
  return footer;
}

- (void)buildContent {
  NSView *content =
      [[NSView alloc] initWithFrame:NSMakeRect(0, 0, PST_EDITOR_WINDOW_WIDTH,
                                               PST_EDITOR_WINDOW_HEIGHT)];
  self.window.contentView = content;

  NSView *sidebar = [self buildSidebar];
  NSView *detail = [self buildDetail];
  NSView *footer = [self buildFooter];
  NSBox *divider = PSTUISeparator();
  [content addSubview:sidebar];
  [content addSubview:divider];
  [content addSubview:detail];
  [content addSubview:footer];
  [NSLayoutConstraint activateConstraints:@[
    [sidebar.topAnchor constraintEqualToAnchor:content.topAnchor],
    [sidebar.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
    [sidebar.bottomAnchor constraintEqualToAnchor:footer.topAnchor],
    [sidebar.widthAnchor constraintEqualToConstant:PST_EDITOR_SIDEBAR_WIDTH],
    [divider.topAnchor constraintEqualToAnchor:content.topAnchor],
    [divider.leadingAnchor constraintEqualToAnchor:sidebar.trailingAnchor],
    [divider.bottomAnchor constraintEqualToAnchor:footer.topAnchor],
    [divider.widthAnchor constraintEqualToConstant:1.0],
    [detail.topAnchor constraintEqualToAnchor:content.topAnchor],
    [detail.leadingAnchor constraintEqualToAnchor:divider.trailingAnchor],
    [detail.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
    [detail.bottomAnchor constraintEqualToAnchor:footer.topAnchor],
    [footer.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
    [footer.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
    [footer.bottomAnchor constraintEqualToAnchor:content.bottomAnchor],
    [footer.heightAnchor constraintEqualToConstant:PST_EDITOR_FOOTER_HEIGHT],
  ]];

  [self updateEditorPresentation];
}

- (nullable PSTPermissionTargetDraft *)selectedTarget {
  NSInteger selectedRow = self.targetsTable.selectedRow;
  if (selectedRow < 0 || (NSUInteger)selectedRow >= self.targets.count) {
    return nil;
  }
  return self.targets[(NSUInteger)selectedRow];
}

- (void)updatePermissionPresentationForTarget:
    (nullable PSTPermissionTargetDraft *)target {
  NSUInteger selectedCount = target.serviceIdentifiers.count;
  self.permissionCountLabel.stringValue =
      [NSString stringWithFormat:@"%lu of %lu selected", (unsigned long)selectedCount,
                                 (unsigned long)self.services.count];
  self.selectAllButton.enabled = target != nil && selectedCount < self.services.count;
  self.clearButton.enabled = target != nil && selectedCount > 0;

  for (NSUInteger index = 0; index < self.permissionButtons.count; index++) {
    NSButton *checkbox = self.permissionButtons[index];
    NSImageView *icon = self.permissionIcons[index];
    NSBox *card = self.permissionCards[index];
    NSString *identifier = self.services[index].identifier;
    BOOL selected =
        target != nil && [target.serviceIdentifiers containsObject:identifier];
    checkbox.enabled = target != nil;
    checkbox.state = selected ? NSControlStateValueOn : NSControlStateValueOff;
    icon.contentTintColor =
        selected ? NSColor.controlAccentColor : NSColor.secondaryLabelColor;
    card.fillColor =
        selected ? [NSColor.selectedContentBackgroundColor colorWithAlphaComponent:0.12]
                 : NSColor.controlBackgroundColor;
    card.borderWidth = selected ? 1.0 : 0.0;
    card.borderColor = selected
                           ? [NSColor.controlAccentColor colorWithAlphaComponent:0.45]
                           : [NSColor.separatorColor colorWithAlphaComponent:0.55];
  }
}

- (void)updateEditorPresentation {
  PSTPermissionTargetDraft *target = self.selectedTarget;
  BOOL hasSelection = target != nil;
  self.sidebarEmptyState.hidden = self.targets.count > 0;
  self.detailEmptyState.hidden = hasSelection;
  self.detailEditor.hidden = !hasSelection;
  self.removeButton.enabled = hasSelection;
  self.targetCountLabel.stringValue =
      self.targets.count == 0
          ? @"No targets"
          : [NSString stringWithFormat:@"%lu target%@",
                                       (unsigned long)self.targets.count,
                                       self.targets.count == 1 ? @"" : @"s"];

  if (target != nil) {
    PSTEditorTargetKindProfile kindProfile =
        PSTEditorTargetKindProfileForKind(target.kind);
    self.targetIcon.image = PSTEditorImageForTarget(target, 56.0);
    self.targetTitle.stringValue =
        target.name.length > 0 ? target.name : @"Unnamed Target";
    NSString *source = target.pathCandidates.firstObject;
    NSString *sourceName = source.lastPathComponent;
    self.targetSubtitle.stringValue =
        sourceName.length > 0
            ? [NSString
                  stringWithFormat:@"%@ · %@", kindProfile.displayName, sourceName]
            : kindProfile.displayName;
    self.nameField.stringValue = target.name;
    self.identifierField.stringValue = target.identifier;
    self.sourceLabel.stringValue =
        source.length > 0 ? source : target.bundleIdentifiers.firstObject;
    self.requiredCheckbox.state =
        target.isRequired ? NSControlStateValueOn : NSControlStateValueOff;
  }
  [self updatePermissionPresentationForTarget:target];
  [self updateValidationPresentation];
}

- (void)updateValidationPresentation {
  NSError *error = nil;
  NSData *data =
      [PSTPermissionTargetsDocument dataWithTargets:self.targets
                          allowedServiceIdentifiers:self.allowedServiceIdentifiers
                                              error:&error];
  self.saveButton.enabled = data != nil;
  self.applyButton.enabled = data != nil;
  self.saveAndApplyButton.enabled = data != nil;
  if (data != nil) {
    self.validationLabel.stringValue =
        [NSString stringWithFormat:@"%lu target%@ ready to apply or save.",
                                   (unsigned long)self.targets.count,
                                   self.targets.count == 1 ? @"" : @"s"];
    self.validationLabel.textColor = NSColor.secondaryLabelColor;
    self.validationIcon.image = PSTUISymbol(@"checkmark.circle.fill", @"Ready to save",
                                            14.0, NSFontWeightMedium);
    self.validationIcon.contentTintColor = NSColor.systemGreenColor;
  } else {
    self.validationLabel.stringValue =
        error.localizedDescription != nil
            ? error.localizedDescription
            : @"Complete the target configuration before saving.";
    BOOL empty = self.targets.count == 0;
    self.validationLabel.textColor =
        empty ? NSColor.secondaryLabelColor : NSColor.systemRedColor;
    self.validationIcon.image = PSTUISymbol(
        empty ? @"info.circle" : @"exclamationmark.circle.fill",
        empty ? @"Editor status" : @"Configuration error", 14.0, NSFontWeightMedium);
    self.validationIcon.contentTintColor =
        empty ? NSColor.secondaryLabelColor : NSColor.systemRedColor;
  }
}

- (NSString *)uniqueIdentifierWithPrefix:(NSString *)prefix base:(NSString *)base {
  NSString *lowercaseBase = base.lowercaseString;
  NSCharacterSet *allowed = [NSCharacterSet
      characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789._-"];
  NSArray<NSString *> *components =
      [lowercaseBase componentsSeparatedByCharactersInSet:allowed.invertedSet];
  NSMutableArray<NSString *> *nonemptyComponents = [NSMutableArray array];
  for (NSString *component in components) {
    if (component.length > 0) {
      [nonemptyComponents addObject:component];
    }
  }
  NSString *normalizedBase = [nonemptyComponents componentsJoinedByString:@"-"];
  if (normalizedBase.length == 0) {
    normalizedBase = @"target";
  }
  NSString *candidate = [NSString stringWithFormat:@"%@:%@", prefix, normalizedBase];
  NSMutableSet<NSString *> *usedIdentifiers = [NSMutableSet set];
  for (PSTPermissionTargetDraft *target in self.targets) {
    [usedIdentifiers addObject:target.identifier];
  }
  NSUInteger suffix = 2;
  NSString *uniqueCandidate = candidate;
  while ([usedIdentifiers containsObject:uniqueCandidate]) {
    uniqueCandidate =
        [NSString stringWithFormat:@"%@-%lu", candidate, (unsigned long)suffix];
    suffix++;
  }
  return uniqueCandidate;
}

- (BOOL)addTargetFromURL:(NSURL *)URL kind:(PSTPermissionTargetKind)kind {
  PSTEditorTargetKindProfile kindProfile = PSTEditorTargetKindProfileForKind(kind);
  NSString *path = URL.path;
  NSString *bundleIdentifier = nil;
  NSString *name = nil;
  if (kindProfile.applicationBundle) {
    NSBundle *bundle = [NSBundle bundleWithURL:URL];
    if (bundle == nil) {
      return NO;
    }
    bundleIdentifier = bundle.bundleIdentifier;
    NSDictionary<NSString *, id> *info = bundle.localizedInfoDictionary != nil
                                             ? bundle.localizedInfoDictionary
                                             : bundle.infoDictionary;
    name = info[@"CFBundleDisplayName"];
    if (name.length == 0) {
      name = info[@"CFBundleName"];
    }
  } else {
    BOOL isDirectory = NO;
    BOOL exists =
        path.length > 0 && [NSFileManager.defaultManager fileExistsAtPath:path
                                                              isDirectory:&isDirectory];
    if (!exists || isDirectory ||
        ![NSFileManager.defaultManager isExecutableFileAtPath:path]) {
      return NO;
    }
  }
  if (name.length == 0) {
    name = URL.URLByDeletingPathExtension.lastPathComponent;
  }
  if (name.length == 0) {
    name = URL.lastPathComponent;
  }
  NSString *base = bundleIdentifier.length > 0 ? bundleIdentifier : name;
  NSArray<NSString *> *bundleIdentifiers = @[];
  if (bundleIdentifier.length > 0) {
    bundleIdentifiers = @[ (NSString *_Nonnull)bundleIdentifier ];
  }
  PSTPermissionTargetDraft *target = [[PSTPermissionTargetDraft alloc]
      initWithIdentifier:[self uniqueIdentifierWithPrefix:kindProfile.identifierPrefix
                                                     base:base]
                    name:name
                    kind:kind
       bundleIdentifiers:bundleIdentifiers
          pathCandidates:path.length > 0 ? @[ path ] : @[]
                required:NO
      serviceIdentifiers:@[]];
  [self.targets addObject:target];
  return YES;
}

- (void)finishAddingTargets {
  [self.targetsTable reloadData];
  NSInteger row = (NSInteger)self.targets.count - 1;
  if (row >= 0) {
    [self.targetsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row]
                   byExtendingSelection:NO];
    [self.targetsTable scrollRowToVisible:row];
  }
  [self updateEditorPresentation];
  [self.window makeFirstResponder:self.nameField];
}

- (void)showSourceAlertWithMessage:(NSString *)message {
  NSAlert *alert = [[NSAlert alloc] init];
  alert.alertStyle = NSAlertStyleWarning;
  alert.messageText = @"Unable to Add Target";
  alert.informativeText = message;
  NSWindow *window = self.window;
  if (window != nil) {
    [alert beginSheetModalForWindow:window completionHandler:nil];
  }
}

- (void)addTargetsOfKind:(PSTPermissionTargetKind)kind {
  PSTEditorTargetKindProfile kindProfile = PSTEditorTargetKindProfileForKind(kind);
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  panel.title = kindProfile.pickerTitle;
  panel.message = kindProfile.pickerMessage;
  panel.prompt = @"Add";
  panel.allowedContentTypes = @[ kindProfile.contentType ];
  panel.canChooseDirectories = NO;
  panel.canChooseFiles = YES;
  panel.allowsMultipleSelection = YES;
  NSWindow *window = self.window;
  if (window == nil) {
    return;
  }
  __weak PSTPermissionTargetsEditorController *weakSelf = self;
  [panel beginSheetModalForWindow:window
                completionHandler:^(NSModalResponse response) {
                  PSTPermissionTargetsEditorController *strongSelf = weakSelf;
                  if (strongSelf == nil || response != NSModalResponseOK) {
                    return;
                  }
                  NSUInteger added = 0;
                  for (NSURL *URL in panel.URLs) {
                    if ([strongSelf addTargetFromURL:URL kind:kind]) {
                      added++;
                    }
                  }
                  if (added == 0) {
                    [strongSelf
                        showSourceAlertWithMessage:kindProfile.invalidSelectionMessage];
                    return;
                  }
                  [strongSelf finishAddingTargets];
                }];
}

- (void)addApplication:(id)sender {
  (void)sender;
  [self addTargetsOfKind:PSTPermissionTargetKindApplicationBundle];
}

- (void)addExecutable:(id)sender {
  (void)sender;
  [self addTargetsOfKind:PSTPermissionTargetKindExecutable];
}

- (void)removeTarget:(id)sender {
  (void)sender;
  NSInteger selectedRow = self.targetsTable.selectedRow;
  if (selectedRow < 0 || (NSUInteger)selectedRow >= self.targets.count) {
    return;
  }
  [self.targets removeObjectAtIndex:(NSUInteger)selectedRow];
  [self.targetsTable reloadData];
  if (self.targets.count > 0) {
    NSUInteger nextRow = MIN((NSUInteger)selectedRow, self.targets.count - 1);
    [self.targetsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:nextRow]
                   byExtendingSelection:NO];
  }
  [self updateEditorPresentation];
}

- (void)togglePermission:(NSButton *)sender {
  PSTPermissionTargetDraft *target = self.selectedTarget;
  NSUInteger index = (NSUInteger)sender.tag;
  if (target == nil || index >= self.services.count) {
    return;
  }
  NSString *identifier = self.services[index].identifier;
  NSMutableArray<NSString *> *identifiers = [target.serviceIdentifiers mutableCopy];
  if (sender.state == NSControlStateValueOn) {
    if (![identifiers containsObject:identifier]) {
      [identifiers addObject:identifier];
    }
  } else {
    [identifiers removeObject:identifier];
  }
  target.serviceIdentifiers = identifiers;
  [self.targetsTable reloadData];
  [self updatePermissionPresentationForTarget:target];
  [self updateValidationPresentation];
}

- (void)selectAllPermissions:(id)sender {
  (void)sender;
  PSTPermissionTargetDraft *target = self.selectedTarget;
  if (target == nil) {
    return;
  }
  NSMutableArray<NSString *> *identifiers =
      [NSMutableArray arrayWithCapacity:self.services.count];
  for (PSTPermissionService *service in self.services) {
    [identifiers addObject:service.identifier];
  }
  target.serviceIdentifiers = identifiers;
  [self.targetsTable reloadData];
  [self updatePermissionPresentationForTarget:target];
  [self updateValidationPresentation];
}

- (void)clearPermissions:(id)sender {
  (void)sender;
  PSTPermissionTargetDraft *target = self.selectedTarget;
  if (target == nil) {
    return;
  }
  target.serviceIdentifiers = @[];
  [self.targetsTable reloadData];
  [self updatePermissionPresentationForTarget:target];
  [self updateValidationPresentation];
}

- (void)toggleRequired:(id)sender {
  (void)sender;
  PSTPermissionTargetDraft *target = self.selectedTarget;
  if (target == nil) {
    return;
  }
  target.required = self.requiredCheckbox.state == NSControlStateValueOn;
}

- (void)controlTextDidChange:(NSNotification *)notification {
  PSTPermissionTargetDraft *target = self.selectedTarget;
  if (target == nil) {
    return;
  }
  if (notification.object == self.nameField) {
    target.name = self.nameField.stringValue;
    self.targetTitle.stringValue =
        target.name.length > 0 ? target.name : @"Unnamed Target";
  } else if (notification.object == self.identifierField) {
    target.identifier = self.identifierField.stringValue;
  }
  [self.targetsTable reloadData];
  [self updateValidationPresentation];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
  return tableView == self.targetsTable ? (NSInteger)self.targets.count : 0;
}

- (nullable NSView *)tableView:(NSTableView *)tableView
            viewForTableColumn:(nullable NSTableColumn *)tableColumn
                           row:(NSInteger)row {
  (void)tableColumn;
  if (tableView != self.targetsTable || row < 0 ||
      (NSUInteger)row >= self.targets.count) {
    return nil;
  }
  PSTPermissionTargetDraft *target = self.targets[(NSUInteger)row];
  NSTableCellView *cell = [[NSTableCellView alloc] initWithFrame:NSZeroRect];

  NSImageView *icon = [[NSImageView alloc] initWithFrame:NSZeroRect];
  PSTEditorTargetKindProfile kindProfile =
      PSTEditorTargetKindProfileForKind(target.kind);
  icon.translatesAutoresizingMaskIntoConstraints = NO;
  icon.image = PSTEditorImageForTarget(target, 32.0);
  icon.imageScaling = NSImageScaleProportionallyUpOrDown;
  [icon setAccessibilityLabel:kindProfile.accessibilityName];

  NSTextField *name =
      PSTUILabel(target.name.length > 0 ? target.name : @"Unnamed Target");
  name.font = [NSFont systemFontOfSize:13.0 weight:NSFontWeightMedium];
  name.lineBreakMode = NSLineBreakByTruncatingTail;
  NSUInteger permissionCount = target.serviceIdentifiers.count;
  NSTextField *summary = PSTUILabel(
      [NSString stringWithFormat:@"%@ · %lu permission%@", kindProfile.compactName,
                                 (unsigned long)permissionCount,
                                 permissionCount == 1 ? @"" : @"s"]);
  summary.font = [NSFont systemFontOfSize:10.0];
  summary.textColor = NSColor.secondaryLabelColor;
  summary.lineBreakMode = NSLineBreakByTruncatingTail;
  NSStackView *text = PSTUIVerticalStack(@[ name, summary ], 2.0);
  NSStackView *rowStack = [NSStackView stackViewWithViews:@[ icon, text ]];
  rowStack.translatesAutoresizingMaskIntoConstraints = NO;
  rowStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  rowStack.alignment = NSLayoutAttributeCenterY;
  rowStack.spacing = 10.0;
  [cell addSubview:rowStack];
  [NSLayoutConstraint activateConstraints:@[
    [rowStack.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:8.0],
    [rowStack.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-8.0],
    [rowStack.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
    [icon.widthAnchor constraintEqualToConstant:32.0],
    [icon.heightAnchor constraintEqualToConstant:32.0],
  ]];
  return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
  if (notification.object == self.targetsTable) {
    [self updateEditorPresentation];
  }
}

- (NSDragOperation)tableView:(NSTableView *)tableView
                validateDrop:(id<NSDraggingInfo>)info
                 proposedRow:(NSInteger)row
       proposedDropOperation:(NSTableViewDropOperation)dropOperation {
  (void)row;
  (void)dropOperation;
  if (tableView != self.targetsTable || info.draggingSource == tableView) {
    return NSDragOperationNone;
  }
  NSArray<NSURL *> *URLs = [info.draggingPasteboard
      readObjectsForClasses:@[ NSURL.class ]
                    options:@{NSPasteboardURLReadingFileURLsOnlyKey : @YES}];
  return URLs.count > 0 ? NSDragOperationCopy : NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)tableView
       acceptDrop:(id<NSDraggingInfo>)info
              row:(NSInteger)row
    dropOperation:(NSTableViewDropOperation)dropOperation {
  (void)row;
  (void)dropOperation;
  if (tableView != self.targetsTable) {
    return NO;
  }
  NSArray<NSURL *> *URLs = [info.draggingPasteboard
      readObjectsForClasses:@[ NSURL.class ]
                    options:@{NSPasteboardURLReadingFileURLsOnlyKey : @YES}];
  NSUInteger added = 0;
  for (NSURL *URL in URLs) {
    NSBundle *bundle = [NSBundle bundleWithURL:URL];
    if (bundle != nil &&
        [URL.pathExtension caseInsensitiveCompare:@"app"] == NSOrderedSame) {
      if ([self addTargetFromURL:URL kind:PSTPermissionTargetKindApplicationBundle]) {
        added++;
      }
      continue;
    }
    if ([self addTargetFromURL:URL kind:PSTPermissionTargetKindExecutable]) {
      added++;
    }
  }
  if (added == 0) {
    [self showSourceAlertWithMessage:
              @"Drop an application bundle or an executable file."];
    return NO;
  }
  [self finishAddingTargets];
  return YES;
}

- (void)presentForWindow:(NSWindow *)parentWindow
              completion:(PSTPermissionTargetsEditorHandler)completion {
  self.completion = completion;
  self.result = nil;
  NSWindow *editorWindow = self.window;
  if (editorWindow == nil) {
    self.completion = nil;
    completion(nil);
    return;
  }
  __weak PSTPermissionTargetsEditorController *weakSelf = self;
  [parentWindow beginSheet:editorWindow
         completionHandler:^(NSModalResponse response) {
           PSTPermissionTargetsEditorController *strongSelf = weakSelf;
           if (strongSelf == nil) {
             return;
           }
           PSTPermissionTargetsEditorHandler handler = strongSelf.completion;
           PSTPermissionTargetsEditorResult *result =
               response == NSModalResponseOK ? strongSelf.result : nil;
           strongSelf.completion = nil;
           strongSelf.result = nil;
           if (handler != nil) {
             handler(result);
           }
         }];
}

- (void)cancelEditor:(id)sender {
  (void)sender;
  NSWindow *window = self.window;
  NSWindow *parent = window.sheetParent;
  if (window != nil && parent != nil) {
    [parent endSheet:window returnCode:NSModalResponseCancel];
  }
}

- (nullable NSData *)currentTargetsData {
  (void)[self.window makeFirstResponder:nil];
  NSError *error = nil;
  NSData *data =
      [PSTPermissionTargetsDocument dataWithTargets:self.targets
                          allowedServiceIdentifiers:self.allowedServiceIdentifiers
                                              error:&error];
  if (data == nil) {
    [self updateValidationPresentation];
  }
  return data;
}

- (void)finishWithTargetsData:(NSData *)data
                     savedURL:(nullable NSURL *)savedURL
                  shouldApply:(BOOL)shouldApply {
  self.result =
      [[PSTPermissionTargetsEditorResult alloc] initWithTargetsData:data
                                                           savedURL:savedURL
                                                        shouldApply:shouldApply];
  NSWindow *window = self.window;
  NSWindow *parent = window.sheetParent;
  if (window != nil && parent != nil) {
    [parent endSheet:window returnCode:NSModalResponseOK];
  }
}

- (void)applyTargets:(id)sender {
  (void)sender;
  NSData *data = [self currentTargetsData];
  if (data == nil) {
    return;
  }
  [self finishWithTargetsData:data savedURL:nil shouldApply:YES];
}

- (void)saveTargetsData:(NSData *)data shouldApply:(BOOL)shouldApply {
  NSSavePanel *panel = [NSSavePanel savePanel];
  panel.title = @"Save Permission Targets";
  panel.message = shouldApply
                      ? @"Save the target configuration, then review it for applying."
                      : @"Save the target configuration without applying it now.";
  panel.prompt = shouldApply ? @"Save & Apply" : @"Save";
  panel.nameFieldStringValue = PSTPermissionTargetsFilename;
  panel.allowedContentTypes = @[ UTTypeJSON ];
  panel.canCreateDirectories = YES;
  NSWindow *window = self.window;
  if (window == nil) {
    return;
  }
  __weak PSTPermissionTargetsEditorController *weakSelf = self;
  [panel
      beginSheetModalForWindow:window
             completionHandler:^(NSModalResponse response) {
               PSTPermissionTargetsEditorController *strongSelf = weakSelf;
               NSURL *URL = panel.URL;
               if (strongSelf == nil || response != NSModalResponseOK || URL == nil) {
                 return;
               }
               NSError *writeError = nil;
               if (![data writeToURL:URL
                             options:NSDataWritingAtomic
                               error:&writeError]) {
                 NSAlert *alert = [[NSAlert alloc] init];
                 alert.alertStyle = NSAlertStyleWarning;
                 alert.messageText = @"Unable to Save Permission Targets";
                 alert.informativeText =
                     writeError.localizedDescription != nil
                         ? writeError.localizedDescription
                         : @"The target configuration could not be written.";
                 [alert beginSheetModalForWindow:window completionHandler:nil];
                 return;
               }
               [strongSelf finishWithTargetsData:data
                                        savedURL:URL
                                     shouldApply:shouldApply];
             }];
}

- (void)saveTargets:(id)sender {
  (void)sender;
  NSData *data = [self currentTargetsData];
  if (data != nil) {
    [self saveTargetsData:data shouldApply:NO];
  }
}

- (void)saveAndApplyTargets:(id)sender {
  (void)sender;
  NSData *data = [self currentTargetsData];
  if (data != nil) {
    [self saveTargetsData:data shouldApply:YES];
  }
}

@end
