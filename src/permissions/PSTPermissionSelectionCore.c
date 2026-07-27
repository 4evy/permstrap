#include "permissions/PSTPermissionSelectionCore.h"

#define CC_NO_SHORT_NAMES
#include <cc.h>

/*
 * CC's macro-safety warning deliberately emits a division by zero when its
 * container argument is not a compile-time constant. At -O0, Clang does not
 * classify even a plain local pointer as constant and the integer sanitizer
 * executes that warning path. Every call below is isolated in a wrapper whose
 * container argument is a side-effect-free pointer, so disable only that
 * diagnostic mechanism while retaining all container runtime checks.
 */
#undef CC_WARN_DUPLICATE_SIDE_EFFECTS
#define CC_WARN_DUPLICATE_SIDE_EFFECTS(container) ((void)sizeof(container))

#include <stdckdint.h>
#include <stdlib.h>
#include <string.h>

typedef cc_vec(const char *) PSTStringVector;
typedef cc_set(const char *) PSTStringSet;

typedef struct {
  PSTStringVector values;
  PSTStringSet membership;
} PSTOrderedStringSet;

/*
 * CC represents an empty vector with an immutable global placeholder. Its
 * public init/cleanup macros intentionally cast that placeholder to the opaque
 * handle type; isolate Clang's cast-qual diagnostic to those two API calls.
 */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-qual"
static void pst_ordered_string_set_init(PSTOrderedStringSet *set) {
  PSTStringVector *values = &set->values;
  PSTStringSet *membership = &set->membership;
  cc_init(values);
  cc_init(membership);
}

static void pst_ordered_string_set_cleanup(PSTOrderedStringSet *set) {
  PSTStringVector *values = &set->values;
  PSTStringSet *membership = &set->membership;
  cc_cleanup(values);
  cc_cleanup(membership);
}

static void pst_string_set_init(PSTStringSet *set) { cc_init(set); }

static void pst_string_set_cleanup(PSTStringSet *set) { cc_cleanup(set); }
#pragma clang diagnostic pop

static bool pst_selection_set_error(PSTPermissionSelectionError *error,
                                    PSTPermissionSelectionErrorCode code,
                                    size_t selection_index, const char *identifier) {
  if (error != nullptr) {
    *error = (PSTPermissionSelectionError){
        .code = code,
        .selection_index = selection_index,
        .identifier = identifier,
    };
  }
  return false;
}

static bool pst_string_set_contains(PSTStringSet *set, const char *value) {
  return cc_get(set, value) != nullptr;
}

static bool pst_string_set_insert(PSTStringSet *set, const char *value) {
  return cc_insert(set, value) != nullptr;
}

static void pst_string_set_erase(PSTStringSet *set, const char *value) {
  (void)cc_erase(set, value);
}

static bool pst_string_vector_push(PSTStringVector *vector, const char *value) {
  return cc_push(vector, value) != nullptr;
}

static size_t pst_string_vector_size(PSTStringVector *vector) {
  return cc_size(vector);
}

static const char *pst_string_vector_get(PSTStringVector *vector, size_t index) {
  return *cc_get(vector, index);
}

static bool pst_ordered_string_set_append(PSTOrderedStringSet *set, const char *value) {
  PSTStringVector *values = &set->values;
  PSTStringSet *membership = &set->membership;
  if (pst_string_set_contains(&set->membership, value)) {
    return true;
  }
  if (!pst_string_set_insert(membership, value)) {
    return false;
  }
  if (!pst_string_vector_push(values, value)) {
    pst_string_set_erase(membership, value);
    return false;
  }
  return true;
}

static bool pst_ordered_string_set_copy(PSTOrderedStringSet *set, const char ***items,
                                        size_t *count) {
  PSTStringVector *values = &set->values;
  *items = nullptr;
  *count = pst_string_vector_size(values);
  if (*count == 0) {
    return true;
  }
  size_t allocation_size = 0;
  if (ckd_mul(&allocation_size, *count, sizeof(**items))) {
    return false;
  }
  const char **allocation = malloc(allocation_size);
  if (allocation == nullptr) {
    return false;
  }
  for (size_t index = 0; index < *count; ++index) {
    allocation[index] = pst_string_vector_get(values, index);
  }
  *items = allocation;
  return true;
}

static bool pst_string_list_is_valid(const char *const *items, size_t count) {
  if (count > 0 && items == nullptr) {
    return false;
  }
  for (size_t index = 0; index < count; ++index) {
    if (items[index] == nullptr || items[index][0] == '\0') {
      return false;
    }
  }
  return true;
}

static const PSTPermissionSetView *
pst_permission_set_find(const PSTPermissionCatalogView *catalog,
                        const char *identifier) {
  for (size_t index = 0; index < catalog->permission_set_count; ++index) {
    if (strcmp(catalog->permission_sets[index].identifier, identifier) == 0) {
      return &catalog->permission_sets[index];
    }
  }
  return nullptr;
}

static bool pst_catalog_contains_service(const PSTPermissionCatalogView *catalog,
                                         const char *identifier) {
  for (size_t index = 0; index < catalog->service_count; ++index) {
    if (strcmp(catalog->service_identifiers[index], identifier) == 0) {
      return true;
    }
  }
  return false;
}

static bool pst_catalog_is_valid(const PSTPermissionCatalogView *catalog) {
  if (catalog == nullptr ||
      !pst_string_list_is_valid(catalog->service_identifiers, catalog->service_count) ||
      (catalog->permission_set_count > 0 && catalog->permission_sets == nullptr)) {
    return false;
  }
  for (size_t index = 0; index < catalog->permission_set_count; ++index) {
    const PSTPermissionSetView *permission_set = &catalog->permission_sets[index];
    if (permission_set->identifier == nullptr ||
        permission_set->identifier[0] == '\0' ||
        !pst_string_list_is_valid(permission_set->service_identifiers,
                                  permission_set->service_count)) {
      return false;
    }
  }
  return true;
}

static bool pst_selection_is_valid(const PSTPermissionSelectionView *selection) {
  return pst_string_list_is_valid(selection->permission_set_identifiers,
                                  selection->permission_set_count) &&
         pst_string_list_is_valid(selection->included_service_identifiers,
                                  selection->included_service_count) &&
         pst_string_list_is_valid(selection->excluded_service_identifiers,
                                  selection->excluded_service_count);
}

static bool pst_collect_service(const PSTPermissionCatalogView *catalog,
                                PSTOrderedStringSet *services, const char *identifier,
                                size_t selection_index,
                                PSTPermissionSelectionError *error) {
  if (!pst_catalog_contains_service(catalog, identifier)) {
    return pst_selection_set_error(error,
                                   PST_PERMISSION_SELECTION_ERROR_UNKNOWN_SERVICE,
                                   selection_index, identifier);
  }
  if (!pst_ordered_string_set_append(services, identifier)) {
    return pst_selection_set_error(error, PST_PERMISSION_SELECTION_ERROR_OUT_OF_MEMORY,
                                   selection_index, identifier);
  }
  return true;
}

void pst_permission_selection_result_destroy(PSTPermissionSelectionResult *result) {
  if (result == nullptr) {
    return;
  }
  free(result->permission_set_identifiers);
  free(result->service_identifiers);
  *result = (PSTPermissionSelectionResult){};
}

bool pst_permission_selection_resolve(const PSTPermissionCatalogView *catalog,
                                      const PSTPermissionSelectionView *selections,
                                      size_t selection_count,
                                      PSTPermissionSelectionResult *result,
                                      PSTPermissionSelectionError *error) {
  if (result != nullptr) {
    *result = (PSTPermissionSelectionResult){};
  }
  if (error != nullptr) {
    *error = (PSTPermissionSelectionError){};
  }
  if (result == nullptr || selections == nullptr || selection_count == 0 ||
      !pst_catalog_is_valid(catalog)) {
    return pst_selection_set_error(error, PST_PERMISSION_SELECTION_ERROR_INVALID_INPUT,
                                   0, nullptr);
  }

  PSTOrderedStringSet selected_sets;
  PSTOrderedStringSet selected_services;
  PSTStringSet excluded_services;
  PSTOrderedStringSet resolved_services;
  pst_ordered_string_set_init(&selected_sets);
  pst_ordered_string_set_init(&selected_services);
  pst_string_set_init(&excluded_services);
  pst_ordered_string_set_init(&resolved_services);
  for (size_t selection_index = 0; selection_index < selection_count;
       ++selection_index) {
    const PSTPermissionSelectionView *selection = &selections[selection_index];
    if (!pst_selection_is_valid(selection)) {
      (void)pst_selection_set_error(error, PST_PERMISSION_SELECTION_ERROR_INVALID_INPUT,
                                    selection_index, nullptr);
      goto failure;
    }

    for (size_t set_index = 0; set_index < selection->permission_set_count;
         ++set_index) {
      const char *identifier = selection->permission_set_identifiers[set_index];
      const PSTPermissionSetView *permission_set =
          pst_permission_set_find(catalog, identifier);
      if (permission_set == nullptr) {
        (void)pst_selection_set_error(
            error, PST_PERMISSION_SELECTION_ERROR_UNKNOWN_PERMISSION_SET,
            selection_index, identifier);
        goto failure;
      }
      if (!pst_ordered_string_set_append(&selected_sets, identifier)) {
        (void)pst_selection_set_error(error,
                                      PST_PERMISSION_SELECTION_ERROR_OUT_OF_MEMORY,
                                      selection_index, identifier);
        goto failure;
      }
      for (size_t service_index = 0; service_index < permission_set->service_count;
           ++service_index) {
        if (!pst_collect_service(catalog, &selected_services,
                                 permission_set->service_identifiers[service_index],
                                 selection_index, error)) {
          goto failure;
        }
      }
    }

    for (size_t service_index = 0; service_index < selection->included_service_count;
         ++service_index) {
      if (!pst_collect_service(catalog, &selected_services,
                               selection->included_service_identifiers[service_index],
                               selection_index, error)) {
        goto failure;
      }
    }
    for (size_t service_index = 0; service_index < selection->excluded_service_count;
         ++service_index) {
      const char *identifier = selection->excluded_service_identifiers[service_index];
      if (!pst_catalog_contains_service(catalog, identifier)) {
        (void)pst_selection_set_error(error,
                                      PST_PERMISSION_SELECTION_ERROR_UNKNOWN_SERVICE,
                                      selection_index, identifier);
        goto failure;
      }
      if (!pst_string_set_insert(&excluded_services, identifier)) {
        (void)pst_selection_set_error(error,
                                      PST_PERMISSION_SELECTION_ERROR_OUT_OF_MEMORY,
                                      selection_index, identifier);
        goto failure;
      }
    }
  }

  for (size_t index = 0; index < pst_string_vector_size(&selected_services.values);
       ++index) {
    const char *identifier = pst_string_vector_get(&selected_services.values, index);
    if (!pst_string_set_contains(&excluded_services, identifier) &&
        !pst_ordered_string_set_append(&resolved_services, identifier)) {
      (void)pst_selection_set_error(error, PST_PERMISSION_SELECTION_ERROR_OUT_OF_MEMORY,
                                    0, identifier);
      goto failure;
    }
  }
  if (pst_string_vector_size(&resolved_services.values) == 0) {
    (void)pst_selection_set_error(error, PST_PERMISSION_SELECTION_ERROR_EMPTY_RESULT, 0,
                                  nullptr);
    goto failure;
  }

  if (!pst_ordered_string_set_copy(&selected_sets, &result->permission_set_identifiers,
                                   &result->permission_set_count) ||
      !pst_ordered_string_set_copy(&resolved_services, &result->service_identifiers,
                                   &result->service_count)) {
    free(result->permission_set_identifiers);
    *result = (PSTPermissionSelectionResult){};
    (void)pst_selection_set_error(error, PST_PERMISSION_SELECTION_ERROR_OUT_OF_MEMORY,
                                  0, nullptr);
    goto failure;
  }
  pst_ordered_string_set_cleanup(&selected_sets);
  pst_ordered_string_set_cleanup(&selected_services);
  pst_string_set_cleanup(&excluded_services);
  pst_ordered_string_set_cleanup(&resolved_services);
  return true;

failure:
  pst_ordered_string_set_cleanup(&selected_sets);
  pst_ordered_string_set_cleanup(&selected_services);
  pst_string_set_cleanup(&excluded_services);
  pst_ordered_string_set_cleanup(&resolved_services);
  return false;
}
