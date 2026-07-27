#include "permissions/PSTPermissionTypes.h"

#include <assert.h>
#include <string.h>

int main(void) {
  PSTPermissionServiceMode mode = PSTPermissionServiceModeApplicationList;
  assert(pst_permission_service_mode_parse("application-list", &mode));
  assert(mode == PSTPermissionServiceModeApplicationList);
  assert(pst_permission_service_mode_parse("existing-relationships", &mode));
  assert(mode == PSTPermissionServiceModeExistingRelationships);
  assert(!pst_permission_service_mode_parse("magic", &mode));
  assert(strcmp(pst_permission_service_mode_identifier(mode),
                "existing-relationships") == 0);

  PSTPermissionTargetKind kind = PSTPermissionTargetKindApplicationBundle;
  assert(pst_permission_target_kind_parse("application-bundle", &kind));
  assert(kind == PSTPermissionTargetKindApplicationBundle);
  assert(pst_permission_target_kind_parse("executable", &kind));
  assert(kind == PSTPermissionTargetKindExecutable);
  assert(!pst_permission_target_kind_parse("magic", &kind));
  assert(strcmp(pst_permission_target_kind_identifier(kind), "executable") == 0);

  assert(!pst_permission_service_mode_parse(nullptr, &mode));
  assert(!pst_permission_service_mode_parse("application-list", nullptr));
  assert(pst_permission_service_mode_identifier((PSTPermissionServiceMode)UINT8_MAX) ==
         nullptr);
  return 0;
}
