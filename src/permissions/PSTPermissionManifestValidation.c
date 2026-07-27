#include "permissions/PSTPermissionManifestValidation.h"

#include "core/PSTYyjson.h"
#include "permissions/PSTPermissionTypes.h"

#include <stdio.h>
#include <string.h>

#include <yyjson.h>

static const char PST_PERMISSION_CATALOG_SCHEMA[] = "./Permissions.schema.json";
static const char PST_PERMISSION_TARGETS_SCHEMA[] = "./PermissionTargets.schema.json";

static bool pst_manifest_set_error(PSTPermissionManifestValidationError *error,
                                   PSTPermissionManifestValidationCode code,
                                   const char *path, const char *description) {
  if (error != nullptr) {
    *error = (PSTPermissionManifestValidationError){
        .code = code,
    };
    (void)snprintf(error->path, sizeof(error->path), "%s", path);
    (void)snprintf(error->description, sizeof(error->description), "%s", description);
  }
  return false;
}

static bool pst_manifest_set_read_error(PSTPermissionManifestValidationError *error,
                                        const yyjson_read_err *read_error) {
  if (error != nullptr) {
    *error = (PSTPermissionManifestValidationError){
        .code = PSTPermissionManifestValidationInvalidJSON,
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

static bool pst_manifest_validate_object(yyjson_val *value,
                                         const char *const *allowed_keys,
                                         size_t allowed_key_count, const char *path,
                                         PSTPermissionManifestValidationCode code,
                                         PSTPermissionManifestValidationError *error) {
  PSTYyjsonObjectError object_error =
      pst_yyjson_validate_object(value, allowed_keys, allowed_key_count);
  if (object_error != PSTYyjsonObjectValid) {
    return pst_manifest_set_error(error, code, path,
                                  pst_yyjson_object_error_description(object_error));
  }
  return true;
}

static yyjson_val *
pst_manifest_required_string(yyjson_val *object, const char *key, const char *path,
                             PSTPermissionManifestValidationCode code,
                             PSTPermissionManifestValidationError *error) {
  yyjson_val *value = pst_yyjson_obj_get(object, key);
  if (!pst_yyjson_string_is_safe(value)) {
    char item_path[PST_JSON_DIAGNOSTIC_CAPACITY] = {};
    pst_yyjson_child_path(item_path, path, key);
    (void)pst_manifest_set_error(error, code, item_path,
                                 "must be a non-empty UTF-8 string without NUL");
    return nullptr;
  }
  return value;
}

static bool pst_manifest_optional_boolean(yyjson_val *object, const char *key,
                                          const char *path,
                                          PSTPermissionManifestValidationCode code,
                                          PSTPermissionManifestValidationError *error) {
  yyjson_val *value = pst_yyjson_obj_get(object, key);
  if (value == nullptr || yyjson_is_bool(value)) {
    return true;
  }
  char item_path[PST_JSON_DIAGNOSTIC_CAPACITY] = {};
  pst_yyjson_child_path(item_path, path, key);
  return pst_manifest_set_error(error, code, item_path, "must be a boolean");
}

static bool pst_manifest_required_boolean(yyjson_val *object, const char *key,
                                          const char *path,
                                          PSTPermissionManifestValidationCode code,
                                          PSTPermissionManifestValidationError *error) {
  if (yyjson_is_bool(pst_yyjson_obj_get(object, key))) {
    return true;
  }
  char item_path[PST_JSON_DIAGNOSTIC_CAPACITY] = {};
  pst_yyjson_child_path(item_path, path, key);
  return pst_manifest_set_error(error, code, item_path, "must be a boolean");
}

static bool
pst_manifest_validate_string_array(yyjson_val *value, const char *path,
                                   PSTPermissionManifestValidationCode code,
                                   PSTPermissionManifestValidationError *error) {
  if (!yyjson_is_arr(value) || yyjson_arr_size(value) == 0) {
    return pst_manifest_set_error(error, code, path,
                                  "must be a non-empty array of strings");
  }
  yyjson_arr_iter outer = yyjson_arr_iter_with(value);
  yyjson_val *element = nullptr;
  size_t outer_index = 0;
  while ((element = yyjson_arr_iter_next(&outer)) != nullptr) {
    if (!pst_yyjson_string_is_safe(element)) {
      return pst_manifest_set_error(error, code, path,
                                    "must contain only non-empty UTF-8 strings");
    }
    yyjson_arr_iter inner = yyjson_arr_iter_with(value);
    for (size_t inner_index = 0; inner_index < outer_index; ++inner_index) {
      yyjson_val *previous = yyjson_arr_iter_next(&inner);
      if (previous != nullptr && yyjson_equals(element, previous)) {
        return pst_manifest_set_error(error, code, path, "must contain unique strings");
      }
    }
    ++outer_index;
  }
  return true;
}

static bool pst_manifest_validate_optional_string_array(
    yyjson_val *object, const char *key, const char *path,
    PSTPermissionManifestValidationCode code,
    PSTPermissionManifestValidationError *error) {
  yyjson_val *value = pst_yyjson_obj_get(object, key);
  if (value == nullptr) {
    return true;
  }
  char item_path[PST_JSON_DIAGNOSTIC_CAPACITY] = {};
  pst_yyjson_child_path(item_path, path, key);
  return pst_manifest_validate_string_array(value, item_path, code, error);
}

static bool pst_manifest_validate_version(yyjson_val *root,
                                          PSTPermissionManifestValidationError *error) {
  yyjson_val *version = pst_yyjson_obj_get(root, "version");
  if (!yyjson_is_uint(version) ||
      yyjson_get_uint(version) != PST_PERMISSION_MANIFEST_VERSION) {
    return pst_manifest_set_error(error,
                                  PSTPermissionManifestValidationUnsupportedVersion,
                                  "version", "must be exactly 1");
  }
  return true;
}

static bool pst_manifest_validate_schema(yyjson_val *root, const char *expected,
                                         PSTPermissionManifestValidationError *error) {
  yyjson_val *schema = pst_manifest_required_string(
      root, "$schema", "<root>", PSTPermissionManifestValidationInvalidJSON, error);
  if (schema == nullptr) {
    return false;
  }
  if (!yyjson_equals_str(schema, expected)) {
    char description[PST_JSON_DIAGNOSTIC_CAPACITY] = {};
    (void)snprintf(description, sizeof(description), "must be %s", expected);
    return pst_manifest_set_error(error, PSTPermissionManifestValidationInvalidJSON,
                                  "$schema", description);
  }
  return true;
}

static yyjson_val *pst_manifest_service_with_identifier(yyjson_val *services,
                                                        yyjson_val *identifier) {
  yyjson_arr_iter iterator = yyjson_arr_iter_with(services);
  yyjson_val *service = nullptr;
  while ((service = yyjson_arr_iter_next(&iterator)) != nullptr) {
    yyjson_val *candidate = pst_yyjson_obj_get(service, "id");
    if (candidate != nullptr && yyjson_equals(candidate, identifier)) {
      return service;
    }
  }
  return nullptr;
}

static bool
pst_manifest_validate_services(yyjson_val *services,
                               PSTPermissionManifestValidationError *error) {
  static const char *const allowed_keys[] = {
      "id", "name", "description", "symbol", "route", "requiresAdmin", "mode",
  };
  yyjson_arr_iter iterator = yyjson_arr_iter_with(services);
  yyjson_val *service = nullptr;
  size_t index = 0;
  while ((service = yyjson_arr_iter_next(&iterator)) != nullptr) {
    char path[PST_JSON_DIAGNOSTIC_CAPACITY] = {};
    pst_yyjson_index_path(path, "services", index);
    if (!pst_manifest_validate_object(
            service, allowed_keys, PST_ARRAY_COUNT(allowed_keys), path,
            PSTPermissionManifestValidationInvalidService, error)) {
      return false;
    }
    yyjson_val *identifier = pst_manifest_required_string(
        service, "id", path, PSTPermissionManifestValidationInvalidService, error);
    yyjson_val *name = pst_manifest_required_string(
        service, "name", path, PSTPermissionManifestValidationInvalidService, error);
    yyjson_val *route = pst_manifest_required_string(
        service, "route", path, PSTPermissionManifestValidationInvalidService, error);
    yyjson_val *mode_value = pst_manifest_required_string(
        service, "mode", path, PSTPermissionManifestValidationInvalidService, error);
    yyjson_val *description = pst_yyjson_obj_get(service, "description");
    yyjson_val *symbol = pst_yyjson_obj_get(service, "symbol");
    if (identifier == nullptr || name == nullptr || route == nullptr ||
        mode_value == nullptr ||
        (description != nullptr && !pst_yyjson_string_is_safe(description)) ||
        (symbol != nullptr && !pst_yyjson_string_is_safe(symbol)) ||
        !pst_manifest_required_boolean(service, "requiresAdmin", path,
                                       PSTPermissionManifestValidationInvalidService,
                                       error)) {
      return false;
    }
    PSTPermissionServiceMode mode = PSTPermissionServiceModeApplicationList;
    if (!pst_permission_service_mode_parse(yyjson_get_str(mode_value), &mode)) {
      return pst_manifest_set_error(error,
                                    PSTPermissionManifestValidationInvalidService, path,
                                    "mode contains an unsupported value");
    }
    yyjson_arr_iter previous_iterator = yyjson_arr_iter_with(services);
    for (size_t previous_index = 0; previous_index < index; ++previous_index) {
      yyjson_val *previous = yyjson_arr_iter_next(&previous_iterator);
      yyjson_val *previous_identifier = pst_yyjson_obj_get(previous, "id");
      if (previous_identifier != nullptr &&
          yyjson_equals(identifier, previous_identifier)) {
        return pst_manifest_set_error(error,
                                      PSTPermissionManifestValidationDuplicateService,
                                      "services", "service identifiers must be unique");
      }
    }
    ++index;
  }
  return true;
}

static bool
pst_manifest_validate_permission_sets(yyjson_val *permission_sets, yyjson_val *services,
                                      PSTPermissionManifestValidationError *error) {
  static const char *const allowed_keys[] = {
      "name",
      "description",
      "services",
  };
  if (pst_yyjson_object_has_duplicate_key(permission_sets)) {
    return pst_manifest_set_error(
        error, PSTPermissionManifestValidationInvalidPermissionSet, "permissionSets",
        "permission set identifiers must be unique");
  }
  yyjson_obj_iter iterator = yyjson_obj_iter_with(permission_sets);
  yyjson_val *identifier = nullptr;
  while ((identifier = yyjson_obj_iter_next(&iterator)) != nullptr) {
    if (!pst_yyjson_string_is_safe(identifier)) {
      return pst_manifest_set_error(
          error, PSTPermissionManifestValidationInvalidPermissionSet, "permissionSets",
          "permission set identifiers must be non-empty strings");
    }
    char path[PST_JSON_DIAGNOSTIC_CAPACITY] = {};
    (void)snprintf(path, sizeof(path), "permissionSets/%s", yyjson_get_str(identifier));
    yyjson_val *permission_set = yyjson_obj_iter_get_val(identifier);
    if (!pst_manifest_validate_object(
            permission_set, allowed_keys, PST_ARRAY_COUNT(allowed_keys), path,
            PSTPermissionManifestValidationInvalidPermissionSet, error)) {
      return false;
    }
    yyjson_val *name = pst_manifest_required_string(
        permission_set, "name", path,
        PSTPermissionManifestValidationInvalidPermissionSet, error);
    yyjson_val *description = pst_yyjson_obj_get(permission_set, "description");
    yyjson_val *service_identifiers = pst_yyjson_obj_get(permission_set, "services");
    char services_path[PST_JSON_DIAGNOSTIC_CAPACITY] = {};
    pst_yyjson_child_path(services_path, path, "services");
    if (name == nullptr ||
        (description != nullptr && !pst_yyjson_string_is_safe(description)) ||
        !pst_manifest_validate_string_array(
            service_identifiers, services_path,
            PSTPermissionManifestValidationInvalidPermissionSet, error)) {
      return false;
    }
    yyjson_arr_iter service_iterator = yyjson_arr_iter_with(service_identifiers);
    yyjson_val *service_identifier = nullptr;
    while ((service_identifier = yyjson_arr_iter_next(&service_iterator)) != nullptr) {
      if (pst_manifest_service_with_identifier(services, service_identifier) ==
          nullptr) {
        return pst_manifest_set_error(error,
                                      PSTPermissionManifestValidationUnknownService,
                                      services_path, "refers to an unknown service");
      }
    }
  }
  return true;
}

static bool
pst_manifest_validate_catalog_root(yyjson_val *root,
                                   PSTPermissionManifestValidationError *error) {
  static const char *const allowed_keys[] = {
      "$schema",
      "version",
      "services",
      "permissionSets",
  };
  if (!pst_manifest_validate_object(
          root, allowed_keys, PST_ARRAY_COUNT(allowed_keys), "<root>",
          PSTPermissionManifestValidationInvalidJSON, error) ||
      !pst_manifest_validate_schema(root, PST_PERMISSION_CATALOG_SCHEMA, error) ||
      !pst_manifest_validate_version(root, error)) {
    return false;
  }
  yyjson_val *services = pst_yyjson_obj_get(root, "services");
  yyjson_val *permission_sets = pst_yyjson_obj_get(root, "permissionSets");
  if (!yyjson_is_arr(services) || yyjson_arr_size(services) == 0 ||
      !yyjson_is_obj(permission_sets) || yyjson_obj_size(permission_sets) == 0) {
    return pst_manifest_set_error(error, PSTPermissionManifestValidationInvalidJSON,
                                  "<root>",
                                  "requires non-empty services and permission sets");
  }
  return pst_manifest_validate_services(services, error) &&
         pst_manifest_validate_permission_sets(permission_sets, services, error);
}

static bool pst_manifest_validate_permission_selection(
    yyjson_val *selection, const char *path,
    PSTPermissionManifestValidationError *error) {
  static const char *const allowed_keys[] = {
      "inheritDefaults",
      "sets",
      "include",
      "exclude",
  };
  if (!pst_manifest_validate_object(
          selection, allowed_keys, PST_ARRAY_COUNT(allowed_keys), path,
          PSTPermissionManifestValidationInvalidTarget, error)) {
    return false;
  }
  if (!pst_manifest_optional_boolean(selection, "inheritDefaults", path,
                                     PSTPermissionManifestValidationInvalidTarget,
                                     error)) {
    return false;
  }
  bool has_selector = false;
  for (size_t index = 1; index < PST_ARRAY_COUNT(allowed_keys); ++index) {
    yyjson_val *value = pst_yyjson_obj_get(selection, allowed_keys[index]);
    if (value == nullptr) {
      continue;
    }
    has_selector = true;
    char item_path[PST_JSON_DIAGNOSTIC_CAPACITY] = {};
    pst_yyjson_child_path(item_path, path, allowed_keys[index]);
    if (!pst_manifest_validate_string_array(
            value, item_path, PSTPermissionManifestValidationInvalidTarget, error)) {
      return false;
    }
  }
  if (!has_selector) {
    return pst_manifest_set_error(
        error, PSTPermissionManifestValidationInvalidTarget, path,
        "must declare at least one of sets, include, or exclude");
  }
  return true;
}

static bool
pst_manifest_validate_defaults(yyjson_val *root,
                               PSTPermissionManifestValidationError *error) {
  static const char *const allowed_keys[] = {
      "required",
      "permissions",
  };
  yyjson_val *defaults = pst_yyjson_obj_get(root, "defaults");
  if (defaults == nullptr) {
    return true;
  }
  static const char path[] = "defaults";
  if (!pst_manifest_validate_object(
          defaults, allowed_keys, PST_ARRAY_COUNT(allowed_keys), path,
          PSTPermissionManifestValidationInvalidTarget, error) ||
      !pst_manifest_optional_boolean(defaults, "required", path,
                                     PSTPermissionManifestValidationInvalidTarget,
                                     error)) {
    return false;
  }
  yyjson_val *permissions = pst_yyjson_obj_get(defaults, "permissions");
  if (permissions == nullptr) {
    return true;
  }
  return pst_manifest_validate_permission_selection(permissions, "defaults/permissions",
                                                    error);
}

static bool pst_manifest_target_field_is_duplicate(yyjson_val *targets, size_t index,
                                                   const char *field,
                                                   yyjson_val *candidate) {
  yyjson_arr_iter iterator = yyjson_arr_iter_with(targets);
  for (size_t previous_index = 0; previous_index < index; ++previous_index) {
    yyjson_val *previous = yyjson_arr_iter_next(&iterator);
    yyjson_val *previous_value = pst_yyjson_obj_get(previous, field);
    if (previous_value != nullptr && yyjson_equals(candidate, previous_value)) {
      return true;
    }
  }
  return false;
}

static bool pst_manifest_validate_target(yyjson_val *targets, yyjson_val *target,
                                         size_t index,
                                         PSTPermissionManifestValidationError *error) {
  static const char *const allowed_keys[] = {
      "id",
      "name",
      "enabled",
      "required",
      "kind",
      "bundleIdentifiers",
      "pathCandidates",
      "permissions",
  };
  char path[PST_JSON_DIAGNOSTIC_CAPACITY] = {};
  pst_yyjson_index_path(path, "targets", index);
  if (!pst_manifest_validate_object(target, allowed_keys, PST_ARRAY_COUNT(allowed_keys),
                                    path, PSTPermissionManifestValidationInvalidTarget,
                                    error)) {
    return false;
  }
  yyjson_val *identifier = pst_manifest_required_string(
      target, "id", path, PSTPermissionManifestValidationInvalidTarget, error);
  yyjson_val *name = pst_manifest_required_string(
      target, "name", path, PSTPermissionManifestValidationInvalidTarget, error);
  if (identifier == nullptr || name == nullptr ||
      !pst_manifest_optional_boolean(target, "enabled", path,
                                     PSTPermissionManifestValidationInvalidTarget,
                                     error) ||
      !pst_manifest_optional_boolean(target, "required", path,
                                     PSTPermissionManifestValidationInvalidTarget,
                                     error) ||
      !pst_manifest_validate_optional_string_array(
          target, "bundleIdentifiers", path,
          PSTPermissionManifestValidationInvalidTarget, error) ||
      !pst_manifest_validate_optional_string_array(
          target, "pathCandidates", path, PSTPermissionManifestValidationInvalidTarget,
          error)) {
    return false;
  }
  if (pst_manifest_target_field_is_duplicate(targets, index, "id", identifier) ||
      pst_manifest_target_field_is_duplicate(targets, index, "name", name)) {
    return pst_manifest_set_error(error, PSTPermissionManifestValidationInvalidTarget,
                                  path, "target identifiers and names must be unique");
  }

  PSTPermissionTargetKind kind = PSTPermissionTargetKindApplicationBundle;
  yyjson_val *kind_value = pst_yyjson_obj_get(target, "kind");
  if (kind_value != nullptr) {
    kind_value = pst_manifest_required_string(
        target, "kind", path, PSTPermissionManifestValidationInvalidTarget, error);
    if (kind_value == nullptr ||
        !pst_permission_target_kind_parse(yyjson_get_str(kind_value), &kind)) {
      return pst_manifest_set_error(error, PSTPermissionManifestValidationInvalidTarget,
                                    path, "kind contains an unsupported value");
    }
  }

  yyjson_val *bundle_identifiers = pst_yyjson_obj_get(target, "bundleIdentifiers");
  yyjson_val *path_candidates = pst_yyjson_obj_get(target, "pathCandidates");
  if (kind == PSTPermissionTargetKindApplicationBundle) {
    if (bundle_identifiers == nullptr && path_candidates == nullptr) {
      return pst_manifest_set_error(
          error, PSTPermissionManifestValidationInvalidTarget, path,
          "application targets require bundle identifiers or path candidates");
    }
  } else if (bundle_identifiers != nullptr || path_candidates == nullptr) {
    return pst_manifest_set_error(
        error, PSTPermissionManifestValidationInvalidTarget, path,
        "executable targets require paths and cannot declare bundle identifiers");
  }

  yyjson_val *permissions = pst_yyjson_obj_get(target, "permissions");
  if (permissions == nullptr) {
    return true;
  }
  char permissions_path[PST_JSON_DIAGNOSTIC_CAPACITY] = {};
  pst_yyjson_child_path(permissions_path, path, "permissions");
  return pst_manifest_validate_permission_selection(permissions, permissions_path,
                                                    error);
}

static bool
pst_manifest_validate_targets_root(yyjson_val *root,
                                   PSTPermissionManifestValidationError *error) {
  static const char *const allowed_keys[] = {
      "$schema",
      "version",
      "defaults",
      "targets",
  };
  if (!pst_manifest_validate_object(
          root, allowed_keys, PST_ARRAY_COUNT(allowed_keys), "<root>",
          PSTPermissionManifestValidationInvalidJSON, error) ||
      !pst_manifest_validate_schema(root, PST_PERMISSION_TARGETS_SCHEMA, error) ||
      !pst_manifest_validate_version(root, error) ||
      !pst_manifest_validate_defaults(root, error)) {
    return false;
  }
  yyjson_val *targets = pst_yyjson_obj_get(root, "targets");
  if (!yyjson_is_arr(targets) || yyjson_arr_size(targets) == 0) {
    return pst_manifest_set_error(error, PSTPermissionManifestValidationInvalidTarget,
                                  "targets", "must be a non-empty array");
  }
  yyjson_arr_iter iterator = yyjson_arr_iter_with(targets);
  yyjson_val *target = nullptr;
  size_t index = 0;
  while ((target = yyjson_arr_iter_next(&iterator)) != nullptr) {
    if (!pst_manifest_validate_target(targets, target, index, error)) {
      return false;
    }
    ++index;
  }
  return true;
}

typedef bool (*PSTManifestRootValidator)(yyjson_val *root,
                                         PSTPermissionManifestValidationError *error);

static bool pst_manifest_validate_data(const void *data, size_t length,
                                       PSTManifestRootValidator validator,
                                       PSTPermissionManifestValidationError *error) {
  if (error != nullptr) {
    *error = (PSTPermissionManifestValidationError){};
  }
  if (data == nullptr || length == 0) {
    return pst_manifest_set_error(error, PSTPermissionManifestValidationInvalidJSON,
                                  "<root>", "invalid JSON: input is empty");
  }
  yyjson_read_err read_error = {};
  yyjson_doc *document = pst_yyjson_read(data, length, &read_error);
  if (document == nullptr) {
    return pst_manifest_set_read_error(error, &read_error);
  }
  const bool valid = validator(yyjson_doc_get_root(document), error);
  yyjson_doc_free(document);
  return valid;
}

bool pst_permission_catalog_validate(const void *data, size_t length,
                                     PSTPermissionManifestValidationError *error) {
  return pst_manifest_validate_data(data, length, pst_manifest_validate_catalog_root,
                                    error);
}

bool pst_permission_targets_validate(const void *data, size_t length,
                                     PSTPermissionManifestValidationError *error) {
  return pst_manifest_validate_data(data, length, pst_manifest_validate_targets_root,
                                    error);
}
