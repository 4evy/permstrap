#include "security/PSTTrustedProcessValidation.h"

#include <assert.h>
#include <string.h>
#include <unistd.h>

int main(void) {
  assert(pst_trusted_process_validation_public_error(
             PSTTrustedProcessValidationErrorProcessMissing) ==
         PSTTrustedProcessErrorProcessMissing);
  assert(strcmp(pst_trusted_process_validation_error_description(
                    PSTTrustedProcessValidationErrorSignatureInvalid),
                "Trusted UI process failed Apple validation.") == 0);
  assert(pst_trusted_process_validation_public_error(
             (PSTTrustedProcessValidationError)UINT8_MAX) ==
         PSTTrustedProcessErrorIdentityUnavailable);
  assert(pst_trusted_process_validation_error_description(
             (PSTTrustedProcessValidationError)UINT8_MAX) != nullptr);

  uint64_t start_time = 0;
  assert(pst_process_start_time(getpid(), &start_time));
  assert(start_time > 0);
  assert(!pst_process_start_time(0, &start_time));
  assert(!pst_process_start_time(getpid(), nullptr));

  PSTTrustedProcessIdentity identity = {};
  PSTTrustedProcessValidationError error = PSTTrustedProcessValidationErrorNone;
  assert(!pst_trusted_process_validate_identity(0, 0, &identity, &error));
  assert(error == PSTTrustedProcessValidationErrorProcessMissing);
  assert(identity.code_identifier[0] == '\0');
  assert(identity.executable_path[0] == '\0');
  return 0;
}
