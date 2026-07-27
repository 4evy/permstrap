#include "automation/PSTAXUtilities.h"

#include <assert.h>

int main(void) {
  assert(pst_ax_copy_application(0) == nullptr);
  assert(pst_ax_copy_descendant_by_identifier(nullptr, kAXIdentifierAttribute) ==
         nullptr);
  assert(pst_ax_copy_descendant_by_attribute(nullptr, kAXRoleAttribute,
                                             kAXButtonRole) == nullptr);
  assert(pst_ax_copy_descendant_by_role_and_title(nullptr, kAXButtonRole,
                                                  CFSTR("Continue")) == nullptr);
  assert(pst_ax_copy_descendants_by_role(nullptr, kAXButtonRole) == nullptr);
  assert(pst_ax_copy_descendant_string_attribute_values_with_suffix(
             nullptr, kAXIdentifierAttribute, CFSTR("_Toggle")) == nullptr);
  assert(!pst_ax_set_string_value(nullptr, CFSTR("value")));
  CGRect frame = CGRectZero;
  assert(!pst_ax_copy_frame(nullptr, &frame));
  assert(!pst_ax_perform_background_action(nullptr));
  assert(!pst_ax_press_with_fallback(nullptr, 0));
  assert(!pst_ax_select_text(nullptr, CFSTR("value")));
  assert(!pst_post_return_key(0));
  assert(!pst_post_mouse_click(0, CGPointZero, kCGMouseButtonLeft, 1));
  assert(!pst_post_scroll(0, CGPointZero, 0, 1));

  CFStringRef copied_value = CFSTR("sentinel");
  assert(!pst_ax_copy_string_attribute(nullptr, kAXRoleAttribute, &copied_value));
  assert(copied_value == nullptr);

  assert(pst_ax_attributes_identify_secure_text_field(
      kAXTextFieldRole, kAXSecureTextFieldSubrole, false));
  assert(pst_ax_attributes_identify_secure_text_field(kAXTextFieldRole, nullptr, true));
  assert(
      !pst_ax_attributes_identify_secure_text_field(kAXTextFieldRole, nullptr, false));
  assert(!pst_ax_attributes_identify_secure_text_field(kAXGroupRole, nullptr, true));
  return 0;
}
