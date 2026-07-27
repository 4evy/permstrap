#include "security/PSTTrustedProcessValidation.h"

#include "core/PSTTime.h"

#include <CoreFoundation/CoreFoundation.h>
#include <Security/Security.h>
#include <libproc.h>
#include <stdckdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/proc_info.h>
#include <unistd.h>

typedef struct PSTTrustedProcessValidationFailurePolicy {
  PSTTrustedProcessValidationError validation_error;
  PSTTrustedProcessError public_error;
  const char *description;
} PSTTrustedProcessValidationFailurePolicy;

static const PSTTrustedProcessValidationFailurePolicy
    pst_trusted_process_validation_failure_policies[] = {
        {
            PSTTrustedProcessValidationErrorNone,
            PSTTrustedProcessErrorIdentityUnavailable,
            "Trusted UI identity validation failed.",
        },
        {
            PSTTrustedProcessValidationErrorProcessMissing,
            PSTTrustedProcessErrorProcessMissing,
            "Trusted UI process no longer exists.",
        },
        {
            PSTTrustedProcessValidationErrorUnexpectedUser,
            PSTTrustedProcessErrorUnexpectedUser,
            "Trusted UI process has an unexpected user.",
        },
        {
            PSTTrustedProcessValidationErrorProcessTooOld,
            PSTTrustedProcessErrorProcessTooOld,
            "Trusted UI process predates the armed operation.",
        },
        {
            PSTTrustedProcessValidationErrorIdentityUnavailable,
            PSTTrustedProcessErrorIdentityUnavailable,
            "Unable to inspect trusted UI code identity.",
        },
        {
            PSTTrustedProcessValidationErrorSignatureInvalid,
            PSTTrustedProcessErrorSignatureInvalid,
            "Trusted UI process failed Apple validation.",
        },
        {
            PSTTrustedProcessValidationErrorPathInvalid,
            PSTTrustedProcessErrorPathInvalid,
            "Trusted UI process path could not be resolved.",
        },
};

static const PSTTrustedProcessValidationFailurePolicy *
pst_trusted_process_validation_failure_policy(
    PSTTrustedProcessValidationError validation_error) {
  for (size_t index = 0;
       index < PST_ARRAY_COUNT(pst_trusted_process_validation_failure_policies);
       ++index) {
    if (pst_trusted_process_validation_failure_policies[index].validation_error ==
        validation_error) {
      return &pst_trusted_process_validation_failure_policies[index];
    }
  }
  return &pst_trusted_process_validation_failure_policies[0];
}

PSTTrustedProcessError
pst_trusted_process_validation_public_error(PSTTrustedProcessValidationError error) {
  return pst_trusted_process_validation_failure_policy(error)->public_error;
}

const char *pst_trusted_process_validation_error_description(
    PSTTrustedProcessValidationError error) {
  return pst_trusted_process_validation_failure_policy(error)->description;
}

static bool pst_copy_process_info(pid_t process_identifier,
                                  struct proc_bsdinfo *process_info) {
  static_assert(sizeof(*process_info) <= INT_MAX);
  int copied = proc_pidinfo(process_identifier, PROC_PIDTBSDINFO, 0, process_info,
                            (int)sizeof(*process_info));
  return copied == (int)sizeof(*process_info);
}

bool pst_process_start_time(pid_t process_identifier,
                            uint64_t *start_time_nanoseconds) {
  if (start_time_nanoseconds == nullptr || process_identifier <= 0) {
    return false;
  }
  struct proc_bsdinfo process_info = {};
  if (!pst_copy_process_info(process_identifier, &process_info)) {
    return false;
  }
  uint64_t seconds = process_info.pbi_start_tvsec;
  uint64_t microseconds = process_info.pbi_start_tvusec;
  if (microseconds >= PST_MICROSECONDS_PER_SECOND) {
    return false;
  }
  uint64_t fractional_nanoseconds = 0;
  uint64_t whole_nanoseconds = 0;
  return !ckd_mul(&fractional_nanoseconds, microseconds,
                  PST_NANOSECONDS_PER_MICROSECOND) &&
         !ckd_mul(&whole_nanoseconds, seconds, PST_NANOSECONDS_PER_SECOND) &&
         !ckd_add(start_time_nanoseconds, whole_nanoseconds, fractional_nanoseconds);
}

static SecCodeRef pst_copy_code_for_process(pid_t process_identifier) {
  CFNumberRef process_number =
      CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &process_identifier);
  if (process_number == nullptr) {
    return nullptr;
  }
  const void *keys[] = {kSecGuestAttributePid};
  const void *values[] = {process_number};
  CFDictionaryRef attributes = CFDictionaryCreate(kCFAllocatorDefault, keys, values, 1,
                                                  &kCFTypeDictionaryKeyCallBacks,
                                                  &kCFTypeDictionaryValueCallBacks);
  CFRelease(process_number);
  if (attributes == nullptr) {
    return nullptr;
  }
  SecCodeRef code = nullptr;
  OSStatus status =
      SecCodeCopyGuestWithAttributes(nullptr, attributes, kSecCSDefaultFlags, &code);
  CFRelease(attributes);
  return status == errSecSuccess ? code : nullptr;
}

static CFStringRef pst_copy_code_identifier(SecCodeRef code) {
  CFDictionaryRef signing_information = nullptr;
  OSStatus status = SecCodeCopySigningInformation(code, kSecCSSigningInformation,
                                                  &signing_information);
  if (status != errSecSuccess || signing_information == nullptr) {
    return nullptr;
  }
  CFTypeRef raw_identifier =
      CFDictionaryGetValue(signing_information, kSecCodeInfoIdentifier);
  CFStringRef identifier = nullptr;
  if (raw_identifier != nullptr && CFGetTypeID(raw_identifier) == CFStringGetTypeID()) {
    identifier = CFStringCreateCopy(kCFAllocatorDefault, (CFStringRef)raw_identifier);
  }
  CFRelease(signing_information);
  return identifier;
}

static bool pst_code_has_apple_signature(SecCodeRef code) {
  SecRequirementRef requirement = nullptr;
  OSStatus status = SecRequirementCreateWithString(CFSTR("anchor apple"),
                                                   kSecCSDefaultFlags, &requirement);
  if (status == errSecSuccess) {
    status = SecCodeCheckValidity(code, kSecCSStrictValidate, requirement);
  }
  if (requirement != nullptr) {
    CFRelease(requirement);
  }
  return status == errSecSuccess;
}

static bool pst_copy_process_path(pid_t process_identifier,
                                  char destination[PATH_MAX]) {
  char process_path[PROC_PIDPATHINFO_MAXSIZE] = {};
  static_assert(sizeof(process_path) <= UINT32_MAX);
  if (proc_pidpath(process_identifier, process_path, (uint32_t)sizeof(process_path)) <=
      0) {
    return false;
  }
  char resolved_path[PATH_MAX] = {};
  if (realpath(process_path, resolved_path) == nullptr) {
    return false;
  }
  size_t length = strlen(resolved_path);
  if (length >= PATH_MAX) {
    return false;
  }
  memcpy(destination, resolved_path, length + 1);
  return true;
}

static bool pst_validation_failed(PSTTrustedProcessValidationError code,
                                  PSTTrustedProcessValidationError *error) {
  if (error != nullptr) {
    *error = code;
  }
  return false;
}

bool pst_trusted_process_validate_identity(pid_t process_identifier,
                                           uint64_t not_before_nanoseconds,
                                           PSTTrustedProcessIdentity *identity,
                                           PSTTrustedProcessValidationError *error) {
  if (identity != nullptr) {
    *identity = (PSTTrustedProcessIdentity){};
  }
  if (error != nullptr) {
    *error = PSTTrustedProcessValidationErrorNone;
  }
  struct proc_bsdinfo process_info = {};
  if (process_identifier <= 0 ||
      !pst_copy_process_info(process_identifier, &process_info)) {
    return pst_validation_failed(PSTTrustedProcessValidationErrorProcessMissing, error);
  }
  if (process_info.pbi_uid != getuid()) {
    return pst_validation_failed(PSTTrustedProcessValidationErrorUnexpectedUser, error);
  }

  uint64_t start_time = 0;
  if (!pst_process_start_time(process_identifier, &start_time) ||
      start_time < not_before_nanoseconds) {
    return pst_validation_failed(PSTTrustedProcessValidationErrorProcessTooOld, error);
  }
  if (identity == nullptr) {
    return pst_validation_failed(PSTTrustedProcessValidationErrorIdentityUnavailable,
                                 error);
  }

  SecCodeRef code = pst_copy_code_for_process(process_identifier);
  if (code == nullptr) {
    return pst_validation_failed(PSTTrustedProcessValidationErrorIdentityUnavailable,
                                 error);
  }
  CFStringRef identifier = pst_copy_code_identifier(code);
  if (identifier == nullptr ||
      !CFStringGetCString(identifier, identity->code_identifier,
                          (CFIndex)sizeof(identity->code_identifier),
                          kCFStringEncodingUTF8)) {
    if (identifier != nullptr) {
      CFRelease(identifier);
    }
    CFRelease(code);
    return pst_validation_failed(PSTTrustedProcessValidationErrorIdentityUnavailable,
                                 error);
  }
  bool signature_is_valid = pst_code_has_apple_signature(code);
  CFRelease(identifier);
  CFRelease(code);
  if (!signature_is_valid) {
    return pst_validation_failed(PSTTrustedProcessValidationErrorSignatureInvalid,
                                 error);
  }

  if (!pst_copy_process_path(process_identifier, identity->executable_path)) {
    return pst_validation_failed(PSTTrustedProcessValidationErrorPathInvalid, error);
  }
  return true;
}
