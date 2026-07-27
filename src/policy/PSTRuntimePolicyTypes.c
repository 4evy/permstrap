#include "policy/PSTRuntimePolicyTypes.h"

#include <stddef.h>
#include <string.h>

typedef struct PSTTrustedProcessRoleEntry {
  const char *identifier;
  PSTTrustedProcessRole role;
} PSTTrustedProcessRoleEntry;

static const PSTTrustedProcessRoleEntry PST_TRUSTED_PROCESS_ROLES[] = {
    {
        .identifier = "authorization-observer",
        .role = PSTTrustedProcessRoleAuthorizationObserver,
    },
    {
        .identifier = "authorization-ax-host",
        .role = PSTTrustedProcessRoleAuthorizationAXHost,
    },
    {
        .identifier = "authorization-event-host",
        .role = PSTTrustedProcessRoleAuthorizationEventHost,
    },
};

bool pst_trusted_process_role_parse(const char *identifier,
                                    PSTTrustedProcessRole *role) {
  if (identifier == nullptr || role == nullptr) {
    return false;
  }
  for (size_t index = 0; index < PST_ARRAY_COUNT(PST_TRUSTED_PROCESS_ROLES); ++index) {
    if (strcmp(identifier, PST_TRUSTED_PROCESS_ROLES[index].identifier) == 0) {
      *role = PST_TRUSTED_PROCESS_ROLES[index].role;
      return true;
    }
  }
  return false;
}
