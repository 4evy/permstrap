#include "policy/PSTRuntimePolicyValidation.h"

#include "core/PSTTime.h"
#include "core/PSTYyjson.h"
#include "policy/PSTRuntimePolicyTypes.h"

#include <limits.h>
#include <stdio.h>
#include <string.h>

#include <yyjson.h>

typedef struct PSTStringView {
  const char *data;
  size_t length;
} PSTStringView;

static const char PST_RUNTIME_POLICY_SCHEMA[] = "./RuntimePolicy.schema.json";

static bool pst_set_error(PSTRuntimePolicyValidationError *error,
                          PSTRuntimePolicyValidationCode code, const char *path,
                          const char *description) {
  if (error != nullptr) {
    *error = (PSTRuntimePolicyValidationError){
        .code = code,
    };
    (void)snprintf(error->path, sizeof(error->path), "%s", path);
    (void)snprintf(error->description, sizeof(error->description), "%s", description);
  }
  return false;
}

static bool pst_set_read_error(PSTRuntimePolicyValidationError *error,
                               const yyjson_read_err *read_error) {
  if (error != nullptr) {
    *error = (PSTRuntimePolicyValidationError){
        .code = PSTRuntimePolicyValidationInvalidJSON,
        .byte_position = read_error->pos,
    };
    (void)snprintf(error->path, sizeof(error->path), "%s", "<root>");
    (void)snprintf(error->description, sizeof(error->description),
                   "invalid JSON at byte %zu: %s", read_error->pos,
                   read_error->msg != nullptr ? read_error->msg
                                              : "unknown parser error");
  }
  return false;
}

static PSTStringView pst_json_string_view(yyjson_val *value) {
  return (PSTStringView){
      .data = yyjson_get_str(value),
      .length = yyjson_get_len(value),
  };
}

static bool pst_validate_object(yyjson_val *value, const char *const *allowed_keys,
                                size_t allowed_key_count, const char *path,
                                PSTRuntimePolicyValidationCode code,
                                PSTRuntimePolicyValidationError *error) {
  PSTYyjsonObjectError object_error =
      pst_yyjson_validate_object(value, allowed_keys, allowed_key_count);
  if (object_error != PSTYyjsonObjectValid) {
    return pst_set_error(error, code, path,
                         pst_yyjson_object_error_description(object_error));
  }
  return true;
}

static yyjson_val *pst_required_string(yyjson_val *object, const char *key,
                                       const char *path,
                                       PSTRuntimePolicyValidationCode code,
                                       PSTRuntimePolicyValidationError *error) {
  yyjson_val *value = pst_yyjson_obj_get(object, key);
  if (!pst_yyjson_string_is_safe(value)) {
    char item_path[PST_JSON_DIAGNOSTIC_CAPACITY] = {};
    pst_yyjson_child_path(item_path, path, key);
    (void)pst_set_error(error, code, item_path,
                        "must be a non-empty UTF-8 string without NUL");
    return nullptr;
  }
  return value;
}

static yyjson_val *pst_optional_string(yyjson_val *object, const char *key,
                                       const char *path,
                                       PSTRuntimePolicyValidationCode code, bool *valid,
                                       PSTRuntimePolicyValidationError *error) {
  yyjson_val *value = pst_yyjson_obj_get(object, key);
  if (value == nullptr) {
    *valid = true;
    return nullptr;
  }
  if (!pst_yyjson_string_is_safe(value)) {
    char item_path[PST_JSON_DIAGNOSTIC_CAPACITY] = {};
    pst_yyjson_child_path(item_path, path, key);
    *valid = pst_set_error(error, code, item_path,
                           "must be a non-empty UTF-8 string without NUL");
    return nullptr;
  }
  *valid = true;
  return value;
}

static bool pst_required_boolean(yyjson_val *object, const char *key, const char *path,
                                 PSTRuntimePolicyValidationCode code, bool *result,
                                 PSTRuntimePolicyValidationError *error) {
  yyjson_val *value = pst_yyjson_obj_get(object, key);
  if (!yyjson_is_bool(value)) {
    char item_path[PST_JSON_DIAGNOSTIC_CAPACITY] = {};
    pst_yyjson_child_path(item_path, path, key);
    return pst_set_error(error, code, item_path, "must be a boolean");
  }
  if (result != nullptr) {
    *result = yyjson_get_bool(value);
  }
  return true;
}

static bool pst_required_integer(yyjson_val *object, const char *key, const char *path,
                                 uint64_t minimum, uint64_t maximum,
                                 PSTRuntimePolicyValidationCode code, uint64_t *result,
                                 PSTRuntimePolicyValidationError *error) {
  yyjson_val *value = pst_yyjson_obj_get(object, key);
  const bool valid = yyjson_is_uint(value) && yyjson_get_uint(value) >= minimum &&
                     yyjson_get_uint(value) <= maximum;
  if (!valid) {
    char item_path[PST_JSON_DIAGNOSTIC_CAPACITY] = {};
    char description[PST_JSON_DIAGNOSTIC_CAPACITY] = {};
    pst_yyjson_child_path(item_path, path, key);
    (void)snprintf(description, sizeof(description),
                   "must be an integer from %llu through %llu",
                   (unsigned long long)minimum, (unsigned long long)maximum);
    return pst_set_error(error, code, item_path, description);
  }
  if (result != nullptr) {
    *result = yyjson_get_uint(value);
  }
  return true;
}

static bool pst_string_array_contains_c_string(yyjson_val *array,
                                               const char *expected) {
  yyjson_arr_iter iterator = yyjson_arr_iter_with(array);
  yyjson_val *value = nullptr;
  while ((value = yyjson_arr_iter_next(&iterator)) != nullptr) {
    if (yyjson_equals_str(value, expected)) {
      return true;
    }
  }
  return false;
}

typedef bool (*PSTStringValueValidator)(const char *value);

static bool pst_trusted_process_role_is_valid(const char *value) {
  PSTTrustedProcessRole role;
  return pst_trusted_process_role_parse(value, &role);
}

static bool pst_validate_string_array(yyjson_val *object, const char *key,
                                      const char *path,
                                      PSTStringValueValidator value_validator,
                                      PSTRuntimePolicyValidationCode code,
                                      PSTRuntimePolicyValidationError *error) {
  yyjson_val *array = pst_yyjson_obj_get(object, key);
  char item_path[PST_JSON_DIAGNOSTIC_CAPACITY] = {};
  pst_yyjson_child_path(item_path, path, key);
  if (!yyjson_is_arr(array) || yyjson_arr_size(array) == 0) {
    return pst_set_error(error, code, item_path,
                         "must be a non-empty array of strings");
  }

  yyjson_arr_iter outer = yyjson_arr_iter_with(array);
  yyjson_val *value = nullptr;
  size_t outer_index = 0;
  while ((value = yyjson_arr_iter_next(&outer)) != nullptr) {
    if (!pst_yyjson_string_is_safe(value)) {
      return pst_set_error(error, code, item_path,
                           "must contain only non-empty UTF-8 strings");
    }
    yyjson_arr_iter inner = yyjson_arr_iter_with(array);
    for (size_t inner_index = 0; inner_index < outer_index; ++inner_index) {
      yyjson_val *previous = yyjson_arr_iter_next(&inner);
      if (previous != nullptr && yyjson_equals(value, previous)) {
        return pst_set_error(error, code, item_path, "must contain unique strings");
      }
    }
    if (value_validator != nullptr && !value_validator(yyjson_get_str(value))) {
      return pst_set_error(error, code, item_path, "contains an unsupported value");
    }
    ++outer_index;
  }
  return true;
}

static bool pst_bundle_identifier_is_valid(yyjson_val *value) {
  const PSTStringView identifier = pst_json_string_view(value);
  if (identifier.data == nullptr) {
    return false;
  }
  bool saw_period = false;
  bool segment_has_character = false;
  for (size_t index = 0; index < identifier.length; ++index) {
    const unsigned char character = (unsigned char)identifier.data[index];
    if (character == '.') {
      if (!segment_has_character) {
        return false;
      }
      saw_period = true;
      segment_has_character = false;
      continue;
    }
    const bool valid_character = (character >= 'A' && character <= 'Z') ||
                                 (character >= 'a' && character <= 'z') ||
                                 (character >= '0' && character <= '9') ||
                                 character == '_' || character == '-';
    if (!valid_character) {
      return false;
    }
    segment_has_character = true;
  }
  return saw_period && segment_has_character;
}

static bool pst_absolute_path_is_valid(yyjson_val *value) {
  const PSTStringView path = pst_json_string_view(value);
  if (path.data == nullptr || path.length <= 1 || path.data[0] != '/') {
    return false;
  }
  size_t segment_start = 1;
  for (size_t index = 1; index <= path.length; ++index) {
    if (index != path.length && path.data[index] != '/') {
      continue;
    }
    const size_t segment_length = index - segment_start;
    if (segment_length == 2 && path.data[segment_start] == '.' &&
        path.data[segment_start + 1] == '.') {
      return false;
    }
    segment_start = index + 1;
  }
  return true;
}

static bool pst_validate_text_matcher(yyjson_val *object, const char *key,
                                      const char *path,
                                      PSTRuntimePolicyValidationError *error) {
  static const char *const allowed_keys[] = {"required", "any"};
  char matcher_path[PST_JSON_DIAGNOSTIC_CAPACITY] = {};
  pst_yyjson_child_path(matcher_path, path, key);
  yyjson_val *matcher = pst_yyjson_obj_get(object, key);
  return pst_validate_object(
             matcher, allowed_keys, PST_ARRAY_COUNT(allowed_keys), matcher_path,
             PSTRuntimePolicyValidationInvalidAuthorizationPrompt, error) &&
         pst_validate_string_array(matcher, "required", matcher_path, nullptr,
                                   PSTRuntimePolicyValidationInvalidAuthorizationPrompt,
                                   error) &&
         pst_validate_string_array(matcher, "any", matcher_path, nullptr,
                                   PSTRuntimePolicyValidationInvalidAuthorizationPrompt,
                                   error);
}

static bool pst_validate_authorization_prompt(yyjson_val *root,
                                              PSTRuntimePolicyValidationError *error) {
  static const char *const allowed_keys[] = {
      "candidateText",
      "expectedText",
      "credentialRevealButtonTitles",
      "timing",
  };
  static const char *const timing_keys[] = {
      "processAgeToleranceMilliseconds",
      "secureFieldAppearanceAttempts",
      "secureFieldAppearancePollMilliseconds",
      "promptPollMilliseconds",
  };
  static const char path[] = "authorizationPrompt";
  yyjson_val *prompt = pst_yyjson_obj_get(root, path);
  if (!pst_validate_object(prompt, allowed_keys, PST_ARRAY_COUNT(allowed_keys), path,
                           PSTRuntimePolicyValidationInvalidAuthorizationPrompt,
                           error) ||
      !pst_validate_text_matcher(prompt, "candidateText", path, error) ||
      !pst_validate_text_matcher(prompt, "expectedText", path, error) ||
      !pst_validate_string_array(prompt, "credentialRevealButtonTitles", path, nullptr,
                                 PSTRuntimePolicyValidationInvalidAuthorizationPrompt,
                                 error)) {
    return false;
  }

  static const char timing_path[] = "authorizationPrompt/timing";
  yyjson_val *timing = pst_yyjson_obj_get(prompt, "timing");
  if (!pst_validate_object(
          timing, timing_keys, PST_ARRAY_COUNT(timing_keys), timing_path,
          PSTRuntimePolicyValidationInvalidAuthorizationPrompt, error)) {
    return false;
  }
  if (!pst_required_integer(timing, "processAgeToleranceMilliseconds", timing_path, 1,
                            PST_MAX_NANOSECOND_CONVERTIBLE_MILLISECONDS,
                            PSTRuntimePolicyValidationInvalidAuthorizationPrompt,
                            nullptr, error)) {
    return false;
  }
  if (!pst_required_integer(
          timing, "secureFieldAppearanceAttempts", timing_path, 1, LLONG_MAX,
          PSTRuntimePolicyValidationInvalidAuthorizationPrompt, nullptr, error)) {
    return false;
  }
  for (size_t index = 2; index < PST_ARRAY_COUNT(timing_keys); ++index) {
    if (!pst_required_integer(timing, timing_keys[index], timing_path, 1,
                              PST_MAX_NANOSECOND_CONVERTIBLE_MILLISECONDS,
                              PSTRuntimePolicyValidationInvalidAuthorizationPrompt,
                              nullptr, error)) {
      return false;
    }
  }
  return true;
}

static bool pst_validate_system_settings(yyjson_val *root,
                                         PSTRuntimePolicyValidationError *error) {
  static const char *const string_keys[] = {
      "bundleIdentifier",
      "privacyPaneURLPrefix",
      "accessibilityBootstrapRoute",
      "restartLaterButtonTitle",
      "applicationSwitchSuffix",
      "automationRowSuffix",
      "automationToggleRole",
      "automationDisclosureRole",
  };
  static const char *const allowed_keys[] = {
      "bundleIdentifier",
      "privacyPaneURLPrefix",
      "accessibilityBootstrapRoute",
      "restartLaterButtonTitle",
      "applicationSwitchSuffix",
      "automationRowSuffix",
      "automationToggleRole",
      "automationDisclosureRole",
      "interaction",
      "timing",
  };
  static const char *const interaction_keys[] = {
      "permissionListRoles",
      "permissionListMinimumWidth",
      "permissionListMinimumHeight",
      "permissionListFrameTolerance",
      "permissionListAncestorLimit",
      "dropOffsetFromLeft",
      "dropOffsetFromTop",
      "dropEdgeInset",
      "applicationActivationAttempts",
  };
  static const char *const timing_keys[] = {
      "workspaceOpenTimeoutMilliseconds",
      "mainRunLoopPollMilliseconds",
      "paneWaitMilliseconds",
      "elementWaitMilliseconds",
      "authorizationWaitMilliseconds",
      "applicationActivationPollMilliseconds",
      "nativeDragTimeoutMilliseconds",
      "disclosureSettleMilliseconds",
      "pollMilliseconds",
  };

  static const char path[] = "systemSettings";
  yyjson_val *settings = pst_yyjson_obj_get(root, path);
  if (!pst_validate_object(settings, allowed_keys, PST_ARRAY_COUNT(allowed_keys), path,
                           PSTRuntimePolicyValidationInvalidSystemSettings, error)) {
    return false;
  }
  for (size_t index = 0; index < PST_ARRAY_COUNT(string_keys); ++index) {
    yyjson_val *value =
        pst_required_string(settings, string_keys[index], path,
                            PSTRuntimePolicyValidationInvalidSystemSettings, error);
    if (value == nullptr) {
      return false;
    }
    if (index == 0 && !pst_bundle_identifier_is_valid(value)) {
      return pst_set_error(error, PSTRuntimePolicyValidationInvalidSystemSettings,
                           "systemSettings/bundleIdentifier",
                           "must be a bundle identifier");
    }
  }

  static const char interaction_path[] = "systemSettings/interaction";
  yyjson_val *interaction = pst_yyjson_obj_get(settings, "interaction");
  if (!pst_validate_object(interaction, interaction_keys,
                           PST_ARRAY_COUNT(interaction_keys), interaction_path,
                           PSTRuntimePolicyValidationInvalidSystemSettings, error) ||
      !pst_validate_string_array(
          interaction, "permissionListRoles", interaction_path, nullptr,
          PSTRuntimePolicyValidationInvalidSystemSettings, error)) {
    return false;
  }
  for (size_t index = 1; index < PST_ARRAY_COUNT(interaction_keys); ++index) {
    if (!pst_required_integer(
            interaction, interaction_keys[index], interaction_path, 1, UINT32_MAX,
            PSTRuntimePolicyValidationInvalidSystemSettings, nullptr, error)) {
      return false;
    }
  }

  static const char timing_path[] = "systemSettings/timing";
  yyjson_val *timing = pst_yyjson_obj_get(settings, "timing");
  if (!pst_validate_object(timing, timing_keys, PST_ARRAY_COUNT(timing_keys),
                           timing_path, PSTRuntimePolicyValidationInvalidSystemSettings,
                           error)) {
    return false;
  }
  for (size_t index = 0; index < PST_ARRAY_COUNT(timing_keys); ++index) {
    if (!pst_required_integer(timing, timing_keys[index], timing_path, 1,
                              PST_MAX_NANOSECOND_CONVERTIBLE_MILLISECONDS,
                              PSTRuntimePolicyValidationInvalidSystemSettings, nullptr,
                              error)) {
      return false;
    }
  }
  return true;
}

static bool pst_process_has_role(yyjson_val *process, const char *role) {
  return pst_string_array_contains_c_string(pst_yyjson_obj_get(process, "roles"), role);
}

static yyjson_val *pst_find_process(yyjson_val *processes, yyjson_val *identifier) {
  yyjson_arr_iter iterator = yyjson_arr_iter_with(processes);
  yyjson_val *process = nullptr;
  while ((process = yyjson_arr_iter_next(&iterator)) != nullptr) {
    yyjson_val *candidate = pst_yyjson_obj_get(process, "bundleIdentifier");
    if (candidate != nullptr && yyjson_equals(candidate, identifier)) {
      return process;
    }
  }
  return nullptr;
}

static bool pst_validate_trusted_process(yyjson_val *processes, yyjson_val *process,
                                         size_t index,
                                         PSTRuntimePolicyValidationError *error) {
  static const char *const allowed_keys[] = {
      "bundleIdentifier",
      "executablePath",
      "roles",
      "requiresFrontmost",
      "activePromptRequiresSecureField",
      "eventHostBundleIdentifier",
      "localizedNameContains",
  };
  char path[PST_JSON_DIAGNOSTIC_CAPACITY] = {};
  pst_yyjson_index_path(path, "trustedProcesses", index);
  if (!pst_validate_object(process, allowed_keys, PST_ARRAY_COUNT(allowed_keys), path,
                           PSTRuntimePolicyValidationInvalidTrustedProcess, error)) {
    return false;
  }
  yyjson_val *identifier =
      pst_required_string(process, "bundleIdentifier", path,
                          PSTRuntimePolicyValidationInvalidTrustedProcess, error);
  yyjson_val *executable_path =
      pst_required_string(process, "executablePath", path,
                          PSTRuntimePolicyValidationInvalidTrustedProcess, error);
  if (identifier == nullptr || executable_path == nullptr ||
      !pst_validate_string_array(
          process, "roles", path, pst_trusted_process_role_is_valid,
          PSTRuntimePolicyValidationInvalidTrustedProcess, error) ||
      !pst_required_boolean(process, "requiresFrontmost", path,
                            PSTRuntimePolicyValidationInvalidTrustedProcess, nullptr,
                            error)) {
    return false;
  }
  bool requires_secure_field = false;
  if (!pst_required_boolean(process, "activePromptRequiresSecureField", path,
                            PSTRuntimePolicyValidationInvalidTrustedProcess,
                            &requires_secure_field, error)) {
    return false;
  }
  bool optional_is_valid = false;
  yyjson_val *event_host = pst_optional_string(
      process, "eventHostBundleIdentifier", path,
      PSTRuntimePolicyValidationInvalidTrustedProcess, &optional_is_valid, error);
  if (!optional_is_valid) {
    return false;
  }
  yyjson_val *localized_name = pst_optional_string(
      process, "localizedNameContains", path,
      PSTRuntimePolicyValidationInvalidTrustedProcess, &optional_is_valid, error);
  if (!optional_is_valid) {
    return false;
  }

  if (!pst_bundle_identifier_is_valid(identifier)) {
    char item_path[PST_JSON_DIAGNOSTIC_CAPACITY] = {};
    pst_yyjson_child_path(item_path, path, "bundleIdentifier");
    return pst_set_error(error, PSTRuntimePolicyValidationInvalidTrustedProcess,
                         item_path, "must be a bundle identifier");
  }
  if (event_host != nullptr && !pst_bundle_identifier_is_valid(event_host)) {
    char item_path[PST_JSON_DIAGNOSTIC_CAPACITY] = {};
    pst_yyjson_child_path(item_path, path, "eventHostBundleIdentifier");
    return pst_set_error(error, PSTRuntimePolicyValidationInvalidTrustedProcess,
                         item_path, "must be a bundle identifier");
  }
  if (localized_name != nullptr && !pst_yyjson_string_is_safe(localized_name)) {
    char item_path[PST_JSON_DIAGNOSTIC_CAPACITY] = {};
    pst_yyjson_child_path(item_path, path, "localizedNameContains");
    return pst_set_error(error, PSTRuntimePolicyValidationInvalidTrustedProcess,
                         item_path, "must be a non-empty string");
  }
  if (!pst_absolute_path_is_valid(executable_path)) {
    char item_path[PST_JSON_DIAGNOSTIC_CAPACITY] = {};
    pst_yyjson_child_path(item_path, path, "executablePath");
    return pst_set_error(error, PSTRuntimePolicyValidationInvalidTrustedProcess,
                         item_path, "must be a normalized absolute path");
  }

  yyjson_arr_iter previous_iterator = yyjson_arr_iter_with(processes);
  for (size_t previous_index = 0; previous_index < index; ++previous_index) {
    yyjson_val *previous = yyjson_arr_iter_next(&previous_iterator);
    yyjson_val *previous_identifier = pst_yyjson_obj_get(previous, "bundleIdentifier");
    if (previous_identifier != nullptr &&
        yyjson_equals(identifier, previous_identifier)) {
      return pst_set_error(error, PSTRuntimePolicyValidationDuplicateTrustedProcess,
                           "trustedProcesses", "bundle identifiers must be unique");
    }
  }
  if (requires_secure_field &&
      !pst_process_has_role(process, "authorization-ax-host")) {
    char item_path[PST_JSON_DIAGNOSTIC_CAPACITY] = {};
    pst_yyjson_child_path(item_path, path, "activePromptRequiresSecureField");
    return pst_set_error(error, PSTRuntimePolicyValidationInvalidRelationship,
                         item_path, "requires the authorization-ax-host role");
  }
  return true;
}

static bool
pst_validate_trusted_process_relationships(yyjson_val *root, yyjson_val *processes,
                                           PSTRuntimePolicyValidationError *error) {
  yyjson_val *settings = pst_yyjson_obj_get(root, "systemSettings");
  yyjson_val *settings_identifier = pst_yyjson_obj_get(settings, "bundleIdentifier");
  yyjson_val *settings_process = pst_find_process(processes, settings_identifier);
  if (settings_process == nullptr) {
    return pst_set_error(error, PSTRuntimePolicyValidationInvalidRelationship,
                         "systemSettings/bundleIdentifier",
                         "must identify a declared trusted process");
  }
  if (!pst_process_has_role(settings_process, "authorization-ax-host")) {
    return pst_set_error(error, PSTRuntimePolicyValidationInvalidRelationship,
                         "systemSettings/bundleIdentifier",
                         "must identify an authorization Accessibility host");
  }

  yyjson_arr_iter iterator = yyjson_arr_iter_with(processes);
  yyjson_val *process = nullptr;
  size_t index = 0;
  while ((process = yyjson_arr_iter_next(&iterator)) != nullptr) {
    yyjson_val *event_host = pst_yyjson_obj_get(process, "eventHostBundleIdentifier");
    if (event_host == nullptr) {
      ++index;
      continue;
    }
    char process_path[PST_JSON_DIAGNOSTIC_CAPACITY] = {};
    char item_path[PST_JSON_DIAGNOSTIC_CAPACITY] = {};
    pst_yyjson_index_path(process_path, "trustedProcesses", index);
    pst_yyjson_child_path(item_path, process_path, "eventHostBundleIdentifier");
    yyjson_val *referenced_process = pst_find_process(processes, event_host);
    if (referenced_process == nullptr) {
      return pst_set_error(error, PSTRuntimePolicyValidationInvalidRelationship,
                           item_path, "must reference a declared trusted process");
    }
    if (!pst_process_has_role(referenced_process, "authorization-event-host")) {
      return pst_set_error(error, PSTRuntimePolicyValidationInvalidRelationship,
                           item_path, "must reference an authorization event host");
    }
    ++index;
  }
  return true;
}

static bool pst_validate_trusted_processes(yyjson_val *root,
                                           PSTRuntimePolicyValidationError *error) {
  yyjson_val *processes = pst_yyjson_obj_get(root, "trustedProcesses");
  if (!yyjson_is_arr(processes) || yyjson_arr_size(processes) == 0) {
    return pst_set_error(error, PSTRuntimePolicyValidationInvalidTrustedProcess,
                         "trustedProcesses", "must be a non-empty array");
  }
  yyjson_arr_iter iterator = yyjson_arr_iter_with(processes);
  yyjson_val *process = nullptr;
  size_t index = 0;
  while ((process = yyjson_arr_iter_next(&iterator)) != nullptr) {
    if (!pst_validate_trusted_process(processes, process, index, error)) {
      return false;
    }
    ++index;
  }
  return pst_validate_trusted_process_relationships(root, processes, error);
}

static bool pst_validate_root(yyjson_val *root,
                              PSTRuntimePolicyValidationError *error) {
  static const char *const allowed_keys[] = {
      "$schema", "version", "authorizationPrompt", "systemSettings", "trustedProcesses",
  };
  if (!pst_validate_object(root, allowed_keys, PST_ARRAY_COUNT(allowed_keys), "<root>",
                           PSTRuntimePolicyValidationInvalidJSON, error)) {
    return false;
  }
  yyjson_val *schema = pst_required_string(
      root, "$schema", "<root>", PSTRuntimePolicyValidationInvalidJSON, error);
  if (schema == nullptr) {
    return false;
  }
  if (!yyjson_equals_str(schema, PST_RUNTIME_POLICY_SCHEMA)) {
    return pst_set_error(error, PSTRuntimePolicyValidationInvalidJSON, "$schema",
                         "must be ./RuntimePolicy.schema.json");
  }
  uint64_t version = 0;
  if (!pst_required_integer(root, "version", "<root>", 1, LLONG_MAX,
                            PSTRuntimePolicyValidationUnsupportedVersion, &version,
                            error)) {
    return false;
  }
  if (version != PST_RUNTIME_POLICY_VERSION) {
    return pst_set_error(error, PSTRuntimePolicyValidationUnsupportedVersion, "version",
                         "must be exactly 1");
  }
  return pst_validate_authorization_prompt(root, error) &&
         pst_validate_system_settings(root, error) &&
         pst_validate_trusted_processes(root, error);
}

bool pst_runtime_policy_validate(const void *data, size_t length,
                                 PSTRuntimePolicyValidationError *error) {
  if (error != nullptr) {
    *error = (PSTRuntimePolicyValidationError){};
  }
  if (data == nullptr || length == 0) {
    return pst_set_error(error, PSTRuntimePolicyValidationInvalidJSON, "<root>",
                         "invalid JSON: input is empty");
  }
  yyjson_read_err read_error = {};
  yyjson_doc *document = pst_yyjson_read(data, length, &read_error);
  if (document == nullptr) {
    return pst_set_read_error(error, &read_error);
  }
  const bool valid = pst_validate_root(yyjson_doc_get_root(document), error);
  yyjson_doc_free(document);
  return valid;
}
