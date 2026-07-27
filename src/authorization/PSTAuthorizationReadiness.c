#include "authorization/PSTAuthorizationReadiness.h"

#include "core/PSTPlatformPoll.h"
#include "core/PSTPoll.h"

typedef struct PSTAuthorizationWaitContext {
  uint64_t interval_nanoseconds;
} PSTAuthorizationWaitContext;

static void pst_authorization_wait_between_probes(void *raw_context) {
  PSTAuthorizationWaitContext *context = raw_context;
  pst_platform_wait(context->interval_nanoseconds);
}

bool pst_authorization_wait_until_ready(size_t maximum_attempts,
                                        uint64_t poll_interval_nanoseconds,
                                        PSTAuthorizationReadinessProbe probe,
                                        void *context) {
  PSTAuthorizationWaitContext wait_context = {
      .interval_nanoseconds = poll_interval_nanoseconds,
  };
  return pst_poll_until_ready(
      maximum_attempts, probe, context,
      poll_interval_nanoseconds == 0 ? nullptr : pst_authorization_wait_between_probes,
      &wait_context);
}
