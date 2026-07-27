#ifndef PST_RUNTIME_POLICY_TYPES_H
#define PST_RUNTIME_POLICY_TYPES_H

#include "core/PSTC23.h"

#include <stdint.h>

constexpr uint64_t PST_RUNTIME_POLICY_VERSION = 1;

typedef enum PSTTrustedProcessRole : uint8_t {
  PSTTrustedProcessRoleAuthorizationObserver = 1U << 0,
  PSTTrustedProcessRoleAuthorizationAXHost = 1U << 1,
  PSTTrustedProcessRoleAuthorizationEventHost = 1U << 2,
} PSTTrustedProcessRole;

static_assert(sizeof(PSTTrustedProcessRole) == sizeof(uint8_t));

[[nodiscard]] bool pst_trusted_process_role_parse(const char *identifier,
                                                  PSTTrustedProcessRole *role);

#endif
