#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PSTUIFlippedView : NSView
@end

FOUNDATION_EXPORT NSTextField *PSTUILabel(NSString *text);
FOUNDATION_EXPORT NSImage *PSTUISymbol(NSString *name,
                                       NSString *accessibilityDescription,
                                       CGFloat pointSize, NSFontWeight weight);
FOUNDATION_EXPORT NSImageView *PSTUISymbolView(NSString *name,
                                               NSString *accessibilityDescription,
                                               CGFloat pointSize, NSColor *tint);
FOUNDATION_EXPORT NSView *PSTUIFlexibleSpace(void);
FOUNDATION_EXPORT NSStackView *PSTUIVerticalStack(NSArray<NSView *> *views,
                                                  CGFloat spacing);
FOUNDATION_EXPORT void PSTUIConfigureButton(NSButton *button, BOOL primary);
FOUNDATION_EXPORT NSBox *PSTUISeparator(void);
FOUNDATION_EXPORT NSView *PSTUIGroupPanel(NSTextField *heading, NSView *content);
FOUNDATION_EXPORT NSString *PSTUICountPhrase(NSUInteger count, NSString *singular,
                                             NSString *plural);
FOUNDATION_EXPORT NSImage *PSTUITargetIcon(NSArray<NSString *> *pathCandidates,
                                           BOOL executable, CGFloat size);

NS_ASSUME_NONNULL_END
