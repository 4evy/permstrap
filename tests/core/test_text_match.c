#include "core/PSTTextMatch.h"

#include <assert.h>
#include <string.h>

#define PST_TEXT(value) ((PSTTextView){.data = (value), .length = sizeof(value) - 1})

int main(void) {
  const PSTTextView visible[] = {
      PST_TEXT("System Settings wants to make changes."),
      PST_TEXT("Enter an Administrator PASSWORD to allow this."),
  };
  const PSTTextView required[] = {PST_TEXT("password")};
  const PSTTextView any[] = {
      PST_TEXT("system settings"),
      PST_TEXT("password to make changes"),
  };
  assert(pst_text_views_match(visible, sizeof visible / sizeof *visible, required,
                              sizeof required / sizeof *required, any,
                              sizeof any / sizeof *any));

  const PSTTextView missing_required[] = {PST_TEXT("touch id")};
  assert(!pst_text_views_match(visible, sizeof visible / sizeof *visible,
                               missing_required,
                               sizeof missing_required / sizeof *missing_required, any,
                               sizeof any / sizeof *any));

  const PSTTextView no_any[] = {PST_TEXT("")};
  assert(pst_text_views_match(visible, sizeof visible / sizeof *visible, required,
                              sizeof required / sizeof *required, no_any, 0));

  const PSTTextView unrelated[] = {PST_TEXT("unrelated prompt")};
  assert(!pst_text_views_match(unrelated, sizeof unrelated / sizeof *unrelated,
                               required, sizeof required / sizeof *required, any,
                               sizeof any / sizeof *any));

  const PSTTextView localized_visible[] = {
      PST_TEXT("Die Stra\xC3\x9F"
               "e ist ge\xC3\xB6"
               "ffnet."),
      PST_TEXT("Cafe\xCC\x81"),
  };
  const PSTTextView localized_required[] = {
      PST_TEXT("STRASSE"),
      PST_TEXT("CAF\xC3\x89"),
  };
  assert(pst_text_views_match(
      localized_visible, sizeof localized_visible / sizeof *localized_visible,
      localized_required, sizeof localized_required / sizeof *localized_required,
      no_any, 0));

  const PSTTextView malformed_visible[] = {
      {.data = "\xC3", .length = 1},
  };
  assert(!pst_text_views_match(
      malformed_visible, sizeof malformed_visible / sizeof *malformed_visible, required,
      sizeof required / sizeof *required, no_any, 0));
  return 0;
}
