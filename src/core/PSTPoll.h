#ifndef PST_POLL_H
#define PST_POLL_H

#include "core/PSTC23.h"

#include <stddef.h>

typedef bool (*PSTPollProbe)(void *context);
typedef void (*PSTPollWait)(void *context);

[[nodiscard("polling success or exhaustion must be handled")]]
bool pst_poll_until_ready(size_t maximum_attempts, PSTPollProbe probe,
                          void *probe_context, PSTPollWait wait, void *wait_context);

#endif
