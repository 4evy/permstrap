#include "authorization/PSTAuthorizationInjectionTypes.h"

#include <assert.h>
#include <string.h>

int main(void) {
  assert(!pst_authorization_injection_result_is_retryable(
      PSTAuthorizationInjectionResultNoPrompt));
  assert(pst_authorization_injection_result_is_retryable(
      PSTAuthorizationInjectionResultAXUnavailable));
  assert(pst_authorization_injection_result_is_retryable(
      PSTAuthorizationInjectionResultSecureFieldMissing));
  assert(pst_authorization_injection_result_is_retryable(
      PSTAuthorizationInjectionResultFocusFailed));
  assert(pst_authorization_injection_result_is_retryable(
      PSTAuthorizationInjectionResultEventHostUnavailable));
  assert(pst_authorization_injection_result_is_retryable(
      PSTAuthorizationInjectionResultIdentityUnavailable));
  assert(!pst_authorization_injection_result_is_retryable(
      PSTAuthorizationInjectionResultRejected));

  assert(pst_authorization_injection_result_for_trusted_process_error(
             PSTTrustedProcessErrorProcessMissing) ==
         PSTAuthorizationInjectionResultIdentityUnavailable);
  assert(pst_authorization_injection_result_for_trusted_process_error(
             PSTTrustedProcessErrorIdentityUnavailable) ==
         PSTAuthorizationInjectionResultIdentityUnavailable);
  assert(pst_authorization_injection_result_for_trusted_process_error(
             PSTTrustedProcessErrorProcessTooOld) ==
         PSTAuthorizationInjectionResultRejected);
  assert(pst_authorization_injection_result_for_trusted_process_error(
             PSTTrustedProcessErrorSignatureInvalid) ==
         PSTAuthorizationInjectionResultRejected);
  assert(pst_authorization_injection_result_for_trusted_process_error(
             (PSTTrustedProcessError)UINT8_MAX) ==
         PSTAuthorizationInjectionResultRejected);

  assert(pst_authorization_injection_failure_description(
             PSTAuthorizationInjectionResultNoPrompt) == nullptr);
  const char *description = pst_authorization_injection_failure_description(
      PSTAuthorizationInjectionResultEventSubmissionFailed);
  assert(description != nullptr);
  assert(strstr(description, "Credential events") != nullptr);
  description = pst_authorization_injection_failure_description(
      PSTAuthorizationInjectionResultEventHostUnavailable);
  assert(description != nullptr);
  assert(strstr(description, "event host") != nullptr);
  description = pst_authorization_injection_failure_description(
      PSTAuthorizationInjectionResultIdentityUnavailable);
  assert(description != nullptr);
  assert(strstr(description, "identity stayed unavailable") != nullptr);
  assert(pst_authorization_injection_failure_description(
             (PSTAuthorizationInjectionResult)UINT8_MAX) == nullptr);
  return 0;
}
