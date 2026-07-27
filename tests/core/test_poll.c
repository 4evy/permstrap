#include "core/PSTPoll.h"

#include <assert.h>

typedef struct {
  size_t probe_count;
  size_t wait_count;
  size_t ready_on_probe;
} PSTProbeFixture;

static bool probe(void *context) {
  PSTProbeFixture *fixture = context;
  ++fixture->probe_count;
  return fixture->probe_count == fixture->ready_on_probe;
}

static void wait_between_probes(void *context) {
  PSTProbeFixture *fixture = context;
  ++fixture->wait_count;
}

int main(void) {
  PSTProbeFixture delayed = {.ready_on_probe = 3};
  assert(pst_poll_until_ready(4, probe, &delayed, wait_between_probes, &delayed));
  assert(delayed.probe_count == 3);
  assert(delayed.wait_count == 2);

  PSTProbeFixture immediate = {.ready_on_probe = 1};
  assert(pst_poll_until_ready(4, probe, &immediate, wait_between_probes, &immediate));
  assert(immediate.probe_count == 1);
  assert(immediate.wait_count == 0);

  PSTProbeFixture exhausted = {.ready_on_probe = 4};
  assert(!pst_poll_until_ready(3, probe, &exhausted, nullptr, nullptr));
  assert(exhausted.probe_count == 3);
  assert(exhausted.wait_count == 0);

  PSTProbeFixture skipped = {.ready_on_probe = 1};
  assert(!pst_poll_until_ready(0, probe, &skipped, wait_between_probes, &skipped));
  assert(skipped.probe_count == 0);
  return 0;
}
