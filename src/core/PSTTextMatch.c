#include "core/PSTTextMatch.h"

#include <utf8proc.h>

#include <assert.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef struct PSTFoldedText {
  utf8proc_uint8_t *data;
  size_t length;
} PSTFoldedText;

static bool pst_fold_text(PSTTextView text, PSTFoldedText *folded) {
  assert(text.data != nullptr);
  assert(folded != nullptr);
  *folded = (PSTFoldedText){};
  if (text.length > (size_t)PTRDIFF_MAX) {
    return false;
  }
  const utf8proc_option_t options =
      UTF8PROC_STABLE | UTF8PROC_COMPOSE | UTF8PROC_CASEFOLD;
  const utf8proc_ssize_t length =
      utf8proc_map((const utf8proc_uint8_t *)text.data, (utf8proc_ssize_t)text.length,
                   &folded->data, options);
  if (length < 0) {
    return false;
  }
  folded->length = (size_t)length;
  return true;
}

static bool pst_folded_text_contains(const PSTFoldedText *haystack,
                                     const PSTFoldedText *needle) {
  assert(haystack != nullptr);
  assert(needle != nullptr);
  if (needle->length == 0) {
    return true;
  }
  if (needle->length > haystack->length) {
    return false;
  }

  const size_t last_start = haystack->length - needle->length;
  for (size_t start = 0; start <= last_start; ++start) {
    if (memcmp(haystack->data + start, needle->data, needle->length) == 0) {
      return true;
    }
  }
  return false;
}

static bool pst_any_view_contains(const PSTTextView haystacks[static 1],
                                  size_t haystack_count, PSTTextView needle) {
  PSTFoldedText folded_needle = {};
  if (!pst_fold_text(needle, &folded_needle)) {
    return false;
  }
  bool contains = false;
  for (size_t index = 0; index < haystack_count; ++index) {
    PSTFoldedText folded_haystack = {};
    if (pst_fold_text(haystacks[index], &folded_haystack)) {
      contains = pst_folded_text_contains(&folded_haystack, &folded_needle);
      free(folded_haystack.data);
      if (contains) {
        break;
      }
    }
  }
  free(folded_needle.data);
  return contains;
}

bool pst_text_views_match(const PSTTextView visible_text[static 1],
                          size_t visible_text_count,
                          const PSTTextView required_text[static 1],
                          size_t required_text_count,
                          const PSTTextView any_text[static 1], size_t any_text_count) {
  assert(visible_text != nullptr);
  assert(required_text != nullptr);
  assert(any_text != nullptr);

  for (size_t index = 0; index < required_text_count; ++index) {
    if (!pst_any_view_contains(visible_text, visible_text_count,
                               required_text[index])) {
      return false;
    }
  }
  if (any_text_count == 0) {
    return true;
  }
  for (size_t index = 0; index < any_text_count; ++index) {
    if (pst_any_view_contains(visible_text, visible_text_count, any_text[index])) {
      return true;
    }
  }
  return false;
}
