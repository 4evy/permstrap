#ifndef PST_TRUSTED_PROCESS_VALIDATION_H
#define PST_TRUSTED_PROCESS_VALIDATION_H

#include "core/PSTC23.h"
#include "security/PSTTrustedProcessTypes.h"

#include <limits.h>
#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>

constexpr size_t PST_TRUSTED_PROCESS_IDENTIFIER_CAPACITY = 1'024;

typedef enum PSTTrustedProcessValidationError : uint8_t {
  PSTTrustedProcessValidationErrorNone,
  PSTTrustedProcessValidationErrorProcessMissing,
  PSTTrustedProcessValidationErrorUnexpectedUser,
  PSTTrustedProcessValidationErrorProcessTooOld,
  PSTTrustedProcessValidationErrorIdentityUnavailable,
  PSTTrustedProcessValidationErrorSignatureInvalid,
  PSTTrustedProcessValidationErrorPathInvalid,
} PSTTrustedProcessValidationError;

typedef struct PSTTrustedProcessIdentity {
  char code_identifier[PST_TRUSTED_PROCESS_IDENTIFIER_CAPACITY];
  char executable_path[PATH_MAX];
} PSTTrustedProcessIdentity;

[[nodiscard]] PSTTrustedProcessError
pst_trusted_process_validation_public_error(PSTTrustedProcessValidationError error);

[[nodiscard]] const char *pst_trusted_process_validation_error_description(
    PSTTrustedProcessValidationError error);

[[nodiscard]]
bool pst_process_start_time(pid_t process_identifier, uint64_t *start_time_nanoseconds);

[[nodiscard("trusted-process identity validation must be handled")]]
bool pst_trusted_process_validate_identity(pid_t process_identifier,
                                           uint64_t not_before_nanoseconds,
                                           PSTTrustedProcessIdentity *identity,
                                           PSTTrustedProcessValidationError *error);

#endif
