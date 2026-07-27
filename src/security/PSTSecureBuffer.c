#include "security/PSTSecureBuffer.h"

#include <sodium/core.h>
#include <sodium/utils.h>

#include <stdckdint.h>
#include <string.h>

bool pst_secure_buffer_init(PSTSecureBuffer *buffer, size_t capacity) {
  if (buffer == nullptr || capacity == 0) {
    return false;
  }
  *buffer = (PSTSecureBuffer){};

  size_t allocation_length = 0;
  if (ckd_add(&allocation_length, capacity, 1) || sodium_init() < 0) {
    return false;
  }
  uint8_t *bytes = sodium_malloc(allocation_length);
  if (bytes == nullptr) {
    return false;
  }
  if (sodium_mlock(bytes, allocation_length) != 0) {
    sodium_free(bytes);
    return false;
  }
  sodium_memzero(bytes, allocation_length);

  buffer->bytes = bytes;
  buffer->capacity = capacity;
  buffer->data_length = 0;
  return true;
}

bool pst_secure_buffer_assign(PSTSecureBuffer *buffer, const void *source,
                              size_t source_length) {
  if (buffer == nullptr || buffer->bytes == nullptr || source == nullptr ||
      source_length > buffer->capacity) {
    return false;
  }
  pst_secure_buffer_clear(buffer);
  memcpy(buffer->bytes, source, source_length);
  buffer->bytes[source_length] = 0;
  buffer->data_length = source_length;
  return true;
}

bool pst_secure_buffer_move(PSTSecureBuffer *buffer, void *source,
                            size_t source_length) {
  if (source == nullptr) {
    return false;
  }
  bool assigned = pst_secure_buffer_assign(buffer, source, source_length);
  if (source_length > 0) {
    sodium_memzero(source, source_length);
  }
  return assigned;
}

void pst_secure_buffer_clear(PSTSecureBuffer *buffer) {
  if (buffer == nullptr || buffer->bytes == nullptr) {
    return;
  }
  size_t clear_length = 0;
  if (ckd_add(&clear_length, buffer->capacity, 1)) {
    sodium_misuse();
  }
  sodium_memzero(buffer->bytes, clear_length);
  buffer->data_length = 0;
}

void pst_secure_buffer_destroy(PSTSecureBuffer *buffer) {
  if (buffer == nullptr) {
    return;
  }
  if (buffer->bytes != nullptr) {
    sodium_free(buffer->bytes);
  }
  *buffer = (PSTSecureBuffer){};
}
