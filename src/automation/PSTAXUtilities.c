#include "automation/PSTAXUtilities.h"

#include <math.h>
#include <stddef.h>
#include <unistd.h>

constexpr size_t PST_AX_MAX_DEPTH = 18;
constexpr size_t PST_AX_MAX_NODES = 8'192;
constexpr CFIndex PST_UNICODE_EVENT_CHUNK = 16;
constexpr useconds_t PST_UNICODE_EVENT_SETTLE_MICROSECONDS = 15'000;
constexpr CGKeyCode PST_KEY_CODE_RETURN = 36;

#define PST_AX_CONTAINS_PROTECTED_CONTENT_ATTRIBUTE CFSTR("AXContainsProtectedContent")

typedef bool (*PSTAXMatcher)(AXUIElementRef element, const void *context);

typedef struct PSTAXAttributeMatch {
  CFStringRef attribute;
  CFStringRef expected;
} PSTAXAttributeMatch;

typedef struct PSTAXRoleAndTitleMatch {
  CFStringRef role;
  CFStringRef title;
} PSTAXRoleAndTitleMatch;

static CFTypeRef pst_ax_copy_attribute(AXUIElementRef element, CFStringRef attribute) {
  if (element == nullptr || attribute == nullptr) {
    return nullptr;
  }
  CFTypeRef value = nullptr;
  AXError error = AXUIElementCopyAttributeValue(element, attribute, &value);
  return error == kAXErrorSuccess ? value : nullptr;
}

bool pst_ax_copy_string_attribute(AXUIElementRef element, CFStringRef attribute,
                                  CFStringRef *value) {
  if (value != nullptr) {
    *value = nullptr;
  }
  CFTypeRef raw_value = pst_ax_copy_attribute(element, attribute);
  if (raw_value == nullptr) {
    return false;
  }
  bool is_string = CFGetTypeID(raw_value) == CFStringGetTypeID();
  if (is_string && value != nullptr) {
    *value = (CFStringRef)raw_value;
  } else {
    CFRelease(raw_value);
  }
  return is_string;
}

static bool pst_ax_string_attribute_equals(AXUIElementRef element,
                                           CFStringRef attribute,
                                           CFStringRef expected) {
  CFStringRef actual = nullptr;
  if (!pst_ax_copy_string_attribute(element, attribute, &actual)) {
    return false;
  }
  bool matches = CFEqual(actual, expected);
  CFRelease(actual);
  return matches;
}

static AXUIElementRef pst_ax_copy_matching_recursive(AXUIElementRef element,
                                                     PSTAXMatcher matcher,
                                                     const void *context, size_t depth,
                                                     size_t *visited) {
  if (element == nullptr || depth > PST_AX_MAX_DEPTH || *visited >= PST_AX_MAX_NODES) {
    return nullptr;
  }
  ++(*visited);
  if (matcher(element, context)) {
    return (AXUIElementRef)CFRetain(element);
  }

  CFTypeRef raw_children = pst_ax_copy_attribute(element, kAXChildrenAttribute);
  if (raw_children == nullptr || CFGetTypeID(raw_children) != CFArrayGetTypeID()) {
    if (raw_children != nullptr) {
      CFRelease(raw_children);
    }
    return nullptr;
  }
  CFArrayRef children = (CFArrayRef)raw_children;
  CFIndex child_count = CFArrayGetCount(children);
  AXUIElementRef match = nullptr;
  for (CFIndex index = 0; index < child_count && match == nullptr; ++index) {
    CFTypeRef child = CFArrayGetValueAtIndex(children, index);
    if (child != nullptr && CFGetTypeID(child) == AXUIElementGetTypeID()) {
      match = pst_ax_copy_matching_recursive((AXUIElementRef)child, matcher, context,
                                             depth + 1, visited);
    }
  }
  CFRelease(children);
  return match;
}

static AXUIElementRef pst_ax_copy_matching(AXUIElementRef root, PSTAXMatcher matcher,
                                           const void *context) {
  size_t visited = 0;
  return pst_ax_copy_matching_recursive(root, matcher, context, 0, &visited);
}

static bool pst_ax_matches_attribute(AXUIElementRef element, const void *context) {
  const PSTAXAttributeMatch *match = context;
  return pst_ax_string_attribute_equals(element, match->attribute, match->expected);
}

static bool pst_ax_matches_role_and_title(AXUIElementRef element, const void *context) {
  const PSTAXRoleAndTitleMatch *match = context;
  return pst_ax_string_attribute_equals(element, kAXRoleAttribute, match->role) &&
         pst_ax_string_attribute_equals(element, kAXTitleAttribute, match->title);
}

static bool pst_ax_matches_secure_text_field(AXUIElementRef element,
                                             const void *context) {
  (void)context;
  CFStringRef role = nullptr;
  CFStringRef subrole = nullptr;
  bool contains_protected_content = false;
  (void)pst_ax_copy_string_attribute(element, kAXRoleAttribute, &role);
  (void)pst_ax_copy_string_attribute(element, kAXSubroleAttribute, &subrole);
  (void)pst_ax_copy_boolean_attribute(element,
                                      PST_AX_CONTAINS_PROTECTED_CONTENT_ATTRIBUTE,
                                      &contains_protected_content);
  bool matches = pst_ax_attributes_identify_secure_text_field(
      role, subrole, contains_protected_content);
  if (role != nullptr) {
    CFRelease(role);
  }
  if (subrole != nullptr) {
    CFRelease(subrole);
  }
  return matches;
}

bool pst_ax_is_trusted(bool show_system_prompt) {
  const void *keys[] = {kAXTrustedCheckOptionPrompt};
  const void *values[] = {show_system_prompt ? kCFBooleanTrue : kCFBooleanFalse};
  CFDictionaryRef options = CFDictionaryCreate(kCFAllocatorDefault, keys, values, 1,
                                               &kCFTypeDictionaryKeyCallBacks,
                                               &kCFTypeDictionaryValueCallBacks);
  if (options == nullptr) {
    return false;
  }
  bool trusted = AXIsProcessTrustedWithOptions(options);
  CFRelease(options);
  return trusted;
}

AXUIElementRef pst_ax_copy_application(pid_t process_identifier) {
  if (process_identifier <= 0) {
    return nullptr;
  }
  AXUIElementRef application = AXUIElementCreateApplication(process_identifier);
  if (application != nullptr) {
    (void)AXUIElementSetMessagingTimeout(application, 1.0F);
  }
  return application;
}

AXUIElementRef pst_ax_copy_descendant_by_identifier(AXUIElementRef root,
                                                    CFStringRef identifier) {
  if (root == nullptr || identifier == nullptr) {
    return nullptr;
  }
  const PSTAXAttributeMatch match = {
      .attribute = kAXIdentifierAttribute,
      .expected = identifier,
  };
  return pst_ax_copy_matching(root, pst_ax_matches_attribute, &match);
}

AXUIElementRef pst_ax_copy_descendant_by_attribute(AXUIElementRef root,
                                                   CFStringRef attribute,
                                                   CFStringRef value) {
  if (root == nullptr || attribute == nullptr || value == nullptr) {
    return nullptr;
  }
  const PSTAXAttributeMatch match = {
      .attribute = attribute,
      .expected = value,
  };
  return pst_ax_copy_matching(root, pst_ax_matches_attribute, &match);
}

AXUIElementRef pst_ax_copy_descendant_by_role_and_title(AXUIElementRef root,
                                                        CFStringRef role,
                                                        CFStringRef title) {
  if (root == nullptr || role == nullptr || title == nullptr) {
    return nullptr;
  }
  const PSTAXRoleAndTitleMatch match = {
      .role = role,
      .title = title,
  };
  return pst_ax_copy_matching(root, pst_ax_matches_role_and_title, &match);
}

AXUIElementRef pst_ax_copy_secure_text_field(AXUIElementRef root) {
  return pst_ax_copy_matching(root, pst_ax_matches_secure_text_field, nullptr);
}

AXUIElementRef pst_ax_copy_focused_ui_element(AXUIElementRef application) {
  CFTypeRef focused = pst_ax_copy_attribute(application, kAXFocusedUIElementAttribute);
  if (focused == nullptr || CFGetTypeID(focused) != AXUIElementGetTypeID()) {
    if (focused != nullptr) {
      CFRelease(focused);
    }
    return nullptr;
  }
  return (AXUIElementRef)focused;
}

AXUIElementRef pst_ax_copy_parent(AXUIElementRef element) {
  CFTypeRef parent = pst_ax_copy_attribute(element, kAXParentAttribute);
  if (parent == nullptr || CFGetTypeID(parent) != AXUIElementGetTypeID()) {
    if (parent != nullptr) {
      CFRelease(parent);
    }
    return nullptr;
  }
  return (AXUIElementRef)parent;
}

bool pst_ax_element_is_focused(AXUIElementRef application, AXUIElementRef element) {
  bool element_is_focused = false;
  if (pst_ax_copy_boolean_attribute(element, kAXFocusedAttribute,
                                    &element_is_focused) &&
      element_is_focused) {
    return true;
  }
  AXUIElementRef focused_element = pst_ax_copy_focused_ui_element(application);
  bool matches = focused_element != nullptr && CFEqual(focused_element, element);
  if (focused_element != nullptr) {
    CFRelease(focused_element);
  }
  return matches;
}

static void pst_ax_collect_role_recursive(AXUIElementRef element, CFStringRef role,
                                          CFMutableArrayRef matches, size_t depth,
                                          size_t *visited) {
  if (element == nullptr || depth > PST_AX_MAX_DEPTH || *visited >= PST_AX_MAX_NODES) {
    return;
  }
  ++(*visited);
  if (pst_ax_string_attribute_equals(element, kAXRoleAttribute, role)) {
    CFArrayAppendValue(matches, element);
  }
  CFTypeRef raw_children = pst_ax_copy_attribute(element, kAXChildrenAttribute);
  if (raw_children == nullptr || CFGetTypeID(raw_children) != CFArrayGetTypeID()) {
    if (raw_children != nullptr) {
      CFRelease(raw_children);
    }
    return;
  }
  CFArrayRef children = (CFArrayRef)raw_children;
  CFIndex child_count = CFArrayGetCount(children);
  for (CFIndex index = 0; index < child_count; ++index) {
    CFTypeRef child = CFArrayGetValueAtIndex(children, index);
    if (child != nullptr && CFGetTypeID(child) == AXUIElementGetTypeID()) {
      pst_ax_collect_role_recursive((AXUIElementRef)child, role, matches, depth + 1,
                                    visited);
    }
  }
  CFRelease(children);
}

CFArrayRef pst_ax_copy_descendants_by_role(AXUIElementRef root, CFStringRef role) {
  if (root == nullptr || role == nullptr) {
    return nullptr;
  }
  CFMutableArrayRef matches =
      CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
  if (matches == nullptr) {
    return nullptr;
  }
  size_t visited = 0;
  pst_ax_collect_role_recursive(root, role, matches, 0, &visited);
  return matches;
}

static void pst_ax_collect_attribute_values_with_suffix_recursive(
    AXUIElementRef element, CFStringRef attribute, CFStringRef suffix,
    CFMutableArrayRef values, size_t depth, size_t *visited) {
  if (element == nullptr || depth > PST_AX_MAX_DEPTH || *visited >= PST_AX_MAX_NODES) {
    return;
  }
  ++(*visited);
  CFStringRef value = nullptr;
  if (pst_ax_copy_string_attribute(element, attribute, &value)) {
    if (CFStringHasSuffix(value, suffix) &&
        !CFArrayContainsValue(values, CFRangeMake(0, CFArrayGetCount(values)), value)) {
      CFArrayAppendValue(values, value);
    }
    CFRelease(value);
  }

  CFTypeRef raw_children = pst_ax_copy_attribute(element, kAXChildrenAttribute);
  if (raw_children == nullptr || CFGetTypeID(raw_children) != CFArrayGetTypeID()) {
    if (raw_children != nullptr) {
      CFRelease(raw_children);
    }
    return;
  }
  CFArrayRef children = (CFArrayRef)raw_children;
  CFIndex child_count = CFArrayGetCount(children);
  for (CFIndex index = 0; index < child_count; ++index) {
    CFTypeRef child = CFArrayGetValueAtIndex(children, index);
    if (child != nullptr && CFGetTypeID(child) == AXUIElementGetTypeID()) {
      pst_ax_collect_attribute_values_with_suffix_recursive(
          (AXUIElementRef)child, attribute, suffix, values, depth + 1, visited);
    }
  }
  CFRelease(children);
}

CFArrayRef pst_ax_copy_descendant_string_attribute_values_with_suffix(
    AXUIElementRef root, CFStringRef attribute, CFStringRef suffix) {
  if (root == nullptr || attribute == nullptr || suffix == nullptr) {
    return nullptr;
  }
  CFMutableArrayRef values =
      CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
  if (values == nullptr) {
    return nullptr;
  }
  size_t visited = 0;
  pst_ax_collect_attribute_values_with_suffix_recursive(root, attribute, suffix, values,
                                                        0, &visited);
  return values;
}

bool pst_ax_press(AXUIElementRef element) {
  return element != nullptr &&
         AXUIElementPerformAction(element, kAXPressAction) == kAXErrorSuccess;
}

bool pst_ax_perform_background_action(AXUIElementRef element) {
  if (element == nullptr) {
    return false;
  }
  CFArrayRef action_names = nullptr;
  if (AXUIElementCopyActionNames(element, &action_names) != kAXErrorSuccess ||
      action_names == nullptr) {
    return false;
  }
  const CFStringRef preferred_actions[] = {
      kAXPressAction,
      kAXPickAction,
      kAXConfirmAction,
  };
  bool succeeded = false;
  for (size_t index = 0; !succeeded && index < PST_ARRAY_COUNT(preferred_actions);
       ++index) {
    CFStringRef action = preferred_actions[index];
    if (CFArrayContainsValue(action_names,
                             CFRangeMake(0, CFArrayGetCount(action_names)), action)) {
      succeeded = AXUIElementPerformAction(element, action) == kAXErrorSuccess;
    }
  }
  CFRelease(action_names);
  if (succeeded) {
    return true;
  }

  Boolean selected_is_settable = false;
  return AXUIElementIsAttributeSettable(element, kAXSelectedAttribute,
                                        &selected_is_settable) == kAXErrorSuccess &&
         selected_is_settable &&
         AXUIElementSetAttributeValue(element, kAXSelectedAttribute, kCFBooleanTrue) ==
             kAXErrorSuccess;
}

bool pst_ax_set_string_value(AXUIElementRef element, CFStringRef value) {
  if (element == nullptr || value == nullptr) {
    return false;
  }
  return AXUIElementSetAttributeValue(element, kAXValueAttribute, value) ==
         kAXErrorSuccess;
}

bool pst_ax_focus(AXUIElementRef element) {
  return element != nullptr &&
         AXUIElementSetAttributeValue(element, kAXFocusedAttribute, kCFBooleanTrue) ==
             kAXErrorSuccess;
}

bool pst_ax_copy_frame(AXUIElementRef element, CGRect *frame) {
  if (element == nullptr || frame == nullptr) {
    return false;
  }
  CFTypeRef raw_position = pst_ax_copy_attribute(element, kAXPositionAttribute);
  CFTypeRef raw_size = pst_ax_copy_attribute(element, kAXSizeAttribute);
  bool valid_types = raw_position != nullptr && raw_size != nullptr &&
                     CFGetTypeID(raw_position) == AXValueGetTypeID() &&
                     CFGetTypeID(raw_size) == AXValueGetTypeID();
  CGPoint position = CGPointZero;
  CGSize size = CGSizeZero;
  bool succeeded =
      valid_types &&
      AXValueGetValue((AXValueRef)raw_position, kAXValueCGPointType, &position) &&
      AXValueGetValue((AXValueRef)raw_size, kAXValueCGSizeType, &size);
  if (raw_position != nullptr) {
    CFRelease(raw_position);
  }
  if (raw_size != nullptr) {
    CFRelease(raw_size);
  }
  if (!succeeded) {
    return false;
  }
  *frame = (CGRect){.origin = position, .size = size};
  return true;
}

bool pst_ax_select_text(AXUIElementRef element, CFStringRef text) {
  if (element == nullptr || text == nullptr || CFStringGetLength(text) == 0) {
    return false;
  }
  CFStringRef value = nullptr;
  if (!pst_ax_copy_string_attribute(element, kAXValueAttribute, &value)) {
    return false;
  }
  CFRange selection =
      CFStringFind(value, text, kCFCompareNonliteral | kCFCompareLocalized);
  CFRelease(value);
  if (selection.location == kCFNotFound) {
    return false;
  }

  Boolean selected_range_is_settable = false;
  if (AXUIElementIsAttributeSettable(element, kAXSelectedTextRangeAttribute,
                                     &selected_range_is_settable) != kAXErrorSuccess ||
      !selected_range_is_settable) {
    return false;
  }
  AXValueRef range_value = AXValueCreate(kAXValueCFRangeType, &selection);
  if (range_value == nullptr) {
    return false;
  }
  bool succeeded = AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute,
                                                range_value) == kAXErrorSuccess;
  CFRelease(range_value);
  return succeeded;
}

bool pst_ax_copy_boolean_attribute(AXUIElementRef element, CFStringRef attribute,
                                   bool *value) {
  if (element == nullptr || attribute == nullptr || value == nullptr) {
    return false;
  }
  CFTypeRef raw_value = pst_ax_copy_attribute(element, attribute);
  if (raw_value == nullptr) {
    return false;
  }
  bool success = false;
  if (CFGetTypeID(raw_value) == CFBooleanGetTypeID()) {
    *value = CFBooleanGetValue((CFBooleanRef)raw_value);
    success = true;
  } else if (CFGetTypeID(raw_value) == CFNumberGetTypeID()) {
    int number = 0;
    if (CFNumberGetValue((CFNumberRef)raw_value, kCFNumberIntType, &number)) {
      *value = number != 0;
      success = true;
    }
  }
  CFRelease(raw_value);
  return success;
}

bool pst_ax_copy_boolean_value(AXUIElementRef element, bool *value) {
  return pst_ax_copy_boolean_attribute(element, kAXValueAttribute, value);
}

bool pst_ax_attributes_identify_secure_text_field(CFStringRef role, CFStringRef subrole,
                                                  bool contains_protected_content) {
  if (subrole != nullptr && CFEqual(subrole, kAXSecureTextFieldSubrole)) {
    return true;
  }
  return contains_protected_content && role != nullptr &&
         CFEqual(role, kAXTextFieldRole);
}

static void pst_ax_append_unique_text(CFMutableArrayRef text, CFStringRef candidate) {
  if (text == nullptr || candidate == nullptr || CFStringGetLength(candidate) == 0) {
    return;
  }
  CFRange all = CFRangeMake(0, CFArrayGetCount(text));
  if (!CFArrayContainsValue(text, all, candidate)) {
    CFArrayAppendValue(text, candidate);
  }
}

static void pst_ax_append_description(
    CFMutableStringRef description, size_t depth, CFStringRef role, CFStringRef subrole,
    CFStringRef identifier, CFStringRef title, CFStringRef element_description,
    CFStringRef value, bool contains_protected_content, bool is_focused) {
  if (description == nullptr) {
    return;
  }
  for (size_t index = 0; index < depth; ++index) {
    CFStringAppend(description, CFSTR("  "));
  }
  CFStringAppend(description, role != nullptr ? role : CFSTR("AXUnknown"));
  if (subrole != nullptr && CFStringGetLength(subrole) > 0) {
    CFStringAppendFormat(description, nullptr, CFSTR("/%@"), subrole);
  }
  if (identifier != nullptr && CFStringGetLength(identifier) > 0) {
    CFStringAppendFormat(description, nullptr, CFSTR(" id=%@"), identifier);
  }
  if (title != nullptr && CFStringGetLength(title) > 0) {
    CFStringAppendFormat(description, nullptr, CFSTR(" title=%@"), title);
  }
  if (element_description != nullptr && CFStringGetLength(element_description) > 0) {
    CFStringAppendFormat(description, nullptr, CFSTR(" description=%@"),
                         element_description);
  }
  if (contains_protected_content) {
    CFStringAppend(description, CFSTR(" protected=true"));
  }
  if (is_focused) {
    CFStringAppend(description, CFSTR(" focused=true"));
  }
  if (value != nullptr && CFStringGetLength(value) > 0) {
    CFStringAppendFormat(description, nullptr, CFSTR(" value=%@"), value);
  }
  CFStringAppend(description, CFSTR("\n"));
}

static void pst_ax_release_if_present(CFTypeRef value) {
  if (value != nullptr) {
    CFRelease(value);
  }
}

static void pst_ax_collect_recursive(AXUIElementRef element, CFMutableArrayRef text,
                                     CFMutableStringRef description, size_t depth,
                                     size_t *visited) {
  if (element == nullptr || depth > PST_AX_MAX_DEPTH || *visited >= PST_AX_MAX_NODES) {
    return;
  }
  ++(*visited);

  CFStringRef role = nullptr;
  CFStringRef subrole = nullptr;
  CFStringRef identifier = nullptr;
  CFStringRef title = nullptr;
  CFStringRef element_description = nullptr;
  (void)pst_ax_copy_string_attribute(element, kAXRoleAttribute, &role);
  (void)pst_ax_copy_string_attribute(element, kAXSubroleAttribute, &subrole);
  (void)pst_ax_copy_string_attribute(element, kAXIdentifierAttribute, &identifier);
  (void)pst_ax_copy_string_attribute(element, kAXTitleAttribute, &title);
  (void)pst_ax_copy_string_attribute(element, kAXDescriptionAttribute,
                                     &element_description);
  bool contains_protected_content = false;
  bool is_focused = false;
  (void)pst_ax_copy_boolean_attribute(element,
                                      PST_AX_CONTAINS_PROTECTED_CONTENT_ATTRIBUTE,
                                      &contains_protected_content);
  (void)pst_ax_copy_boolean_attribute(element, kAXFocusedAttribute, &is_focused);
  CFStringRef value = nullptr;
  if (!pst_ax_attributes_identify_secure_text_field(role, subrole,
                                                    contains_protected_content)) {
    (void)pst_ax_copy_string_attribute(element, kAXValueAttribute, &value);
  }

  pst_ax_append_unique_text(text, title);
  pst_ax_append_unique_text(text, element_description);
  pst_ax_append_unique_text(text, value);
  pst_ax_append_description(description, depth, role, subrole, identifier, title,
                            element_description, value, contains_protected_content,
                            is_focused);

  pst_ax_release_if_present(role);
  pst_ax_release_if_present(subrole);
  pst_ax_release_if_present(identifier);
  pst_ax_release_if_present(title);
  pst_ax_release_if_present(element_description);
  pst_ax_release_if_present(value);

  CFTypeRef raw_children = pst_ax_copy_attribute(element, kAXChildrenAttribute);
  if (raw_children == nullptr || CFGetTypeID(raw_children) != CFArrayGetTypeID()) {
    if (raw_children != nullptr) {
      CFRelease(raw_children);
    }
    return;
  }
  CFArrayRef children = (CFArrayRef)raw_children;
  CFIndex child_count = CFArrayGetCount(children);
  for (CFIndex index = 0; index < child_count; ++index) {
    CFTypeRef child = CFArrayGetValueAtIndex(children, index);
    if (child != nullptr && CFGetTypeID(child) == AXUIElementGetTypeID()) {
      pst_ax_collect_recursive((AXUIElementRef)child, text, description, depth + 1,
                               visited);
    }
  }
  CFRelease(children);
}

CFArrayRef pst_ax_copy_visible_text(AXUIElementRef root) {
  CFMutableArrayRef text =
      CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
  if (text == nullptr) {
    return nullptr;
  }
  size_t visited = 0;
  pst_ax_collect_recursive(root, text, nullptr, 0, &visited);
  return text;
}

CFStringRef pst_ax_copy_tree_description(AXUIElementRef root) {
  CFMutableStringRef description = CFStringCreateMutable(kCFAllocatorDefault, 0);
  if (description == nullptr) {
    return nullptr;
  }
  size_t visited = 0;
  pst_ax_collect_recursive(root, nullptr, description, 0, &visited);
  return description;
}

static bool pst_post_key_event(pid_t process_identifier, CGKeyCode key_code,
                               bool key_down, CGEventFlags flags) {
  if (process_identifier <= 0) {
    return false;
  }
  CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStatePrivate);
  if (source == nullptr) {
    return false;
  }
  CGEventRef event = CGEventCreateKeyboardEvent(source, key_code, key_down);
  CFRelease(source);
  if (event == nullptr) {
    return false;
  }
  CGEventSetFlags(event, flags);
  CGEventPostToPid(process_identifier, event);
  CFRelease(event);
  return true;
}

static bool pst_post_hot_key(pid_t process_identifier, CGKeyCode key_code,
                             CGEventFlags flags) {
  bool key_down = pst_post_key_event(process_identifier, key_code, true, flags);
  bool key_up = pst_post_key_event(process_identifier, key_code, false, flags);
  return key_down && key_up;
}

bool pst_post_return_key(pid_t process_identifier) {
  return pst_post_hot_key(process_identifier, PST_KEY_CODE_RETURN, 0);
}

bool pst_post_unicode(pid_t process_identifier, const UniChar *characters,
                      CFIndex character_count) {
  if (process_identifier <= 0 || characters == nullptr || character_count <= 0) {
    return false;
  }
  for (CFIndex offset = 0; offset < character_count;) {
    CFIndex remaining = character_count - offset;
    CFIndex chunk =
        remaining < PST_UNICODE_EVENT_CHUNK ? remaining : PST_UNICODE_EVENT_CHUNK;
    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStatePrivate);
    if (source == nullptr) {
      return false;
    }
    CGEventRef key_down = CGEventCreateKeyboardEvent(source, 0, true);
    CGEventRef key_up = CGEventCreateKeyboardEvent(source, 0, false);
    CFRelease(source);
    if (key_down == nullptr || key_up == nullptr) {
      if (key_down != nullptr) {
        CFRelease(key_down);
      }
      if (key_up != nullptr) {
        CFRelease(key_up);
      }
      return false;
    }
    CGEventKeyboardSetUnicodeString(key_down, (UniCharCount)chunk, characters + offset);
    CGEventKeyboardSetUnicodeString(key_up, (UniCharCount)chunk, characters + offset);
    CGEventPostToPid(process_identifier, key_down);
    CGEventPostToPid(process_identifier, key_up);
    CFRelease(key_down);
    CFRelease(key_up);
    offset += chunk;
    (void)usleep(PST_UNICODE_EVENT_SETTLE_MICROSECONDS);
  }
  return true;
}

static CGEventType pst_mouse_down_event_type(CGMouseButton button) {
  switch (button) {
  case kCGMouseButtonLeft:
    return kCGEventLeftMouseDown;
  case kCGMouseButtonRight:
    return kCGEventRightMouseDown;
  case kCGMouseButtonCenter:
    return kCGEventOtherMouseDown;
  }
  return kCGEventLeftMouseDown;
}

static CGEventType pst_mouse_up_event_type(CGMouseButton button) {
  switch (button) {
  case kCGMouseButtonLeft:
    return kCGEventLeftMouseUp;
  case kCGMouseButtonRight:
    return kCGEventRightMouseUp;
  case kCGMouseButtonCenter:
    return kCGEventOtherMouseUp;
  }
  return kCGEventLeftMouseUp;
}

bool pst_post_mouse_click(pid_t process_identifier, CGPoint point, CGMouseButton button,
                          uint32_t click_count) {
  bool supported_button = button == kCGMouseButtonLeft ||
                          button == kCGMouseButtonRight ||
                          button == kCGMouseButtonCenter;
  if (process_identifier <= 0 || !supported_button || !isfinite(point.x) ||
      !isfinite(point.y) || click_count == 0) {
    return false;
  }
  CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStatePrivate);
  if (source == nullptr) {
    return false;
  }
  CGEventRef down =
      CGEventCreateMouseEvent(source, pst_mouse_down_event_type(button), point, button);
  CGEventRef up =
      CGEventCreateMouseEvent(source, pst_mouse_up_event_type(button), point, button);
  CFRelease(source);
  if (down == nullptr || up == nullptr) {
    if (down != nullptr) {
      CFRelease(down);
    }
    if (up != nullptr) {
      CFRelease(up);
    }
    return false;
  }
  CGEventSetIntegerValueField(down, kCGMouseEventClickState, (int64_t)click_count);
  CGEventSetIntegerValueField(up, kCGMouseEventClickState, (int64_t)click_count);
  CGEventPostToPid(process_identifier, down);
  CGEventPostToPid(process_identifier, up);
  CFRelease(down);
  CFRelease(up);
  return true;
}

bool pst_post_scroll(pid_t process_identifier, CGPoint point, int32_t horizontal,
                     int32_t vertical) {
  if (process_identifier <= 0 || !isfinite(point.x) || !isfinite(point.y)) {
    return false;
  }
  CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStatePrivate);
  if (source == nullptr) {
    return false;
  }
  CGEventRef event = CGEventCreateScrollWheelEvent(source, kCGScrollEventUnitPixel, 2,
                                                   vertical, horizontal);
  CFRelease(source);
  if (event == nullptr) {
    return false;
  }
  CGEventSetLocation(event, point);
  CGEventPostToPid(process_identifier, event);
  CFRelease(event);
  return true;
}

bool pst_ax_press_with_fallback(AXUIElementRef element, pid_t process_identifier) {
  if (pst_ax_perform_background_action(element)) {
    return true;
  }
  CGRect frame = CGRectZero;
  if (!pst_ax_copy_frame(element, &frame) || CGRectIsEmpty(frame)) {
    return false;
  }
  CGPoint center = CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame));
  return pst_post_mouse_click(process_identifier, center, kCGMouseButtonLeft, 1);
}
