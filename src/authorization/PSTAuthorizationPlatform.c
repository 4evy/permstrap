#include "authorization/PSTAuthorizationPlatform.h"

#include "authorization/PSTAuthorizationReadiness.h"
#include "automation/PSTAXUtilities.h"
#include "core/PSTTime.h"

#include <stdckdint.h>
#include <time.h>

typedef struct PSTSecureFieldProbeContext {
  AXUIElementRef agent;
  AXUIElementRef discovered_field;
} PSTSecureFieldProbeContext;

typedef struct PSTFocusedElementProbeContext {
  AXUIElementRef agent;
  AXUIElementRef secure_field;
} PSTFocusedElementProbeContext;

uint64_t pst_authorization_realtime_nanoseconds(void) {
  struct timespec time_value = {};
  if (clock_gettime(CLOCK_REALTIME, &time_value) != 0 || time_value.tv_sec < 0 ||
      time_value.tv_nsec < 0 ||
      (uint64_t)time_value.tv_nsec >= PST_NANOSECONDS_PER_SECOND) {
    return 0;
  }
  const uint64_t seconds = (uint64_t)time_value.tv_sec;
  const uint64_t nanoseconds = (uint64_t)time_value.tv_nsec;
  uint64_t whole_nanoseconds = 0;
  uint64_t result = 0;
  if (ckd_mul(&whole_nanoseconds, seconds, PST_NANOSECONDS_PER_SECOND) ||
      ckd_add(&result, whole_nanoseconds, nanoseconds)) {
    return 0;
  }
  return result;
}

static bool pst_probe_secure_field(void *raw_context) {
  PSTSecureFieldProbeContext *context = raw_context;
  context->discovered_field = pst_ax_copy_secure_text_field(context->agent);
  return context->discovered_field != nullptr;
}

AXUIElementRef pst_authorization_copy_secure_field(AXUIElementRef agent,
                                                   CFArrayRef reveal_button_titles,
                                                   size_t maximum_attempts,
                                                   uint64_t poll_interval_nanoseconds) {
  if (agent == nullptr) {
    return nullptr;
  }
  AXUIElementRef secure_field = pst_ax_copy_secure_text_field(agent);
  if (secure_field != nullptr) {
    return secure_field;
  }
  if (reveal_button_titles != nullptr) {
    const CFIndex title_count = CFArrayGetCount(reveal_button_titles);
    for (CFIndex index = 0; index < title_count; ++index) {
      CFTypeRef raw_title = CFArrayGetValueAtIndex(reveal_button_titles, index);
      if (raw_title == nullptr || CFGetTypeID(raw_title) != CFStringGetTypeID()) {
        continue;
      }
      AXUIElementRef button = pst_ax_copy_descendant_by_role_and_title(
          agent, kAXButtonRole, (CFStringRef)raw_title);
      if (button != nullptr) {
        (void)pst_ax_press(button);
        CFRelease(button);
        break;
      }
    }
  }

  PSTSecureFieldProbeContext context = {
      .agent = agent,
  };
  (void)pst_authorization_wait_until_ready(maximum_attempts, poll_interval_nanoseconds,
                                           pst_probe_secure_field, &context);
  return context.discovered_field;
}

static bool pst_probe_focused_element(void *raw_context) {
  PSTFocusedElementProbeContext *context = raw_context;
  return pst_ax_element_is_focused(context->agent, context->secure_field);
}

bool pst_authorization_focus_secure_field(AXUIElementRef agent,
                                          AXUIElementRef secure_field,
                                          size_t maximum_attempts,
                                          uint64_t poll_interval_nanoseconds) {
  if (agent == nullptr || secure_field == nullptr) {
    return false;
  }
  if (pst_ax_element_is_focused(agent, secure_field)) {
    return true;
  }
  (void)pst_ax_focus(secure_field);
  PSTFocusedElementProbeContext context = {
      .agent = agent,
      .secure_field = secure_field,
  };
  return pst_authorization_wait_until_ready(maximum_attempts, poll_interval_nanoseconds,
                                            pst_probe_focused_element, &context);
}

bool pst_authorization_post_credential(pid_t process_identifier,
                                       const PSTSecureBuffer *credential) {
  if (credential == nullptr || credential->bytes == nullptr ||
      credential->data_length == 0 || credential->data_length > (size_t)INT64_MAX) {
    return false;
  }
  CFStringRef credential_string = CFStringCreateWithBytesNoCopy(
      kCFAllocatorDefault, credential->bytes, (CFIndex)credential->data_length,
      kCFStringEncodingUTF8, false, kCFAllocatorNull);
  if (credential_string == nullptr) {
    return false;
  }
  const CFIndex character_count = CFStringGetLength(credential_string);
  size_t character_bytes = 0;
  if (character_count <= 0 ||
      ckd_mul(&character_bytes, (uint64_t)character_count, sizeof(UniChar))) {
    CFRelease(credential_string);
    return false;
  }

  PSTSecureBuffer utf16_buffer;
  if (!pst_secure_buffer_init(&utf16_buffer, character_bytes)) {
    CFRelease(credential_string);
    return false;
  }
  UniChar *characters = __builtin_assume_aligned(utf16_buffer.bytes, alignof(UniChar));
  CFStringGetCharacters(credential_string, CFRangeMake(0, character_count), characters);
  CFRelease(credential_string);
  utf16_buffer.data_length = character_bytes;

  const bool posted = pst_post_unicode(process_identifier, characters, character_count);
  pst_secure_buffer_destroy(&utf16_buffer);
  return posted && pst_post_return_key(process_identifier);
}
