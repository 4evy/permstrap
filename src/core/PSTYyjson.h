#ifndef PST_YYJSON_H
#define PST_YYJSON_H

#include "core/PSTC23.h"

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include <yyjson.h>

constexpr size_t PST_JSON_DIAGNOSTIC_CAPACITY = 256;

typedef enum PSTYyjsonObjectError : uint8_t {
  PSTYyjsonObjectValid = 0,
  PSTYyjsonObjectExpected,
  PSTYyjsonObjectDuplicateField,
  PSTYyjsonObjectUnknownField,
} PSTYyjsonObjectError;

/*
 * yyjson_obj_get() and yyjson_arr_get() use defined unsigned wraparound in
 * their indexed fast paths. Permstrap's expanded integer-sanitizer profile
 * intentionally reports unsigned wrap, so traverse through yyjson's iterator
 * APIs instead. Object lookup and container traversal remain library-owned.
 */
[[nodiscard]] static inline yyjson_val *pst_yyjson_obj_get(yyjson_val *object,
                                                           const char *key) {
  yyjson_obj_iter iterator = yyjson_obj_iter_with(object);
  return yyjson_obj_iter_get(&iterator, key);
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-qual"
[[nodiscard]] static inline yyjson_doc *pst_yyjson_read(const void *data, size_t length,
                                                        yyjson_read_err *error) {
  /*
   * yyjson guarantees that input is not modified unless YYJSON_READ_INSITU is
   * set, but its diagnostic-preserving entry point predates a const parameter.
   */
  return yyjson_read_opts((char *)data, length, YYJSON_READ_NOFLAG, nullptr, error);
}
#pragma clang diagnostic pop

[[nodiscard]] static inline bool pst_yyjson_string_is_safe(yyjson_val *value) {
  if (!yyjson_is_str(value) || yyjson_get_len(value) == 0) {
    return false;
  }
  const char *string = yyjson_get_str(value);
  return string != nullptr && memchr(string, '\0', yyjson_get_len(value)) == nullptr;
}

[[nodiscard]] static inline bool
pst_yyjson_key_is_allowed(yyjson_val *key, const char *const *allowed_keys,
                          size_t allowed_key_count) {
  for (size_t index = 0; index < allowed_key_count; ++index) {
    if (yyjson_equals_str(key, allowed_keys[index])) {
      return true;
    }
  }
  return false;
}

[[nodiscard]] static inline bool
pst_yyjson_object_has_duplicate_key(yyjson_val *object) {
  yyjson_obj_iter outer = yyjson_obj_iter_with(object);
  yyjson_val *key = nullptr;
  size_t outer_index = 0;
  while ((key = yyjson_obj_iter_next(&outer)) != nullptr) {
    yyjson_obj_iter inner = yyjson_obj_iter_with(object);
    for (size_t inner_index = 0; inner_index < outer_index; ++inner_index) {
      yyjson_val *previous = yyjson_obj_iter_next(&inner);
      if (previous != nullptr && yyjson_equals(key, previous)) {
        return true;
      }
    }
    ++outer_index;
  }
  return false;
}

[[nodiscard]] static inline PSTYyjsonObjectError
pst_yyjson_validate_object(yyjson_val *value, const char *const *allowed_keys,
                           size_t allowed_key_count) {
  if (!yyjson_is_obj(value)) {
    return PSTYyjsonObjectExpected;
  }
  if (pst_yyjson_object_has_duplicate_key(value)) {
    return PSTYyjsonObjectDuplicateField;
  }
  yyjson_obj_iter iterator = yyjson_obj_iter_with(value);
  yyjson_val *key = nullptr;
  while ((key = yyjson_obj_iter_next(&iterator)) != nullptr) {
    if (!pst_yyjson_key_is_allowed(key, allowed_keys, allowed_key_count)) {
      return PSTYyjsonObjectUnknownField;
    }
  }
  return PSTYyjsonObjectValid;
}

[[nodiscard]] static inline const char *
pst_yyjson_object_error_description(PSTYyjsonObjectError error) {
  static const char *const descriptions[] = {
      [PSTYyjsonObjectValid] = nullptr,
      [PSTYyjsonObjectExpected] = "must be an object",
      [PSTYyjsonObjectDuplicateField] = "contains a duplicate field",
      [PSTYyjsonObjectUnknownField] = "contains an unknown field",
  };
  static_assert(PST_ARRAY_COUNT(descriptions) == PSTYyjsonObjectUnknownField + 1);
  return error <= PSTYyjsonObjectUnknownField ? descriptions[error] : nullptr;
}

static inline void pst_yyjson_child_path(char output[PST_JSON_DIAGNOSTIC_CAPACITY],
                                         const char *path, const char *key) {
  (void)snprintf(output, PST_JSON_DIAGNOSTIC_CAPACITY, "%s/%s", path, key);
}

static inline void pst_yyjson_index_path(char output[PST_JSON_DIAGNOSTIC_CAPACITY],
                                         const char *path, size_t index) {
  (void)snprintf(output, PST_JSON_DIAGNOSTIC_CAPACITY, "%s/%zu", path, index);
}

#endif
