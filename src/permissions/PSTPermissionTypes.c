#include "permissions/PSTPermissionTypes.h"

#include <string.h>

typedef struct {
  const char *identifier;
  uint8_t value;
} PSTIdentifierEntry;

static const PSTIdentifierEntry PST_SERVICE_MODES[] = {
    {
        .identifier = "application-list",
        .value = PSTPermissionServiceModeApplicationList,
    },
    {
        .identifier = "existing-relationships",
        .value = PSTPermissionServiceModeExistingRelationships,
    },
};

static const PSTIdentifierEntry PST_TARGET_KINDS[] = {
    {
        .identifier = "application-bundle",
        .value = PSTPermissionTargetKindApplicationBundle,
    },
    {
        .identifier = "executable",
        .value = PSTPermissionTargetKindExecutable,
    },
};

static bool pst_identifier_parse(const PSTIdentifierEntry *entries, size_t entry_count,
                                 const char *identifier, uint8_t *value) {
  if (identifier == nullptr || value == nullptr) {
    return false;
  }
  for (size_t index = 0; index < entry_count; ++index) {
    if (strcmp(identifier, entries[index].identifier) == 0) {
      *value = entries[index].value;
      return true;
    }
  }
  return false;
}

static const char *pst_identifier_for_value(const PSTIdentifierEntry *entries,
                                            size_t entry_count, uint8_t value) {
  for (size_t index = 0; index < entry_count; ++index) {
    if (value == entries[index].value) {
      return entries[index].identifier;
    }
  }
  return nullptr;
}

bool pst_permission_service_mode_parse(const char *identifier,
                                       PSTPermissionServiceMode *mode) {
  uint8_t value = 0;
  if (mode == nullptr ||
      !pst_identifier_parse(PST_SERVICE_MODES, PST_ARRAY_COUNT(PST_SERVICE_MODES),
                            identifier, &value)) {
    return false;
  }
  *mode = (PSTPermissionServiceMode)value;
  return true;
}

bool pst_permission_target_kind_parse(const char *identifier,
                                      PSTPermissionTargetKind *kind) {
  uint8_t value = 0;
  if (kind == nullptr ||
      !pst_identifier_parse(PST_TARGET_KINDS, PST_ARRAY_COUNT(PST_TARGET_KINDS),
                            identifier, &value)) {
    return false;
  }
  *kind = (PSTPermissionTargetKind)value;
  return true;
}

const char *pst_permission_service_mode_identifier(PSTPermissionServiceMode mode) {
  return pst_identifier_for_value(PST_SERVICE_MODES, PST_ARRAY_COUNT(PST_SERVICE_MODES),
                                  (uint8_t)mode);
}

const char *pst_permission_target_kind_identifier(PSTPermissionTargetKind kind) {
  return pst_identifier_for_value(PST_TARGET_KINDS, PST_ARRAY_COUNT(PST_TARGET_KINDS),
                                  (uint8_t)kind);
}
