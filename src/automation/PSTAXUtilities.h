#ifndef PST_AX_UTILITIES_H
#define PST_AX_UTILITIES_H

#include <ApplicationServices/ApplicationServices.h>
#include <CoreFoundation/CoreFoundation.h>

#include "core/PSTC23.h"

#include <sys/types.h>

#if defined(__OBJC__)
#define PST_AX_NONNULL _Nonnull
#define PST_AX_NULLABLE _Nullable
#else
#define PST_AX_NONNULL
#define PST_AX_NULLABLE
#endif

bool pst_ax_is_trusted(bool show_system_prompt);
AXUIElementRef PST_AX_NULLABLE pst_ax_copy_application(pid_t process_identifier);

AXUIElementRef PST_AX_NULLABLE pst_ax_copy_descendant_by_identifier(
    AXUIElementRef PST_AX_NONNULL root, CFStringRef PST_AX_NONNULL identifier);
AXUIElementRef PST_AX_NULLABLE pst_ax_copy_descendant_by_attribute(
    AXUIElementRef PST_AX_NONNULL root, CFStringRef PST_AX_NONNULL attribute,
    CFStringRef PST_AX_NONNULL value);
AXUIElementRef PST_AX_NULLABLE pst_ax_copy_descendant_by_role_and_title(
    AXUIElementRef PST_AX_NONNULL root, CFStringRef PST_AX_NONNULL role,
    CFStringRef PST_AX_NONNULL title);
AXUIElementRef PST_AX_NULLABLE
pst_ax_copy_secure_text_field(AXUIElementRef PST_AX_NONNULL root);
AXUIElementRef PST_AX_NULLABLE
pst_ax_copy_focused_ui_element(AXUIElementRef PST_AX_NONNULL application);
AXUIElementRef PST_AX_NULLABLE pst_ax_copy_parent(AXUIElementRef PST_AX_NONNULL element)
    CF_RETURNS_RETAINED;
bool pst_ax_element_is_focused(AXUIElementRef PST_AX_NONNULL application,
                               AXUIElementRef PST_AX_NONNULL element);
CFArrayRef PST_AX_NULLABLE
pst_ax_copy_descendants_by_role(AXUIElementRef PST_AX_NONNULL root,
                                CFStringRef PST_AX_NONNULL role) CF_RETURNS_RETAINED;
CFArrayRef PST_AX_NULLABLE pst_ax_copy_descendant_string_attribute_values_with_suffix(
    AXUIElementRef PST_AX_NONNULL root, CFStringRef PST_AX_NONNULL attribute,
    CFStringRef PST_AX_NONNULL suffix) CF_RETURNS_RETAINED;

bool pst_ax_press(AXUIElementRef PST_AX_NONNULL element);
bool pst_ax_perform_background_action(AXUIElementRef PST_AX_NONNULL element);
bool pst_ax_press_with_fallback(AXUIElementRef PST_AX_NONNULL element,
                                pid_t process_identifier);
bool pst_ax_set_string_value(AXUIElementRef PST_AX_NONNULL element,
                             CFStringRef PST_AX_NONNULL value);
bool pst_ax_focus(AXUIElementRef PST_AX_NONNULL element);
bool pst_ax_copy_frame(AXUIElementRef PST_AX_NONNULL element,
                       CGRect *PST_AX_NONNULL frame);
bool pst_ax_select_text(AXUIElementRef PST_AX_NONNULL element,
                        CFStringRef PST_AX_NONNULL text);
bool pst_ax_copy_boolean_attribute(AXUIElementRef PST_AX_NONNULL element,
                                   CFStringRef PST_AX_NONNULL attribute,
                                   bool *PST_AX_NONNULL value);
bool pst_ax_copy_boolean_value(AXUIElementRef PST_AX_NONNULL element,
                               bool *PST_AX_NONNULL value);
/* On success, value receives a retained string when it is non-null. */
bool pst_ax_copy_string_attribute(AXUIElementRef PST_AX_NONNULL element,
                                  CFStringRef PST_AX_NONNULL attribute,
                                  CFStringRef PST_AX_NULLABLE *PST_AX_NULLABLE value);
bool pst_ax_attributes_identify_secure_text_field(CFStringRef PST_AX_NULLABLE role,
                                                  CFStringRef PST_AX_NULLABLE subrole,
                                                  bool contains_protected_content);

CFArrayRef PST_AX_NULLABLE pst_ax_copy_visible_text(AXUIElementRef PST_AX_NONNULL root)
    CF_RETURNS_RETAINED;
CFStringRef PST_AX_NULLABLE
pst_ax_copy_tree_description(AXUIElementRef PST_AX_NONNULL root) CF_RETURNS_RETAINED;

bool pst_post_return_key(pid_t process_identifier);
bool pst_post_unicode(pid_t process_identifier,
                      const UniChar *PST_AX_NONNULL characters,
                      CFIndex character_count);
bool pst_post_mouse_click(pid_t process_identifier, CGPoint point, CGMouseButton button,
                          uint32_t click_count);
bool pst_post_scroll(pid_t process_identifier, CGPoint point, int32_t horizontal,
                     int32_t vertical);

#undef PST_AX_NONNULL
#undef PST_AX_NULLABLE

#endif
