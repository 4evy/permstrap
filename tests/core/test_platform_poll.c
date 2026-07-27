#include "core/PSTPlatformPoll.h"

#include <assert.h>
#include <stddef.h>

typedef struct Fixture {
  size_t probes;
  bool restart_first;
} Fixture;

static PSTPlatformPollDecision succeed(void *raw_context) {
  Fixture *fixture = raw_context;
  ++fixture->probes;
  if (fixture->restart_first && fixture->probes == 1) {
    return PSTPlatformPollDecisionRestartDeadline;
  }
  return PSTPlatformPollDecisionSucceeded;
}

static PSTPlatformPollDecision stop(void *raw_context) {
  Fixture *fixture = raw_context;
  ++fixture->probes;
  return PSTPlatformPollDecisionStopped;
}

static PSTPlatformPollDecision keep_polling(void *raw_context) {
  Fixture *fixture = raw_context;
  ++fixture->probes;
  return PSTPlatformPollDecisionContinue;
}

int main(void) {
  Fixture fixture = {};
  assert(pst_platform_poll(1000000000, 0, succeed, &fixture) ==
         PSTPlatformPollOutcomeSucceeded);
  assert(fixture.probes == 1);

  fixture = (Fixture){.restart_first = true};
  assert(pst_platform_poll(1000000000, 0, succeed, &fixture) ==
         PSTPlatformPollOutcomeSucceeded);
  assert(fixture.probes == 2);

  fixture = (Fixture){};
  assert(pst_platform_poll(1000000000, 0, stop, &fixture) ==
         PSTPlatformPollOutcomeStopped);
  assert(fixture.probes == 1);

  fixture = (Fixture){};
  assert(pst_platform_poll(1000000, 0, keep_polling, &fixture) ==
         PSTPlatformPollOutcomeTimedOut);
  assert(fixture.probes > 0);
  assert(pst_platform_poll(0, 0, succeed, &fixture) == PSTPlatformPollOutcomeInvalid);
  assert(pst_platform_poll(1, 0, nullptr, &fixture) == PSTPlatformPollOutcomeInvalid);
  return 0;
}
