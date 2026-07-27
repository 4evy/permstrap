#include "authorization/PSTAuthorizationPlatform.h"

#include <assert.h>

int main(void) {
  assert(pst_authorization_realtime_nanoseconds() > 0);
  assert(pst_authorization_copy_secure_field(nullptr, nullptr, 0, 0) == nullptr);
  assert(!pst_authorization_focus_secure_field(nullptr, nullptr, 0, 0));
  assert(!pst_authorization_post_credential(0, nullptr));

  PSTSecureBuffer empty = {};
  assert(!pst_authorization_post_credential(0, &empty));
  return 0;
}
