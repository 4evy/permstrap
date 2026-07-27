#ifndef PST_AUTHORIZATION_INJECTION_TYPES_H
#define PST_AUTHORIZATION_INJECTION_TYPES_H

#include "core/PSTC23.h"
#include "security/PSTTrustedProcessTypes.h"

#include <stdint.h>

typedef enum PSTAuthorizationInjectionResult : uint8_t {
  PSTAuthorizationInjectionResultNoPrompt = 0,
  PSTAuthorizationInjectionResultInjected,
  PSTAuthorizationInjectionResultRejected,
  PSTAuthorizationInjectionResultIdentityUnavailable,
  PSTAuthorizationInjectionResultAXUnavailable,
  PSTAuthorizationInjectionResultSecureFieldMissing,
  PSTAuthorizationInjectionResultFocusFailed,
  PSTAuthorizationInjectionResultEventHostUnavailable,
  PSTAuthorizationInjectionResultEventSubmissionFailed,
} PSTAuthorizationInjectionResult;

static_assert(sizeof(PSTAuthorizationInjectionResult) == sizeof(uint8_t));

[[nodiscard]]
bool pst_authorization_injection_result_is_retryable(
    PSTAuthorizationInjectionResult result);

[[nodiscard]]
PSTAuthorizationInjectionResult
pst_authorization_injection_result_for_trusted_process_error(
    PSTTrustedProcessError error);

[[nodiscard]]
const char *
pst_authorization_injection_failure_description(PSTAuthorizationInjectionResult result);

#endif
