#ifndef PST_AUTHORIZATION_READINESS_H
#define PST_AUTHORIZATION_READINESS_H

#include "core/PSTC23.h"

#include <stddef.h>
#include <stdint.h>

typedef bool (*PSTAuthorizationReadinessProbe)(void *context);

[[nodiscard("readiness success or exhaustion must be handled")]]
bool pst_authorization_wait_until_ready(size_t maximum_attempts,
                                        uint64_t poll_interval_nanoseconds,
                                        PSTAuthorizationReadinessProbe probe,
                                        void *context);

#endif
