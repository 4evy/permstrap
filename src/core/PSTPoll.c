#include "core/PSTPoll.h"

bool pst_poll_until_ready(size_t maximum_attempts, PSTPollProbe probe,
                          void *probe_context, PSTPollWait wait, void *wait_context) {
  if (maximum_attempts == 0 || probe == nullptr) {
    return false;
  }
  for (size_t attempt = 0; attempt < maximum_attempts; ++attempt) {
    if (attempt > 0 && wait != nullptr) {
      wait(wait_context);
    }
    if (probe(probe_context)) {
      return true;
    }
  }
  return false;
}
