#ifndef PST_RUNTIME_POLICY_VALIDATION_H
#define PST_RUNTIME_POLICY_VALIDATION_H

#include "core/PSTC23.h"
#include "core/PSTYyjson.h"

#include <stddef.h>
#include <stdint.h>

typedef enum PSTRuntimePolicyValidationCode : uint8_t {
  PSTRuntimePolicyValidationInvalidJSON = 1,
  PSTRuntimePolicyValidationUnsupportedVersion,
  PSTRuntimePolicyValidationInvalidAuthorizationPrompt,
  PSTRuntimePolicyValidationInvalidSystemSettings,
  PSTRuntimePolicyValidationInvalidTrustedProcess,
  PSTRuntimePolicyValidationDuplicateTrustedProcess,
  PSTRuntimePolicyValidationInvalidRelationship,
} PSTRuntimePolicyValidationCode;

typedef struct PSTRuntimePolicyValidationError {
  PSTRuntimePolicyValidationCode code;
  size_t byte_position;
  char path[PST_JSON_DIAGNOSTIC_CAPACITY];
  char description[PST_JSON_DIAGNOSTIC_CAPACITY];
} PSTRuntimePolicyValidationError;

[[nodiscard]] bool pst_runtime_policy_validate(const void *data, size_t length,
                                               PSTRuntimePolicyValidationError *error);

#endif
