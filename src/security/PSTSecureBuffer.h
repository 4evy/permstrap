#ifndef PST_SECURE_BUFFER_H
#define PST_SECURE_BUFFER_H

#include "core/PSTC23.h"

#include <stddef.h>
#include <stdint.h>

/* Maximum UTF-8 credential bytes retained by the application. */
constexpr size_t PST_CREDENTIAL_BUFFER_CAPACITY = 1'024;

typedef struct {
  uint8_t *bytes;
  size_t capacity;
  size_t data_length;
} PSTSecureBuffer;

[[nodiscard("locked-memory allocation failure must be handled")]]
bool pst_secure_buffer_init(PSTSecureBuffer *buffer, size_t capacity);
[[nodiscard("credential assignment failure must be handled")]]
bool pst_secure_buffer_assign(PSTSecureBuffer *buffer, const void *source,
                              size_t source_length);
[[nodiscard("credential move failure must be handled")]]
bool pst_secure_buffer_move(PSTSecureBuffer *buffer, void *source,
                            size_t source_length);
void pst_secure_buffer_clear(PSTSecureBuffer *buffer);
void pst_secure_buffer_destroy(PSTSecureBuffer *buffer);

#endif
