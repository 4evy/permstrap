#include "permissions/PSTPermissionPlanCore.h"

static bool
pst_permission_plan_callbacks_are_valid(const PSTPermissionPlanCallbacks *callbacks) {
  return callbacks != nullptr && callbacks->target_at != nullptr &&
         callbacks->path_for_target != nullptr && callbacks->service_count != nullptr &&
         callbacks->service_at != nullptr && callbacks->emit_operation != nullptr &&
         callbacks->emit_missing_target != nullptr;
}

bool pst_permission_plan_build(size_t target_count,
                               const PSTPermissionPlanCallbacks *callbacks,
                               void *context, PSTPermissionPlanBuildError *error) {
  if (error != nullptr) {
    *error = (PSTPermissionPlanBuildError){};
  }
  if (!pst_permission_plan_callbacks_are_valid(callbacks)) {
    if (error != nullptr) {
      error->code = PSTPermissionPlanBuildErrorInvalidCallbacks;
    }
    return false;
  }

  for (size_t target_index = 0; target_index < target_count; ++target_index) {
    const PSTPermissionPlanHandle target = callbacks->target_at(target_index, context);
    const PSTPermissionPlanHandle path = callbacks->path_for_target(target, context);
    if (path == nullptr) {
      callbacks->emit_missing_target(target, context);
      continue;
    }

    const size_t service_count = callbacks->service_count(target, context);
    for (size_t service_index = 0; service_index < service_count; ++service_index) {
      const PSTPermissionPlanHandle service =
          callbacks->service_at(target, service_index, context);
      if (service == nullptr) {
        if (error != nullptr) {
          *error = (PSTPermissionPlanBuildError){
              .code = PSTPermissionPlanBuildErrorMissingService,
              .target_index = target_index,
              .service_index = service_index,
          };
        }
        return false;
      }
      callbacks->emit_operation(target, service, path, context);
    }
  }
  return true;
}
