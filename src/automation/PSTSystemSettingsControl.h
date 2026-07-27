#ifndef PST_SYSTEM_SETTINGS_CONTROL_H
#define PST_SYSTEM_SETTINGS_CONTROL_H

#include "core/PSTC23.h"

#include <ApplicationServices/ApplicationServices.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stdint.h>
#include <sys/types.h>

typedef enum PSTPermissionSwitchState : uint8_t {
  PSTPermissionSwitchStateUnavailable,
  PSTPermissionSwitchStateUnreadable,
  PSTPermissionSwitchStateDisabled,
  PSTPermissionSwitchStateEnabled,
} PSTPermissionSwitchState;

[[nodiscard]]
AXUIElementRef pst_system_settings_copy_element_by_identifier(
    pid_t process_identifier, CFStringRef identifier) CF_RETURNS_RETAINED;

[[nodiscard]]
AXUIElementRef pst_system_settings_copy_button(pid_t process_identifier,
                                               CFStringRef title) CF_RETURNS_RETAINED;

[[nodiscard]]
PSTPermissionSwitchState
pst_system_settings_permission_switch_state(pid_t process_identifier,
                                            CFStringRef switch_identifier);

[[nodiscard]]
bool pst_system_settings_enable_permission_switch(pid_t process_identifier,
                                                  CFStringRef switch_identifier);

#endif
