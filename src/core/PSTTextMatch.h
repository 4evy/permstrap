#ifndef PST_TEXT_MATCH_H
#define PST_TEXT_MATCH_H

#include "core/PSTC23.h"

#include <stddef.h>

typedef struct {
  const char *data;
  size_t length;
} PSTTextView;

/*
 * Performs locale-independent Unicode case folding and canonical normalization.
 * Every view must contain valid UTF-8; a malformed view fails closed.
 */
[[nodiscard("authorization text decisions must be checked")]]
bool pst_text_views_match(const PSTTextView visible_text[static 1],
                          size_t visible_text_count,
                          const PSTTextView required_text[static 1],
                          size_t required_text_count,
                          const PSTTextView any_text[static 1], size_t any_text_count);

#endif
