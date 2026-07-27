#ifndef PST_PLATFORM_POLL_H
#define PST_PLATFORM_POLL_H

#include "core/PSTC23.h"

#include <stdint.h>

typedef enum PSTPlatformPollDecision : uint8_t {
  PSTPlatformPollDecisionContinue,
  PSTPlatformPollDecisionSucceeded,
  PSTPlatformPollDecisionStopped,
  PSTPlatformPollDecisionRestartDeadline,
} PSTPlatformPollDecision;

typedef enum PSTPlatformPollOutcome : uint8_t {
  PSTPlatformPollOutcomeInvalid,
  PSTPlatformPollOutcomeSucceeded,
  PSTPlatformPollOutcomeStopped,
  PSTPlatformPollOutcomeTimedOut,
} PSTPlatformPollOutcome;

typedef PSTPlatformPollDecision (*PSTPlatformPollProbe)(void *context);

void pst_platform_wait(uint64_t interval_nanoseconds);

[[nodiscard]]
PSTPlatformPollOutcome pst_platform_poll(uint64_t timeout_nanoseconds,
                                         uint64_t poll_interval_nanoseconds,
                                         PSTPlatformPollProbe probe, void *context);

#endif
