#ifndef PST_AUTHORIZATION_PLATFORM_H
#define PST_AUTHORIZATION_PLATFORM_H

#include "core/PSTC23.h"
#include "security/PSTSecureBuffer.h"

#include <ApplicationServices/ApplicationServices.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>

[[nodiscard]] uint64_t pst_authorization_realtime_nanoseconds(void);

[[nodiscard]]
AXUIElementRef pst_authorization_copy_secure_field(
    AXUIElementRef agent, CFArrayRef reveal_button_titles, size_t maximum_attempts,
    uint64_t poll_interval_nanoseconds) CF_RETURNS_RETAINED;

[[nodiscard]]
bool pst_authorization_focus_secure_field(AXUIElementRef agent,
                                          AXUIElementRef secure_field,
                                          size_t maximum_attempts,
                                          uint64_t poll_interval_nanoseconds);

[[nodiscard]]
bool pst_authorization_post_credential(pid_t process_identifier,
                                       const PSTSecureBuffer *credential);

#endif
