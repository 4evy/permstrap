#include "automation/PSTSystemSettingsTypes.h"

#include <stddef.h>

typedef struct PSTSystemSettingsErrorPolicy {
  PSTSystemSettingsAutomatorError error;
  bool allows_continuation;
} PSTSystemSettingsErrorPolicy;

static const PSTSystemSettingsErrorPolicy pst_system_settings_error_policies[] = {
    {PSTSystemSettingsAutomatorErrorOpenPane, true},
    {PSTSystemSettingsAutomatorErrorUIAction, true},
    {PSTSystemSettingsAutomatorErrorAuthorization, false},
    {PSTSystemSettingsAutomatorErrorAutomation, true},
    {PSTSystemSettingsAutomatorErrorUnsupportedMode, false},
};

bool pst_system_settings_error_allows_continuation(
    PSTSystemSettingsAutomatorError error) {
  for (size_t index = 0; index < PST_ARRAY_COUNT(pst_system_settings_error_policies);
       ++index) {
    if (pst_system_settings_error_policies[index].error == error) {
      return pst_system_settings_error_policies[index].allows_continuation;
    }
  }
  return false;
}
