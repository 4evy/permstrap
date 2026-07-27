#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

__attribute__((objc_subclassing_restricted))
@interface PSTAuthorizationPromptPolicy : NSObject

@property(nonatomic, copy, readonly) NSArray<NSString *> *candidateRequiredText;
@property(nonatomic, copy, readonly) NSArray<NSString *> *candidateAnyText;
@property(nonatomic, copy, readonly) NSArray<NSString *> *expectedRequiredText;
@property(nonatomic, copy, readonly) NSArray<NSString *> *expectedAnyText;
@property(nonatomic, copy, readonly) NSArray<NSString *> *credentialRevealButtonTitles;
@property(nonatomic, readonly) uint64_t processAgeToleranceNanoseconds;
@property(nonatomic, readonly) NSUInteger secureFieldAppearanceAttempts;
@property(nonatomic, readonly) uint64_t secureFieldAppearancePollNanoseconds;
@property(nonatomic, readonly) uint64_t promptPollNanoseconds;

- (instancetype)init NS_UNAVAILABLE;
- (BOOL)matchesCandidateText:(NSArray<NSString *> *)visibleText;
- (BOOL)matchesExpectedText:(NSArray<NSString *> *)visibleText;

@end

FOUNDATION_EXPORT PSTAuthorizationPromptPolicy *
PSTCurrentAuthorizationPromptPolicy(void);

NS_ASSUME_NONNULL_END
