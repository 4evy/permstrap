#include "security/PSTSecureBuffer.h"

#include <assert.h>
#include <stdint.h>
#include <string.h>

int main(void) {
  PSTSecureBuffer buffer;
  assert(pst_secure_buffer_init(&buffer, 32));
  assert(buffer.capacity == 32);
  assert(buffer.data_length == 0);

  const char secret[] = "correct horse";
  assert(pst_secure_buffer_assign(&buffer, secret, strlen(secret)));
  assert(buffer.data_length == strlen(secret));
  assert(memcmp(buffer.bytes, secret, strlen(secret)) == 0);
  assert(buffer.bytes[buffer.data_length] == 0);

  char moved_secret[] = "literal password";
  assert(pst_secure_buffer_move(&buffer, moved_secret, strlen(moved_secret)));
  assert(buffer.data_length == strlen("literal password"));
  assert(memcmp(buffer.bytes, "literal password", buffer.data_length) == 0);
  for (size_t index = 0; index < sizeof(moved_secret) - 1; index++) {
    assert(moved_secret[index] == 0);
  }

  pst_secure_buffer_clear(&buffer);
  assert(buffer.data_length == 0);
  for (size_t index = 0; index <= buffer.capacity; index++) {
    assert(buffer.bytes[index] == 0);
  }

  uint8_t too_large[33] = {};
  assert(!pst_secure_buffer_assign(&buffer, too_large, sizeof(too_large)));
  uint8_t moved_too_large[33];
  memset(moved_too_large, 'x', sizeof(moved_too_large));
  assert(!pst_secure_buffer_move(&buffer, moved_too_large, sizeof(moved_too_large)));
  for (size_t index = 0; index < sizeof(moved_too_large); index++) {
    assert(moved_too_large[index] == 0);
  }

  pst_secure_buffer_destroy(&buffer);
  assert(buffer.bytes == nullptr);
  assert(buffer.capacity == 0);
  assert(buffer.data_length == 0);
  return 0;
}
