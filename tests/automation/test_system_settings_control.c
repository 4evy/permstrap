#include "automation/PSTSystemSettingsControl.h"

#include <assert.h>

int main(void) {
  assert(pst_system_settings_copy_element_by_identifier(0, CFSTR("missing")) ==
         nullptr);
  assert(pst_system_settings_copy_element_by_identifier(0, nullptr) == nullptr);
  assert(pst_system_settings_copy_button(0, CFSTR("missing")) == nullptr);
  assert(pst_system_settings_copy_button(0, nullptr) == nullptr);
  assert(pst_system_settings_permission_switch_state(0, CFSTR("missing")) ==
         PSTPermissionSwitchStateUnavailable);
  assert(!pst_system_settings_enable_permission_switch(0, CFSTR("missing")));
  return 0;
}
