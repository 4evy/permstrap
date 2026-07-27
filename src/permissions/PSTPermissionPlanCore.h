#ifndef PST_PERMISSION_PLAN_CORE_H
#define PST_PERMISSION_PLAN_CORE_H

#include "core/PSTC23.h"

#include <stddef.h>
#include <stdint.h>

typedef const void *PSTPermissionPlanHandle;

typedef enum PSTPermissionPlanBuildErrorCode : uint8_t {
  PSTPermissionPlanBuildErrorNone,
  PSTPermissionPlanBuildErrorInvalidCallbacks,
  PSTPermissionPlanBuildErrorMissingService,
} PSTPermissionPlanBuildErrorCode;

typedef struct PSTPermissionPlanBuildError {
  PSTPermissionPlanBuildErrorCode code;
  size_t target_index;
  size_t service_index;
} PSTPermissionPlanBuildError;

typedef struct PSTPermissionPlanCallbacks {
  PSTPermissionPlanHandle (*target_at)(size_t index, void *context);
  PSTPermissionPlanHandle (*path_for_target)(PSTPermissionPlanHandle target,
                                             void *context);
  size_t (*service_count)(PSTPermissionPlanHandle target, void *context);
  PSTPermissionPlanHandle (*service_at)(PSTPermissionPlanHandle target, size_t index,
                                        void *context);
  void (*emit_operation)(PSTPermissionPlanHandle target,
                         PSTPermissionPlanHandle service, PSTPermissionPlanHandle path,
                         void *context);
  void (*emit_missing_target)(PSTPermissionPlanHandle target, void *context);
} PSTPermissionPlanCallbacks;

[[nodiscard]] bool
pst_permission_plan_build(size_t target_count,
                          const PSTPermissionPlanCallbacks *callbacks, void *context,
                          PSTPermissionPlanBuildError *error);

#endif
