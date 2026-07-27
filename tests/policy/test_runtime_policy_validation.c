#include "policy/PSTRuntimePolicyValidation.h"

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void *read_file(const char *path, size_t *length) {
  FILE *file = fopen(path, "rb");
  assert(file != nullptr);
  assert(fseek(file, 0, SEEK_END) == 0);
  const long file_length = ftell(file);
  assert(file_length > 0);
  assert(fseek(file, 0, SEEK_SET) == 0);

  *length = (size_t)file_length;
  char *data = malloc(*length + 1);
  assert(data != nullptr);
  assert(fread(data, 1, *length, file) == *length);
  data[*length] = '\0';
  assert(fclose(file) == 0);
  return data;
}

static void assert_invalid(const char *json,
                           PSTRuntimePolicyValidationCode expected_code) {
  PSTRuntimePolicyValidationError error = {};
  assert(!pst_runtime_policy_validate(json, strlen(json), &error));
  assert(error.code == expected_code);
  assert(error.path[0] != '\0');
  assert(error.description[0] != '\0');
}

static char *copy_replacing_once(const char *source, size_t source_length,
                                 const char *needle, const char *replacement) {
  const char *match = strstr(source, needle);
  assert(match != nullptr);
  const size_t prefix_length = (size_t)(match - source);
  const size_t needle_length = strlen(needle);
  const size_t replacement_length = strlen(replacement);
  const size_t result_length = source_length - needle_length + replacement_length;
  char *result = malloc(result_length + 1);
  assert(result != nullptr);
  memcpy(result, source, prefix_length);
  memcpy(result + prefix_length, replacement, replacement_length);
  memcpy(result + prefix_length + replacement_length, match + needle_length,
         source_length - prefix_length - needle_length);
  result[result_length] = '\0';
  return result;
}

int main(int argc, char *argv[]) {
  assert(argc == 2);
  size_t length = 0;
  void *data = read_file(argv[1], &length);
  PSTRuntimePolicyValidationError error = {};
  assert(pst_runtime_policy_validate(data, length, &error));

  char *oversized_poll =
      copy_replacing_once(data, length, "\"promptPollMilliseconds\": 50",
                          "\"promptPollMilliseconds\": 18446744073710");
  assert_invalid(oversized_poll, PSTRuntimePolicyValidationInvalidAuthorizationPrompt);
  free(oversized_poll);

  char *oversized_pane =
      copy_replacing_once(data, length, "\"paneWaitMilliseconds\": 12000",
                          "\"paneWaitMilliseconds\": 18446744073710");
  assert_invalid(oversized_pane, PSTRuntimePolicyValidationInvalidSystemSettings);
  free(oversized_pane);

  char *invalid_list_width =
      copy_replacing_once(data, length, "\"permissionListMinimumWidth\": 240",
                          "\"permissionListMinimumWidth\": 0");
  assert_invalid(invalid_list_width, PSTRuntimePolicyValidationInvalidSystemSettings);
  free(invalid_list_width);

  char *oversized_list_width =
      copy_replacing_once(data, length, "\"permissionListMinimumWidth\": 240",
                          "\"permissionListMinimumWidth\": 4294967296");
  assert_invalid(oversized_list_width, PSTRuntimePolicyValidationInvalidSystemSettings);
  free(oversized_list_width);
  free(data);

  assert_invalid("{", PSTRuntimePolicyValidationInvalidJSON);
  assert_invalid("[]", PSTRuntimePolicyValidationInvalidJSON);
  assert_invalid("{\"magic\":true}", PSTRuntimePolicyValidationInvalidJSON);
  assert_invalid("{\"$schema\":\"./RuntimePolicy.schema.json\","
                 "\"$schema\":\"./RuntimePolicy.schema.json\"}",
                 PSTRuntimePolicyValidationInvalidJSON);
  assert_invalid("{\"$schema\":\"./RuntimePolicy.schema.json\\u0000\","
                 "\"version\":1}",
                 PSTRuntimePolicyValidationInvalidJSON);

  error = (PSTRuntimePolicyValidationError){};
  assert(!pst_runtime_policy_validate(nullptr, 0, &error));
  assert(error.code == PSTRuntimePolicyValidationInvalidJSON);
  return 0;
}
