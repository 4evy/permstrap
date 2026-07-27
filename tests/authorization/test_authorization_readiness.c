#include "authorization/PSTAuthorizationReadiness.h"

#include <assert.h>
#include <stddef.h>

typedef struct PSTReadinessFixture {
  size_t probes;
  size_t ready_on_probe;
} PSTReadinessFixture;

static bool readiness_probe(void *raw_context) {
  PSTReadinessFixture *fixture = raw_context;
  ++fixture->probes;
  return fixture->probes == fixture->ready_on_probe;
}

int main(void) {
  PSTReadinessFixture delayed = {.ready_on_probe = 3};
  assert(pst_authorization_wait_until_ready(4, 0, readiness_probe, &delayed));
  assert(delayed.probes == 3);

  PSTReadinessFixture immediate = {.ready_on_probe = 1};
  assert(pst_authorization_wait_until_ready(4, 0, readiness_probe, &immediate));
  assert(immediate.probes == 1);

  PSTReadinessFixture exhausted = {.ready_on_probe = 4};
  assert(!pst_authorization_wait_until_ready(3, 0, readiness_probe, &exhausted));
  assert(exhausted.probes == 3);

  PSTReadinessFixture skipped = {.ready_on_probe = 1};
  assert(!pst_authorization_wait_until_ready(0, 0, readiness_probe, &skipped));
  assert(skipped.probes == 0);
  return 0;
}
