#ifndef PST_PERMISSION_MANIFEST_VALIDATION_H
#define PST_PERMISSION_MANIFEST_VALIDATION_H

#include "core/PSTC23.h"
#include "core/PSTYyjson.h"

#include <stddef.h>
#include <stdint.h>

typedef enum PSTPermissionManifestValidationCode : uint8_t {
  PSTPermissionManifestValidationInvalidJSON = 1,
  PSTPermissionManifestValidationUnsupportedVersion,
  PSTPermissionManifestValidationInvalidService,
  PSTPermissionManifestValidationDuplicateService,
  PSTPermissionManifestValidationInvalidPermissionSet,
  PSTPermissionManifestValidationUnknownPermissionSet,
  PSTPermissionManifestValidationInvalidTarget,
  PSTPermissionManifestValidationUnknownService,
} PSTPermissionManifestValidationCode;

typedef struct PSTPermissionManifestValidationError {
  PSTPermissionManifestValidationCode code;
  size_t byte_position;
  char path[PST_JSON_DIAGNOSTIC_CAPACITY];
  char description[PST_JSON_DIAGNOSTIC_CAPACITY];
} PSTPermissionManifestValidationError;

[[nodiscard]] bool
pst_permission_catalog_validate(const void *data, size_t length,
                                PSTPermissionManifestValidationError *error);

[[nodiscard]] bool
pst_permission_targets_validate(const void *data, size_t length,
                                PSTPermissionManifestValidationError *error);

#endif
