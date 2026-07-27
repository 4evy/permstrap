#include "authorization/PSTAuthorizationInjectionTypes.h"

#include <stddef.h>

typedef struct PSTAuthorizationInjectionResultPolicy {
  PSTAuthorizationInjectionResult result;
  bool retryable;
  const char *failure_description;
} PSTAuthorizationInjectionResultPolicy;

static const PSTAuthorizationInjectionResultPolicy
    PST_AUTHORIZATION_INJECTION_RESULT_POLICIES[] = {
        {
            .result = PSTAuthorizationInjectionResultNoPrompt,
        },
        {
            .result = PSTAuthorizationInjectionResultInjected,
        },
        {
            .result = PSTAuthorizationInjectionResultRejected,
            .failure_description =
                "The authorization prompt failed identity or UI validation; "
                "no password was entered.",
        },
        {
            .result = PSTAuthorizationInjectionResultIdentityUnavailable,
            .retryable = true,
            .failure_description =
                "The authorization host identity stayed unavailable until the "
                "readiness deadline; no password was entered.",
        },
        {
            .result = PSTAuthorizationInjectionResultAXUnavailable,
            .retryable = true,
            .failure_description =
                "The verified authorization host AX tree stayed unavailable "
                "until the readiness deadline.",
        },
        {
            .result = PSTAuthorizationInjectionResultSecureFieldMissing,
            .retryable = true,
            .failure_description =
                "The verified authorization prompt did not expose a secure "
                "password field before the readiness deadline.",
        },
        {
            .result = PSTAuthorizationInjectionResultFocusFailed,
            .retryable = true,
            .failure_description =
                "The verified authorization prompt password field did not "
                "accept focus before the readiness deadline.",
        },
        {
            .result = PSTAuthorizationInjectionResultEventHostUnavailable,
            .retryable = true,
            .failure_description =
                "The verified authorization event host did not become ready "
                "before the readiness deadline.",
        },
        {
            .result = PSTAuthorizationInjectionResultEventSubmissionFailed,
            .failure_description =
                "Credential events could not be submitted to the verified "
                "authorization prompt.",
        },
};

static const PSTAuthorizationInjectionResultPolicy *
pst_authorization_injection_policy(PSTAuthorizationInjectionResult result) {
  for (size_t index = 0;
       index < PST_ARRAY_COUNT(PST_AUTHORIZATION_INJECTION_RESULT_POLICIES); ++index) {
    if (PST_AUTHORIZATION_INJECTION_RESULT_POLICIES[index].result == result) {
      return &PST_AUTHORIZATION_INJECTION_RESULT_POLICIES[index];
    }
  }
  return nullptr;
}

bool pst_authorization_injection_result_is_retryable(
    PSTAuthorizationInjectionResult result) {
  const PSTAuthorizationInjectionResultPolicy *policy =
      pst_authorization_injection_policy(result);
  return policy != nullptr && policy->retryable;
}

PSTAuthorizationInjectionResult
pst_authorization_injection_result_for_trusted_process_error(
    PSTTrustedProcessError error) {
  switch (error) {
  case PSTTrustedProcessErrorProcessMissing:
  case PSTTrustedProcessErrorIdentityUnavailable:
    return PSTAuthorizationInjectionResultIdentityUnavailable;
  case PSTTrustedProcessErrorUnexpectedUser:
  case PSTTrustedProcessErrorProcessTooOld:
  case PSTTrustedProcessErrorPolicyMissing:
  case PSTTrustedProcessErrorInstanceMismatch:
  case PSTTrustedProcessErrorSignatureInvalid:
  case PSTTrustedProcessErrorPathInvalid:
    return PSTAuthorizationInjectionResultRejected;
  }
  return PSTAuthorizationInjectionResultRejected;
}

const char *pst_authorization_injection_failure_description(
    PSTAuthorizationInjectionResult result) {
  const PSTAuthorizationInjectionResultPolicy *policy =
      pst_authorization_injection_policy(result);
  return policy != nullptr ? policy->failure_description : nullptr;
}
