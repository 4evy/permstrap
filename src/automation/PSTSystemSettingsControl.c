#include "automation/PSTSystemSettingsControl.h"

#include "automation/PSTAXUtilities.h"

AXUIElementRef pst_system_settings_copy_element_by_identifier(pid_t process_identifier,
                                                              CFStringRef identifier) {
  if (identifier == nullptr) {
    return nullptr;
  }
  AXUIElementRef settings = pst_ax_copy_application(process_identifier);
  if (settings == nullptr) {
    return nullptr;
  }
  AXUIElementRef element = pst_ax_copy_descendant_by_identifier(settings, identifier);
  CFRelease(settings);
  return element;
}

AXUIElementRef pst_system_settings_copy_button(pid_t process_identifier,
                                               CFStringRef title) {
  if (title == nullptr) {
    return nullptr;
  }
  AXUIElementRef settings = pst_ax_copy_application(process_identifier);
  if (settings == nullptr) {
    return nullptr;
  }
  AXUIElementRef button =
      pst_ax_copy_descendant_by_role_and_title(settings, kAXButtonRole, title);
  if (button == nullptr) {
    AXUIElementRef described =
        pst_ax_copy_descendant_by_attribute(settings, kAXDescriptionAttribute, title);
    if (described != nullptr) {
      CFStringRef role = nullptr;
      bool has_role = pst_ax_copy_string_attribute(described, kAXRoleAttribute, &role);
      bool is_button = has_role && CFEqual(role, kAXButtonRole);
      if (role != nullptr) {
        CFRelease(role);
      }
      if (is_button) {
        button = described;
      } else {
        CFRelease(described);
      }
    }
  }
  CFRelease(settings);
  return button;
}

PSTPermissionSwitchState
pst_system_settings_permission_switch_state(pid_t process_identifier,
                                            CFStringRef switch_identifier) {
  AXUIElementRef toggle = pst_system_settings_copy_element_by_identifier(
      process_identifier, switch_identifier);
  if (toggle == nullptr) {
    return PSTPermissionSwitchStateUnavailable;
  }
  bool enabled = false;
  bool copied = pst_ax_copy_boolean_value(toggle, &enabled);
  CFRelease(toggle);
  if (!copied) {
    return PSTPermissionSwitchStateUnreadable;
  }
  return enabled ? PSTPermissionSwitchStateEnabled : PSTPermissionSwitchStateDisabled;
}

bool pst_system_settings_enable_permission_switch(pid_t process_identifier,
                                                  CFStringRef switch_identifier) {
  AXUIElementRef toggle = pst_system_settings_copy_element_by_identifier(
      process_identifier, switch_identifier);
  if (toggle == nullptr) {
    return false;
  }
  bool enabled = false;
  bool read_value = pst_ax_copy_boolean_value(toggle, &enabled);
  bool succeeded = read_value && (enabled || pst_ax_press(toggle));
  CFRelease(toggle);
  return succeeded;
}
