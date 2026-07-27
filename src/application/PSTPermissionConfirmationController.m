#import "application/PSTPermissionConfirmationController.h"

#import "application/PSTUIComponents.h"
#import "permissions/PSTPermissionManifest.h"

static NSUserInterfaceItemIdentifier const PSTPermissionCellIdentifier =
    @"PSTPermissionCell";
static NSUserInterfaceItemIdentifier const PSTTargetCellIdentifier = @"PSTTargetCell";
constexpr CGFloat PST_CONFIRMATION_WINDOW_WIDTH = 820.0;
constexpr CGFloat PST_CONFIRMATION_WINDOW_HEIGHT = 570.0;
constexpr CGFloat PST_CONFIRMATION_PANEL_HEIGHT = 340.0;
constexpr CGFloat PST_PERMISSION_ROW_HEIGHT = 58.0;
constexpr CGFloat PST_TARGET_ROW_HEIGHT = 44.0;
constexpr CGFloat PST_CONFIRMATION_TABLE_INITIAL_HEIGHT = 300.0;

@interface PSTPermissionConfirmationController ()

@property(nonatomic, strong) PSTPermissionManifest *manifest;
@property(nonatomic, copy) NSArray<PSTPermissionService *> *allServices;
@property(nonatomic, copy) NSArray<PSTPermissionService *> *displayedServices;
@property(nonatomic, copy) NSArray<PSTPermissionTarget *> *targets;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSImage *> *targetIcons;
@property(nonatomic, strong) NSTextField *permissionsHeading;
@property(nonatomic, strong) NSTableView *permissionsTable;
@property(nonatomic, strong) NSTableView *targetsTable;
@property(nonatomic, strong) NSScrollView *permissionsScrollView;
@property(nonatomic, strong) NSScrollView *targetsScrollView;
@property(nonatomic, assign) BOOL usesUniformPermissionSet;
@property(nonatomic, copy) PSTPermissionConfirmationHandler completion;

- (void)buildContent;
- (NSTableView *)tableWithIdentifier:(NSUserInterfaceItemIdentifier)identifier
                               width:(CGFloat)width
                           rowHeight:(CGFloat)rowHeight
                     alternatingRows:(BOOL)alternatingRows
                          selectable:(BOOL)selectable;
- (NSTableCellView *)permissionCellWithWidth:(CGFloat)width;
- (NSTableCellView *)targetCellWithWidth:(CGFloat)width;
- (void)showAllPermissions;
- (void)updatePermissionScroller;
- (NSImage *)iconForTarget:(PSTPermissionTarget *)target;

@end

@implementation PSTPermissionConfirmationController

static NSScrollView *PSTConfirmationScrollView(NSTableView *table,
                                               BOOL hasVerticalScroller) {
  NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
  scrollView.translatesAutoresizingMaskIntoConstraints = NO;
  scrollView.hasVerticalScroller = hasVerticalScroller;
  scrollView.autohidesScrollers = YES;
  scrollView.borderType = NSNoBorder;
  scrollView.drawsBackground = YES;
  scrollView.backgroundColor = NSColor.controlBackgroundColor;
  scrollView.documentView = table;
  return scrollView;
}

static void PSTConfirmationAddCellSeparator(NSTableCellView *cell) {
  NSBox *separator = PSTUISeparator();
  [cell addSubview:separator];
  [NSLayoutConstraint activateConstraints:@[
    [separator.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:12.0],
    [separator.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor
                                             constant:-12.0],
    [separator.bottomAnchor constraintEqualToAnchor:cell.bottomAnchor],
    [separator.heightAnchor constraintEqualToConstant:1.0],
  ]];
}

- (instancetype)initWithManifest:(PSTPermissionManifest *)manifest {
  NSWindow *sheet = [[NSWindow alloc]
      initWithContentRect:NSMakeRect(0, 0, PST_CONFIRMATION_WINDOW_WIDTH,
                                     PST_CONFIRMATION_WINDOW_HEIGHT)
                styleMask:NSWindowStyleMaskTitled
                  backing:NSBackingStoreBuffered
                    defer:NO];
  self = [super initWithWindow:sheet];
  if (self == nil) {
    return nil;
  }

  _manifest = manifest;
  _targets = manifest.targets;
  _targetIcons = [NSMutableDictionary dictionary];

  PSTPermissionConfirmationDataSource source =
      PSTPermissionManifestConfirmationDataSource();
  NSMutableArray<PSTPermissionService *> *usedServices = [NSMutableArray array];
  for (size_t index = 0; index < source.service_count((__bridge void *)manifest);
       ++index) {
    PSTPermissionService *service = manifest.services[index];
    if (pst_permission_confirmation_service_is_used(
            &source, (__bridge void *)manifest,
            source.service_at(index, (__bridge void *)manifest))) {
      [usedServices addObject:service];
    }
  }
  _allServices = [usedServices copy];
  _displayedServices = _allServices;

  _usesUniformPermissionSet = pst_permission_confirmation_targets_are_uniform(
      &source, (__bridge void *)manifest);

  sheet.title = @"Review Permission Changes";
  sheet.restorable = NO;
  sheet.contentMinSize =
      NSMakeSize(PST_CONFIRMATION_WINDOW_WIDTH, PST_CONFIRMATION_WINDOW_HEIGHT);
  sheet.titlebarSeparatorStyle = NSTitlebarSeparatorStyleNone;
  [self buildContent];
  return self;
}

- (void)buildContent {
  PSTUIFlippedView *content = [[PSTUIFlippedView alloc]
      initWithFrame:NSMakeRect(0, 0, PST_CONFIRMATION_WINDOW_WIDTH,
                               PST_CONFIRMATION_WINDOW_HEIGHT)];
  self.window.contentView = content;
  [NSLayoutConstraint activateConstraints:@[
    [content.widthAnchor constraintEqualToConstant:PST_CONFIRMATION_WINDOW_WIDTH],
    [content.heightAnchor constraintEqualToConstant:PST_CONFIRMATION_WINDOW_HEIGHT],
  ]];

  NSImageView *headerIcon = [[NSImageView alloc] initWithFrame:NSZeroRect];
  headerIcon.translatesAutoresizingMaskIntoConstraints = NO;
  headerIcon.image = NSApp.applicationIconImage;
  headerIcon.imageScaling = NSImageScaleProportionallyUpOrDown;
  [headerIcon setAccessibilityLabel:@"Permstrap"];
  [NSLayoutConstraint activateConstraints:@[
    [headerIcon.widthAnchor constraintEqualToConstant:50.0],
    [headerIcon.heightAnchor constraintEqualToConstant:50.0],
  ]];
  NSTextField *title = PSTUILabel(@"Review Permission Changes");
  title.font = [NSFont systemFontOfSize:24.0 weight:NSFontWeightSemibold];
  NSTextField *subtitle = PSTUILabel(
      @"Confirm which privacy permissions this workflow will add or enable.");
  subtitle.font = [NSFont systemFontOfSize:13.0];
  subtitle.textColor = NSColor.secondaryLabelColor;
  NSStackView *titleStack = PSTUIVerticalStack(@[ title, subtitle ], 4.0);
  NSStackView *headerStack =
      [NSStackView stackViewWithViews:@[ headerIcon, titleStack ]];
  headerStack.translatesAutoresizingMaskIntoConstraints = NO;
  headerStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  headerStack.alignment = NSLayoutAttributeCenterY;
  headerStack.spacing = 16.0;

  NSString *summaryText = [NSString
      stringWithFormat:@"%@  •  %@",
                       PSTUICountPhrase(self.targets.count, @"target", @"targets"),
                       PSTUICountPhrase(self.allServices.count, @"permission type",
                                        @"permission types")];
  NSTextField *summary = PSTUILabel(summaryText);
  summary.font = [NSFont systemFontOfSize:12.0 weight:NSFontWeightSemibold];
  summary.textColor = NSColor.secondaryLabelColor;

  self.permissionsHeading = PSTUILabel(@"");
  self.permissionsHeading.font = [NSFont systemFontOfSize:13.0
                                                   weight:NSFontWeightSemibold];
  NSTextField *targetsHeading = PSTUILabel(
      [NSString stringWithFormat:@"Targets (%lu)", (unsigned long)self.targets.count]);
  targetsHeading.font = [NSFont systemFontOfSize:13.0 weight:NSFontWeightSemibold];

  self.permissionsTable = [self tableWithIdentifier:@"permissions"
                                              width:350.0
                                          rowHeight:PST_PERMISSION_ROW_HEIGHT
                                    alternatingRows:NO
                                         selectable:NO];
  [self.permissionsTable setAccessibilityLabel:@"Permissions"];
  self.permissionsScrollView =
      PSTConfirmationScrollView(self.permissionsTable, self.allServices.count > 5);

  self.targetsTable = [self tableWithIdentifier:@"targets"
                                          width:350.0
                                      rowHeight:PST_TARGET_ROW_HEIGHT
                                alternatingRows:NO
                                     selectable:!self.usesUniformPermissionSet];
  [self.targetsTable setAccessibilityLabel:@"Targets"];
  NSUInteger targetRowCount =
      self.targets.count + (self.usesUniformPermissionSet ? 0U : 1U);
  self.targetsScrollView =
      PSTConfirmationScrollView(self.targetsTable, targetRowCount > 6);

  NSView *permissionsPanel =
      PSTUIGroupPanel(self.permissionsHeading, self.permissionsScrollView);
  NSView *targetsPanel = PSTUIGroupPanel(targetsHeading, self.targetsScrollView);
  [permissionsPanel.heightAnchor
      constraintEqualToConstant:PST_CONFIRMATION_PANEL_HEIGHT]
      .active = YES;
  [targetsPanel.heightAnchor constraintEqualToConstant:PST_CONFIRMATION_PANEL_HEIGHT]
      .active = YES;

  NSStackView *lists = [NSStackView stackViewWithViews:@[
    permissionsPanel,
    targetsPanel,
  ]];
  lists.translatesAutoresizingMaskIntoConstraints = NO;
  lists.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  lists.alignment = NSLayoutAttributeTop;
  lists.distribution = NSStackViewDistributionFillEqually;
  lists.spacing = 18.0;

  NSImageView *privacyIcon = PSTUISymbolView(@"lock.fill", @"Password protection", 13.0,
                                             NSColor.secondaryLabelColor);
  NSTextField *privacyText = PSTUILabel(
      @"Your validated password remains in locked memory and is used only for "
       "verified Apple authorization prompts opened by this workflow.");
  privacyText.font = [NSFont systemFontOfSize:11.0];
  privacyText.textColor = NSColor.secondaryLabelColor;
  privacyText.maximumNumberOfLines = 2;
  privacyText.lineBreakMode = NSLineBreakByWordWrapping;
  NSStackView *privacyRow =
      [NSStackView stackViewWithViews:@[ privacyIcon, privacyText ]];
  privacyRow.translatesAutoresizingMaskIntoConstraints = NO;
  privacyRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  privacyRow.alignment = NSLayoutAttributeTop;
  privacyRow.spacing = 8.0;
  NSBox *footerSeparator = PSTUISeparator();

  NSButton *cancelButton = [NSButton buttonWithTitle:@"Cancel"
                                              target:self
                                              action:@selector(cancelConfirmation:)];
  cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
  cancelButton.controlSize = NSControlSizeLarge;
  cancelButton.keyEquivalent = @"\033";
  PSTUIConfigureButton(cancelButton, NO);

  NSButton *grantButton = [NSButton buttonWithTitle:@"Grant Permissions"
                                             target:self
                                             action:@selector(confirmPermissions:)];
  grantButton.translatesAutoresizingMaskIntoConstraints = NO;
  grantButton.controlSize = NSControlSizeLarge;
  grantButton.image =
      PSTUISymbol(@"checkmark.shield", @"Grant permissions", 13.0, NSFontWeightMedium);
  grantButton.imagePosition = NSImageLeading;
  grantButton.imageHugsTitle = YES;
  grantButton.keyEquivalent = @"\r";
  PSTUIConfigureButton(grantButton, YES);

  NSStackView *buttonRow = [NSStackView stackViewWithViews:@[
    PSTUIFlexibleSpace(),
    cancelButton,
    grantButton,
  ]];
  buttonRow.translatesAutoresizingMaskIntoConstraints = NO;
  buttonRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  buttonRow.alignment = NSLayoutAttributeCenterY;
  buttonRow.spacing = 10.0;

  NSStackView *root = PSTUIVerticalStack(
      @[
        headerStack,
        summary,
        lists,
        footerSeparator,
        privacyRow,
        buttonRow,
      ],
      12.0);
  [content addSubview:root];
  [NSLayoutConstraint activateConstraints:@[
    [root.topAnchor constraintEqualToAnchor:content.topAnchor constant:24.0],
    [root.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:32.0],
    [root.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-32.0],
    [root.bottomAnchor constraintLessThanOrEqualToAnchor:content.bottomAnchor
                                                constant:-24.0],
    [headerStack.widthAnchor constraintEqualToAnchor:root.widthAnchor],
    [summary.widthAnchor constraintEqualToAnchor:root.widthAnchor],
    [lists.widthAnchor constraintEqualToAnchor:root.widthAnchor],
    [footerSeparator.widthAnchor constraintEqualToAnchor:root.widthAnchor],
    [privacyRow.widthAnchor constraintEqualToAnchor:root.widthAnchor],
    [buttonRow.widthAnchor constraintEqualToAnchor:root.widthAnchor],
  ]];

  [self.targetsTable reloadData];
  [self.permissionsTable reloadData];
  if (!self.usesUniformPermissionSet) {
    [self.targetsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0]
                   byExtendingSelection:NO];
  }
  [self showAllPermissions];
}

- (NSTableView *)tableWithIdentifier:(NSUserInterfaceItemIdentifier)identifier
                               width:(CGFloat)width
                           rowHeight:(CGFloat)rowHeight
                     alternatingRows:(BOOL)alternatingRows
                          selectable:(BOOL)selectable {
  NSTableView *table = [[NSTableView alloc]
      initWithFrame:NSMakeRect(0, 0, width, PST_CONFIRMATION_TABLE_INITIAL_HEIGHT)];
  table.identifier = identifier;
  table.headerView = nil;
  table.rowHeight = rowHeight;
  table.rowSizeStyle = NSTableViewRowSizeStyleCustom;
  table.intercellSpacing = NSMakeSize(0, 0);
  table.usesAlternatingRowBackgroundColors = alternatingRows;
  table.backgroundColor = NSColor.controlBackgroundColor;
  table.style = selectable ? NSTableViewStyleInset : NSTableViewStyleFullWidth;
  table.gridStyleMask = NSTableViewGridNone;
  table.allowsMultipleSelection = NO;
  table.allowsEmptySelection = YES;
  table.selectionHighlightStyle = selectable ? NSTableViewSelectionHighlightStyleRegular
                                             : NSTableViewSelectionHighlightStyleNone;
  table.dataSource = self;
  table.delegate = self;

  NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:identifier];
  column.width = width;
  column.resizingMask = NSTableColumnAutoresizingMask;
  [table addTableColumn:column];
  return table;
}

- (void)presentForWindow:(NSWindow *)parentWindow
              completion:(PSTPermissionConfirmationHandler)completion {
  self.completion = completion;
  NSWindow *confirmationWindow = self.window;
  if (confirmationWindow == nil) {
    self.completion = nil;
    completion(NO);
    return;
  }
  [confirmationWindow setContentSize:confirmationWindow.contentMinSize];
  __weak PSTPermissionConfirmationController *weakSelf = self;
  [parentWindow beginSheet:confirmationWindow
         completionHandler:^(NSModalResponse response) {
           PSTPermissionConfirmationController *strongSelf = weakSelf;
           if (strongSelf == nil) {
             return;
           }
           PSTPermissionConfirmationHandler handler = strongSelf.completion;
           strongSelf.completion = nil;
           if (handler != nil) {
             handler(response == NSModalResponseOK);
           }
         }];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
  if (tableView == self.permissionsTable) {
    return (NSInteger)self.displayedServices.count;
  }
  if (tableView == self.targetsTable) {
    NSUInteger overviewRows = self.usesUniformPermissionSet ? 0U : 1U;
    return (NSInteger)(self.targets.count + overviewRows);
  }
  return 0;
}

- (nullable NSView *)tableView:(NSTableView *)tableView
            viewForTableColumn:(nullable NSTableColumn *)tableColumn
                           row:(NSInteger)row {
  (void)tableColumn;
  if (row < 0) {
    return nil;
  }

  if (tableView == self.permissionsTable) {
    NSUInteger index = (NSUInteger)row;
    if (index >= self.displayedServices.count) {
      return nil;
    }
    NSTableCellView *cell =
        (NSTableCellView *)[tableView makeViewWithIdentifier:PSTPermissionCellIdentifier
                                                       owner:self];
    if (cell == nil) {
      cell = [self permissionCellWithWidth:tableView.bounds.size.width];
    }
    PSTPermissionService *service = self.displayedServices[index];
    cell.imageView.image =
        PSTUISymbol(service.symbolName, service.name, 18.0, NSFontWeightMedium);
    cell.textField.stringValue = service.name;
    NSTextField *detail = (NSTextField *)[cell viewWithTag:1];
    detail.stringValue =
        service.serviceDescription != nil ? service.serviceDescription : @"";
    return cell;
  }

  if (tableView != self.targetsTable) {
    return nil;
  }
  NSTableCellView *cell =
      (NSTableCellView *)[tableView makeViewWithIdentifier:PSTTargetCellIdentifier
                                                     owner:self];
  if (cell == nil) {
    cell = [self targetCellWithWidth:tableView.bounds.size.width];
  }
  NSTextField *detail = (NSTextField *)[cell viewWithTag:1];

  if (!self.usesUniformPermissionSet && row == 0) {
    cell.imageView.image =
        PSTUISymbol(@"square.grid.2x2.fill", @"All targets", 16.0, NSFontWeightRegular);
    cell.imageView.contentTintColor = NSColor.secondaryLabelColor;
    cell.textField.stringValue = @"All Targets";
    detail.hidden = NO;
    detail.stringValue = @"Overview";
    return cell;
  }

  NSInteger targetOffset = self.usesUniformPermissionSet ? 0 : 1;
  NSInteger targetRow = row - targetOffset;
  if (targetRow < 0) {
    return nil;
  }
  NSUInteger targetIndex = (NSUInteger)targetRow;
  if (targetIndex >= self.targets.count) {
    return nil;
  }
  PSTPermissionTarget *target = self.targets[targetIndex];
  cell.imageView.image = [self iconForTarget:target];
  cell.imageView.contentTintColor = nil;
  cell.textField.stringValue = target.name;
  detail.hidden = self.usesUniformPermissionSet;
  if (!self.usesUniformPermissionSet) {
    detail.stringValue = [NSString
        stringWithFormat:@"%lu %@", (unsigned long)target.serviceIdentifiers.count,
                         target.serviceIdentifiers.count == 1 ? @"permission"
                                                              : @"permissions"];
  }
  return cell;
}

- (NSTableCellView *)permissionCellWithWidth:(CGFloat)width {
  NSTableCellView *cell = [[NSTableCellView alloc]
      initWithFrame:NSMakeRect(0, 0, width, PST_PERMISSION_ROW_HEIGHT)];
  cell.identifier = PSTPermissionCellIdentifier;

  NSImageView *imageView = [[NSImageView alloc] initWithFrame:NSZeroRect];
  imageView.translatesAutoresizingMaskIntoConstraints = NO;
  imageView.imageScaling = NSImageScaleProportionallyDown;
  imageView.contentTintColor = NSColor.controlAccentColor;
  cell.imageView = imageView;
  [cell addSubview:imageView];

  NSTextField *textField = PSTUILabel(@"");
  textField.font = [NSFont systemFontOfSize:12.0 weight:NSFontWeightMedium];
  textField.lineBreakMode = NSLineBreakByTruncatingTail;
  cell.textField = textField;

  NSTextField *detail = PSTUILabel(@"");
  detail.tag = 1;
  detail.font = [NSFont systemFontOfSize:10.0];
  detail.textColor = NSColor.secondaryLabelColor;
  detail.maximumNumberOfLines = 2;
  detail.lineBreakMode = NSLineBreakByWordWrapping;
  NSStackView *text = PSTUIVerticalStack(@[ textField, detail ], 2.0);
  [cell addSubview:text];
  PSTConfirmationAddCellSeparator(cell);
  [NSLayoutConstraint activateConstraints:@[
    [imageView.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:12.0],
    [imageView.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
    [imageView.widthAnchor constraintEqualToConstant:24.0],
    [imageView.heightAnchor constraintEqualToConstant:24.0],
    [text.leadingAnchor constraintEqualToAnchor:imageView.trailingAnchor constant:10.0],
    [text.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-12.0],
    [text.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
    [textField.widthAnchor constraintEqualToAnchor:text.widthAnchor],
    [detail.widthAnchor constraintEqualToAnchor:text.widthAnchor],
  ]];
  return cell;
}

- (NSTableCellView *)targetCellWithWidth:(CGFloat)width {
  NSTableCellView *cell = [[NSTableCellView alloc]
      initWithFrame:NSMakeRect(0, 0, width, PST_TARGET_ROW_HEIGHT)];
  cell.identifier = PSTTargetCellIdentifier;

  NSImageView *imageView = [[NSImageView alloc] initWithFrame:NSZeroRect];
  imageView.translatesAutoresizingMaskIntoConstraints = NO;
  imageView.imageScaling = NSImageScaleProportionallyDown;
  cell.imageView = imageView;
  [cell addSubview:imageView];

  NSTextField *textField = PSTUILabel(@"");
  textField.font = [NSFont systemFontOfSize:12.0 weight:NSFontWeightMedium];
  textField.lineBreakMode = NSLineBreakByTruncatingTail;
  cell.textField = textField;
  [cell addSubview:textField];

  NSTextField *detail = PSTUILabel(@"");
  detail.tag = 1;
  detail.font = [NSFont systemFontOfSize:10.0];
  detail.textColor = NSColor.secondaryLabelColor;
  detail.alignment = NSTextAlignmentRight;
  detail.lineBreakMode = NSLineBreakByTruncatingTail;
  [cell addSubview:detail];
  PSTConfirmationAddCellSeparator(cell);
  [detail setContentHuggingPriority:NSLayoutPriorityDefaultHigh
                     forOrientation:NSLayoutConstraintOrientationHorizontal];
  [NSLayoutConstraint activateConstraints:@[
    [imageView.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:12.0],
    [imageView.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
    [imageView.widthAnchor constraintEqualToConstant:24.0],
    [imageView.heightAnchor constraintEqualToConstant:24.0],
    [textField.leadingAnchor constraintEqualToAnchor:imageView.trailingAnchor
                                            constant:10.0],
    [textField.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
    [detail.leadingAnchor constraintGreaterThanOrEqualToAnchor:textField.trailingAnchor
                                                      constant:8.0],
    [detail.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-12.0],
    [detail.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
  ]];
  return cell;
}

- (NSImage *)iconForTarget:(PSTPermissionTarget *)target {
  NSImage *cached = self.targetIcons[target.inventoryIdentifier];
  if (cached != nil) {
    return cached;
  }

  NSImage *icon = PSTUITargetIcon(
      target.pathCandidates, target.kind == PSTPermissionTargetKindExecutable, 24.0);
  self.targetIcons[target.inventoryIdentifier] = icon;
  return icon;
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
  return !self.usesUniformPermissionSet && tableView == self.targetsTable && row >= 0;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
  if (self.usesUniformPermissionSet || notification.object != self.targetsTable) {
    return;
  }
  NSInteger row = self.targetsTable.selectedRow;
  if (row <= 0) {
    [self showAllPermissions];
    return;
  }

  NSUInteger targetIndex = (NSUInteger)(row - 1);
  if (targetIndex >= self.targets.count) {
    [self showAllPermissions];
    return;
  }
  PSTPermissionTarget *target = self.targets[targetIndex];
  NSMutableArray<PSTPermissionService *> *services = [NSMutableArray array];
  for (NSString *identifier in target.serviceIdentifiers) {
    PSTPermissionService *service = [self.manifest serviceForIdentifier:identifier];
    if (service != nil) {
      [services addObject:service];
    }
  }
  self.displayedServices = services;
  self.permissionsHeading.stringValue =
      [NSString stringWithFormat:@"Permissions for %@ (%lu)", target.name,
                                 (unsigned long)services.count];
  [self.permissionsTable reloadData];
  [self updatePermissionScroller];
}

- (void)showAllPermissions {
  self.displayedServices = self.allServices;
  self.permissionsHeading.stringValue = [NSString
      stringWithFormat:@"Permissions (%lu)", (unsigned long)self.allServices.count];
  [self.permissionsTable reloadData];
  [self updatePermissionScroller];
}

- (void)updatePermissionScroller {
  self.permissionsScrollView.hasVerticalScroller = self.displayedServices.count > 5;
}

- (void)cancelConfirmation:(id)sender {
  (void)sender;
  NSWindow *confirmationWindow = self.window;
  NSWindow *parentWindow = confirmationWindow.sheetParent;
  if (confirmationWindow != nil && parentWindow != nil) {
    [parentWindow endSheet:confirmationWindow returnCode:NSModalResponseCancel];
  }
}

- (void)confirmPermissions:(id)sender {
  (void)sender;
  NSWindow *confirmationWindow = self.window;
  NSWindow *parentWindow = confirmationWindow.sheetParent;
  if (confirmationWindow != nil && parentWindow != nil) {
    [parentWindow endSheet:confirmationWindow returnCode:NSModalResponseOK];
  }
}

@end
