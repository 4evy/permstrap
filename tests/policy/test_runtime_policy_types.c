#include "policy/PSTRuntimePolicyTypes.h"

#include <assert.h>

int main(void) {
  PSTTrustedProcessRole role = {};
  assert(pst_trusted_process_role_parse("authorization-observer", &role));
  assert(role == PSTTrustedProcessRoleAuthorizationObserver);
  assert(pst_trusted_process_role_parse("authorization-ax-host", &role));
  assert(role == PSTTrustedProcessRoleAuthorizationAXHost);
  assert(pst_trusted_process_role_parse("authorization-event-host", &role));
  assert(role == PSTTrustedProcessRoleAuthorizationEventHost);
  assert(!pst_trusted_process_role_parse("unknown", &role));
  return 0;
}
