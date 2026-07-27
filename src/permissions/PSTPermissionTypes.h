#ifndef PST_PERMISSION_TYPES_H
#define PST_PERMISSION_TYPES_H

#include "core/PSTC23.h"

#include <stdint.h>

constexpr uint64_t PST_PERMISSION_MANIFEST_VERSION = 1;

typedef enum PSTPermissionServiceMode : uint8_t {
  PSTPermissionServiceModeApplicationList,
  PSTPermissionServiceModeExistingRelationships,
} PSTPermissionServiceMode;

typedef enum PSTPermissionTargetKind : uint8_t {
  PSTPermissionTargetKindApplicationBundle,
  PSTPermissionTargetKindExecutable,
} PSTPermissionTargetKind;

static_assert(sizeof(PSTPermissionServiceMode) == sizeof(uint8_t));
static_assert(sizeof(PSTPermissionTargetKind) == sizeof(uint8_t));

[[nodiscard]]
bool pst_permission_service_mode_parse(const char *identifier,
                                       PSTPermissionServiceMode *mode);
[[nodiscard]]
bool pst_permission_target_kind_parse(const char *identifier,
                                      PSTPermissionTargetKind *kind);
[[nodiscard]]
const char *pst_permission_service_mode_identifier(PSTPermissionServiceMode mode);
[[nodiscard]]
const char *pst_permission_target_kind_identifier(PSTPermissionTargetKind kind);

#endif
