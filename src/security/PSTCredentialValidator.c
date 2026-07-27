#include "security/PSTCredentialValidator.h"

#include <Security/Authorization.h>
#include <Security/AuthorizationTags.h>

#include <errno.h>
#include <pwd.h>
#include <stdckdint.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

constexpr size_t PST_ACCOUNT_BUFFER_INITIAL_CAPACITY = 4'096;
constexpr size_t PST_ACCOUNT_BUFFER_MAXIMUM_CAPACITY = 1'024 * 1'024;
constexpr size_t PST_AUTHORIZATION_STATUS_ERROR_CAPACITY = 128;

typedef struct {
  struct passwd record;
  char *storage;
} PSTAccountRecord;

static void pst_copy_error(char *destination, size_t destination_capacity,
                           const char *source) {
  if (destination == nullptr || destination_capacity == 0) {
    return;
  }
  if (source == nullptr) {
    destination[0] = '\0';
    return;
  }
  (void)snprintf(destination, destination_capacity, "%s", source);
}

static bool pst_current_account_record(PSTAccountRecord *account) {
  if (account == nullptr) {
    return false;
  }
  *account = (PSTAccountRecord){};

  size_t capacity = PST_ACCOUNT_BUFFER_INITIAL_CAPACITY;
  while (capacity <= PST_ACCOUNT_BUFFER_MAXIMUM_CAPACITY) {
    char *storage = malloc(capacity);
    if (storage == nullptr) {
      return false;
    }

    struct passwd *result = nullptr;
    int lookup_result =
        getpwuid_r(getuid(), &account->record, storage, capacity, &result);
    if (lookup_result == 0 && result != nullptr && account->record.pw_name != nullptr &&
        account->record.pw_name[0] != '\0') {
      account->storage = storage;
      return true;
    }
    free(storage);
    if (lookup_result != ERANGE) {
      return false;
    }

    size_t expanded_capacity = 0;
    if (ckd_mul(&expanded_capacity, capacity, 2) ||
        expanded_capacity > PST_ACCOUNT_BUFFER_MAXIMUM_CAPACITY) {
      return false;
    }
    capacity = expanded_capacity;
  }
  return false;
}

static PSTCredentialValidationResult
pst_validation_result_for_status(OSStatus status, char *error_message,
                                 size_t error_message_capacity) {
  switch (status) {
  case errAuthorizationSuccess:
    pst_copy_error(error_message, error_message_capacity, "");
    return PST_CREDENTIAL_VALIDATION_OK;
  case errAuthorizationDenied:
  case errAuthorizationInteractionNotAllowed:
    pst_copy_error(error_message, error_message_capacity,
                   "macOS did not accept the administrator password for the current "
                   "account.");
    return PST_CREDENTIAL_VALIDATION_INVALID;
  case errAuthorizationCanceled:
  case errAuthorizationInvalidSet:
  case errAuthorizationInvalidRef:
  case errAuthorizationInvalidTag:
  case errAuthorizationInvalidPointer:
  case errAuthorizationToolExecuteFailure:
  case errAuthorizationInternal:
  case errAuthorizationExternalizeNotAllowed:
    break;
  }

  char status_error[PST_AUTHORIZATION_STATUS_ERROR_CAPACITY] = {};
  (void)snprintf(status_error, sizeof(status_error),
                 "macOS Authorization Services failed with status %d.", (int)status);
  pst_copy_error(error_message, error_message_capacity, status_error);
  return PST_CREDENTIAL_VALIDATION_UNAVAILABLE;
}

PSTCredentialValidationResult
pst_validate_administrator_credential(const PSTSecureBuffer *credential,
                                      char *error_message,
                                      size_t error_message_capacity) {
  if (credential == nullptr || credential->bytes == nullptr ||
      credential->data_length == 0) {
    pst_copy_error(error_message, error_message_capacity,
                   "Administrator password is empty.");
    return PST_CREDENTIAL_VALIDATION_INVALID;
  }
  if (geteuid() == 0) {
    pst_copy_error(error_message, error_message_capacity,
                   "Administrator passwords cannot be validated while running as "
                   "root.");
    return PST_CREDENTIAL_VALIDATION_UNAVAILABLE;
  }

  PSTAccountRecord account = {};
  if (!pst_current_account_record(&account)) {
    pst_copy_error(error_message, error_message_capacity,
                   "Unable to identify the current macOS account.");
    return PST_CREDENTIAL_VALIDATION_UNAVAILABLE;
  }

  AuthorizationItem right = {
      .name = kAuthorizationRightExecute,
      .valueLength = 0,
      .value = nullptr,
      .flags = 0,
  };
  AuthorizationRights rights = {
      .count = 1,
      .items = &right,
  };
  AuthorizationItem environment_items[] = {
      {
          .name = kAuthorizationEnvironmentUsername,
          .valueLength = strlen(account.record.pw_name),
          .value = account.record.pw_name,
          .flags = 0,
      },
      {
          .name = kAuthorizationEnvironmentPassword,
          .valueLength = credential->data_length,
          .value = credential->bytes,
          .flags = 0,
      },
  };
  AuthorizationEnvironment environment = {
      .count = (UInt32)PST_ARRAY_COUNT(environment_items),
      .items = environment_items,
  };
  /*
   * Do not add kAuthorizationEnvironmentShared: the supplied password must not
   * enter the login session's shared credential pool. A null AuthorizationRef
   * plus DestroyRights makes this a validation attempt, not retained authority.
   */
  AuthorizationFlags flags = (AuthorizationFlags)(kAuthorizationFlagExtendRights |
                                                  kAuthorizationFlagDestroyRights);
  OSStatus status = AuthorizationCreate(&rights, &environment, flags, nullptr);
  free(account.storage);
  return pst_validation_result_for_status(status, error_message,
                                          error_message_capacity);
}
