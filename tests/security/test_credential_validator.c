#include "security/PSTCredentialValidator.h"
#include "security/PSTSecureBuffer.h"

#include <assert.h>
#include <string.h>

int main(void) {
  PSTSecureBuffer credential;
  assert(pst_secure_buffer_init(&credential, 64));

  char error[256] = {};
  assert(pst_validate_administrator_credential(&credential, error, sizeof(error)) ==
         PST_CREDENTIAL_VALIDATION_INVALID);
  assert(strstr(error, "empty") != nullptr);

  pst_secure_buffer_destroy(&credential);
  return 0;
}
