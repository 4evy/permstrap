#ifndef PST_TRUSTED_PROCESS_TYPES_H
#define PST_TRUSTED_PROCESS_TYPES_H

#include <stdint.h>

typedef enum PSTTrustedProcessError : uint8_t {
  PSTTrustedProcessErrorProcessMissing = 1,
  PSTTrustedProcessErrorUnexpectedUser,
  PSTTrustedProcessErrorProcessTooOld,
  PSTTrustedProcessErrorIdentityUnavailable,
  PSTTrustedProcessErrorPolicyMissing,
  PSTTrustedProcessErrorInstanceMismatch,
  PSTTrustedProcessErrorSignatureInvalid,
  PSTTrustedProcessErrorPathInvalid,
} PSTTrustedProcessError;

#endif
