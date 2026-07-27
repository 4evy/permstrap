#ifndef PST_CREDENTIAL_VALIDATOR_H
#define PST_CREDENTIAL_VALIDATOR_H

#include "security/PSTSecureBuffer.h"

#include <stddef.h>

constexpr size_t PST_CREDENTIAL_VALIDATION_ERROR_CAPACITY = 4'096;

typedef enum PSTCredentialValidationResult : unsigned char {
  PST_CREDENTIAL_VALIDATION_OK = 0,
  PST_CREDENTIAL_VALIDATION_INVALID = 1,
  PST_CREDENTIAL_VALIDATION_UNAVAILABLE = 2,
} PSTCredentialValidationResult;

[[nodiscard("credential validation result must be handled")]]
PSTCredentialValidationResult
pst_validate_administrator_credential(const PSTSecureBuffer *credential,
                                      char *error_message,
                                      size_t error_message_capacity);

#endif
