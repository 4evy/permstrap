#ifndef PST_SYSTEM_SETTINGS_TYPES_H
#define PST_SYSTEM_SETTINGS_TYPES_H

#include "core/PSTC23.h"

#include <stdint.h>

typedef enum PSTSystemSettingsAutomatorError : uint8_t {
  PSTSystemSettingsAutomatorErrorOpenPane = 1,
  PSTSystemSettingsAutomatorErrorUIAction,
  PSTSystemSettingsAutomatorErrorAuthorization,
  PSTSystemSettingsAutomatorErrorAutomation,
  PSTSystemSettingsAutomatorErrorUnsupportedMode,
} PSTSystemSettingsAutomatorError;

[[nodiscard]] bool
pst_system_settings_error_allows_continuation(PSTSystemSettingsAutomatorError error);

#endif
