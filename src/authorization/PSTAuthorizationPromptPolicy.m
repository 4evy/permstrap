#import "authorization/PSTAuthorizationPromptPolicy.h"

#import "policy/PSTRuntimePolicy.h"

#include "core/PSTTextMatch.h"
#include "core/PSTTime.h"

#include <stdlib.h>
#include <string.h>

@interface PSTAuthorizationPromptPolicy ()

- (instancetype)
           initWithCandidateRequiredText:(NSArray<NSString *> *)candidateRequiredText
                        candidateAnyText:(NSArray<NSString *> *)candidateAnyText
                    expectedRequiredText:(NSArray<NSString *> *)expectedRequiredText
                         expectedAnyText:(NSArray<NSString *> *)expectedAnyText
            credentialRevealButtonTitles:
                (NSArray<NSString *> *)credentialRevealButtonTitles
          processAgeToleranceNanoseconds:(uint64_t)processAgeToleranceNanoseconds
           secureFieldAppearanceAttempts:(NSUInteger)secureFieldAppearanceAttempts
    secureFieldAppearancePollNanoseconds:(uint64_t)secureFieldAppearancePollNanoseconds
                   promptPollNanoseconds:(uint64_t)promptPollNanoseconds
    NS_DESIGNATED_INITIALIZER;

@end

static PSTTextView *PSTCreateTextViews(NSArray<NSString *> *strings,
                                       size_t *viewCount) {
  *viewCount = strings.count;
  size_t allocationCount = *viewCount == 0 ? 1 : *viewCount;
  PSTTextView *views = calloc(allocationCount, sizeof(*views));
  if (views == nullptr) {
    return nullptr;
  }
  for (size_t index = 0; index < *viewCount; ++index) {
    const char *text = strings[index].UTF8String;
    if (text == nullptr) {
      free(views);
      return nullptr;
    }
    views[index] = (PSTTextView){.data = text, .length = strlen(text)};
  }
  return views;
}

static BOOL PSTTextMatches(NSArray<NSString *> *visibleText,
                           NSArray<NSString *> *requiredText,
                           NSArray<NSString *> *anyText) {
  size_t visibleCount = 0;
  size_t requiredCount = 0;
  size_t anyCount = 0;
  PSTTextView *visibleViews = PSTCreateTextViews(visibleText, &visibleCount);
  PSTTextView *requiredViews = PSTCreateTextViews(requiredText, &requiredCount);
  PSTTextView *anyViews = PSTCreateTextViews(anyText, &anyCount);
  if (visibleViews == nullptr || requiredViews == nullptr || anyViews == nullptr) {
    free(visibleViews);
    free(requiredViews);
    free(anyViews);
    return NO;
  }

  BOOL matches = pst_text_views_match(visibleViews, visibleCount, requiredViews,
                                      requiredCount, anyViews, anyCount);
  free(visibleViews);
  free(requiredViews);
  free(anyViews);
  return matches;
}

@implementation PSTAuthorizationPromptPolicy

- (instancetype)
           initWithCandidateRequiredText:(NSArray<NSString *> *)candidateRequiredText
                        candidateAnyText:(NSArray<NSString *> *)candidateAnyText
                    expectedRequiredText:(NSArray<NSString *> *)expectedRequiredText
                         expectedAnyText:(NSArray<NSString *> *)expectedAnyText
            credentialRevealButtonTitles:
                (NSArray<NSString *> *)credentialRevealButtonTitles
          processAgeToleranceNanoseconds:(uint64_t)processAgeToleranceNanoseconds
           secureFieldAppearanceAttempts:(NSUInteger)secureFieldAppearanceAttempts
    secureFieldAppearancePollNanoseconds:(uint64_t)secureFieldAppearancePollNanoseconds
                   promptPollNanoseconds:(uint64_t)promptPollNanoseconds {
  self = [super init];
  if (self != nil) {
    _candidateRequiredText = [candidateRequiredText copy];
    _candidateAnyText = [candidateAnyText copy];
    _expectedRequiredText = [expectedRequiredText copy];
    _expectedAnyText = [expectedAnyText copy];
    _credentialRevealButtonTitles = [credentialRevealButtonTitles copy];
    _processAgeToleranceNanoseconds = processAgeToleranceNanoseconds;
    _secureFieldAppearanceAttempts = secureFieldAppearanceAttempts;
    _secureFieldAppearancePollNanoseconds = secureFieldAppearancePollNanoseconds;
    _promptPollNanoseconds = promptPollNanoseconds;
  }
  return self;
}

- (BOOL)matchesCandidateText:(NSArray<NSString *> *)visibleText {
  return PSTTextMatches(visibleText, self.candidateRequiredText, self.candidateAnyText);
}

- (BOOL)matchesExpectedText:(NSArray<NSString *> *)visibleText {
  return PSTTextMatches(visibleText, self.expectedRequiredText, self.expectedAnyText);
}

@end

PSTAuthorizationPromptPolicy *PSTCurrentAuthorizationPromptPolicy(void) {
  static PSTAuthorizationPromptPolicy *policy;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSDictionary<NSString *, id> *configuration =
        PSTCurrentRuntimePolicy().authorizationPrompt;
    NSDictionary<NSString *, id> *candidateText = configuration[@"candidateText"];
    NSDictionary<NSString *, id> *expectedText = configuration[@"expectedText"];
    NSDictionary<NSString *, NSNumber *> *timing = configuration[@"timing"];
    NSNumber *processAge = timing[@"processAgeToleranceMilliseconds"];
    NSNumber *appearanceAttempts = timing[@"secureFieldAppearanceAttempts"];
    NSNumber *appearancePoll = timing[@"secureFieldAppearancePollMilliseconds"];
    NSNumber *promptPoll = timing[@"promptPollMilliseconds"];
    policy = [[PSTAuthorizationPromptPolicy alloc]
               initWithCandidateRequiredText:candidateText[@"required"]
                            candidateAnyText:candidateText[@"any"]
                        expectedRequiredText:expectedText[@"required"]
                             expectedAnyText:expectedText[@"any"]
                credentialRevealButtonTitles:configuration
                                                 [@"credentialRevealButtonTitles"]
              processAgeToleranceNanoseconds:processAge.unsignedLongLongValue *
                                             PST_NANOSECONDS_PER_MILLISECOND
               secureFieldAppearanceAttempts:appearanceAttempts.unsignedIntegerValue
        secureFieldAppearancePollNanoseconds:appearancePoll.unsignedLongLongValue *
                                             PST_NANOSECONDS_PER_MILLISECOND
                       promptPollNanoseconds:promptPoll.unsignedLongLongValue *
                                             PST_NANOSECONDS_PER_MILLISECOND];
  });
  return policy;
}
