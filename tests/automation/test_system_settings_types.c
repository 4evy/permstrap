#include "automation/PSTSystemSettingsTypes.h"

#include <assert.h>

int main(void) {
  assert(pst_system_settings_error_allows_continuation(
      PSTSystemSettingsAutomatorErrorOpenPane));
  assert(pst_system_settings_error_allows_continuation(
      PSTSystemSettingsAutomatorErrorUIAction));
  assert(!pst_system_settings_error_allows_continuation(
      PSTSystemSettingsAutomatorErrorAuthorization));
  assert(pst_system_settings_error_allows_continuation(
      PSTSystemSettingsAutomatorErrorAutomation));
  assert(!pst_system_settings_error_allows_continuation(
      PSTSystemSettingsAutomatorErrorUnsupportedMode));
  assert(!pst_system_settings_error_allows_continuation(
      (PSTSystemSettingsAutomatorError)0));
  return 0;
}
