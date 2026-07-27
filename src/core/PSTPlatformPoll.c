#include "core/PSTPlatformPoll.h"

#include "core/PSTTime.h"

#include <errno.h>
#include <stdckdint.h>
#include <time.h>

static bool pst_monotonic_nanoseconds(uint64_t *result) {
  struct timespec value = {};
  if (result == nullptr || clock_gettime(CLOCK_MONOTONIC, &value) != 0 ||
      value.tv_sec < 0 || value.tv_nsec < 0 ||
      value.tv_nsec >= (long)PST_NANOSECONDS_PER_SECOND) {
    return false;
  }
  const uint64_t seconds = (uint64_t)value.tv_sec;
  const uint64_t nanoseconds = (uint64_t)value.tv_nsec;
  uint64_t whole_nanoseconds = 0;
  return !ckd_mul(&whole_nanoseconds, seconds, PST_NANOSECONDS_PER_SECOND) &&
         !ckd_add(result, whole_nanoseconds, nanoseconds);
}

static uint64_t pst_saturated_add(uint64_t lhs, uint64_t rhs) {
  uint64_t result = 0;
  return ckd_add(&result, lhs, rhs) ? UINT64_MAX : result;
}

void pst_platform_wait(uint64_t interval_nanoseconds) {
  const uint64_t seconds = interval_nanoseconds / PST_NANOSECONDS_PER_SECOND;
  const uint64_t nanoseconds = interval_nanoseconds % PST_NANOSECONDS_PER_SECOND;
  if (seconds > (uint64_t)INT64_MAX) {
    return;
  }
  struct timespec remaining = {
      .tv_sec = (time_t)seconds,
      .tv_nsec = (long)nanoseconds,
  };
  while (nanosleep(&remaining, &remaining) != 0 && errno == EINTR) {
  }
}

PSTPlatformPollOutcome pst_platform_poll(uint64_t timeout_nanoseconds,
                                         uint64_t poll_interval_nanoseconds,
                                         PSTPlatformPollProbe probe, void *context) {
  uint64_t now = 0;
  if (timeout_nanoseconds == 0 || probe == nullptr ||
      !pst_monotonic_nanoseconds(&now)) {
    return PSTPlatformPollOutcomeInvalid;
  }
  uint64_t deadline = pst_saturated_add(now, timeout_nanoseconds);
  for (;;) {
    if (!pst_monotonic_nanoseconds(&now)) {
      return PSTPlatformPollOutcomeInvalid;
    }
    if (now >= deadline) {
      return PSTPlatformPollOutcomeTimedOut;
    }
    switch (probe(context)) {
    case PSTPlatformPollDecisionSucceeded:
      return PSTPlatformPollOutcomeSucceeded;
    case PSTPlatformPollDecisionStopped:
      return PSTPlatformPollOutcomeStopped;
    case PSTPlatformPollDecisionRestartDeadline:
      if (!pst_monotonic_nanoseconds(&now)) {
        return PSTPlatformPollOutcomeInvalid;
      }
      deadline = pst_saturated_add(now, timeout_nanoseconds);
      break;
    case PSTPlatformPollDecisionContinue:
      break;
    }
    pst_platform_wait(poll_interval_nanoseconds);
  }
}
