#include "permissions/PSTPermissionSelectionCore.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

static bool strings_equal(const char *const *actual, const char *const *expected,
                          size_t count) {
  for (size_t index = 0; index < count; ++index) {
    if (strcmp(actual[index], expected[index]) != 0) {
      return false;
    }
  }
  return true;
}

static void test_growing_collections_preserve_order(void) {
  constexpr size_t service_count = 48;
  constexpr size_t excluded_count = 10;
  char service_storage[service_count][32] = {};
  char excluded_storage[excluded_count][32] = {};
  char duplicate_service[32] = {};
  const char *services[service_count] = {};
  const char *excluded_services[excluded_count] = {};
  for (size_t index = 0; index < service_count; ++index) {
    const int written = snprintf(service_storage[index], sizeof service_storage[index],
                                 "generated-service-%zu", index);
    assert(written > 0);
    assert((size_t)written < sizeof service_storage[index]);
    services[index] = service_storage[index];
  }
  for (size_t index = 0; index < excluded_count; ++index) {
    const int written =
        snprintf(excluded_storage[index], sizeof excluded_storage[index], "%s",
                 services[index * 5]);
    assert(written > 0);
    assert((size_t)written < sizeof excluded_storage[index]);
    excluded_services[index] = excluded_storage[index];
  }
  const int duplicate_written =
      snprintf(duplicate_service, sizeof duplicate_service, "%s", services[1]);
  assert(duplicate_written > 0);
  assert((size_t)duplicate_written < sizeof duplicate_service);

  const PSTPermissionSetView permission_set = {
      .identifier = "generated",
      .service_identifiers = services,
      .service_count = service_count,
  };
  const PSTPermissionCatalogView catalog = {
      .service_identifiers = services,
      .service_count = service_count,
      .permission_sets = &permission_set,
      .permission_set_count = 1,
  };
  const char *permission_sets[] = {"generated", "generated"};
  const char *included_services[] = {
      duplicate_service,
      services[2],
      services[1],
  };
  const PSTPermissionSelectionView selection = {
      .permission_set_identifiers = permission_sets,
      .permission_set_count = sizeof permission_sets / sizeof *permission_sets,
      .included_service_identifiers = included_services,
      .included_service_count = sizeof included_services / sizeof *included_services,
      .excluded_service_identifiers = excluded_services,
      .excluded_service_count = excluded_count,
  };

  PSTPermissionSelectionResult result = {};
  PSTPermissionSelectionError error = {};
  assert(pst_permission_selection_resolve(&catalog, &selection, 1, &result, &error));
  assert(result.permission_set_count == 1);
  assert(strcmp(result.permission_set_identifiers[0], "generated") == 0);
  assert(result.service_count == service_count - excluded_count);

  size_t result_index = 0;
  for (size_t service_index = 0; service_index < service_count; ++service_index) {
    if (service_index % 5 == 0) {
      continue;
    }
    assert(strcmp(result.service_identifiers[result_index], services[service_index]) ==
           0);
    ++result_index;
  }
  assert(result_index == result.service_count);
  pst_permission_selection_result_destroy(&result);
}

int main(void) {
  const char *services[] = {
      "accessibility",
      "screen-recording",
      "automation",
  };
  const char *desktop_services[] = {
      "accessibility",
      "automation",
  };
  const PSTPermissionSetView sets[] = {
      {
          .identifier = "desktop",
          .service_identifiers = desktop_services,
          .service_count = sizeof desktop_services / sizeof *desktop_services,
      },
  };
  const PSTPermissionCatalogView catalog = {
      .service_identifiers = services,
      .service_count = sizeof services / sizeof *services,
      .permission_sets = sets,
      .permission_set_count = sizeof sets / sizeof *sets,
  };

  const char *default_sets[] = {"desktop"};
  const char *target_includes[] = {"screen-recording", "automation"};
  const char *target_excludes[] = {"automation"};
  const PSTPermissionSelectionView selections[] = {
      {
          .permission_set_identifiers = default_sets,
          .permission_set_count = sizeof default_sets / sizeof *default_sets,
      },
      {
          .included_service_identifiers = target_includes,
          .included_service_count = sizeof target_includes / sizeof *target_includes,
          .excluded_service_identifiers = target_excludes,
          .excluded_service_count = sizeof target_excludes / sizeof *target_excludes,
      },
  };

  PSTPermissionSelectionResult result = {};
  PSTPermissionSelectionError error = {};
  assert(pst_permission_selection_resolve(
      &catalog, selections, sizeof selections / sizeof *selections, &result, &error));
  const char *expected_sets[] = {"desktop"};
  const char *expected_services[] = {
      "accessibility",
      "screen-recording",
  };
  assert(result.permission_set_count == 1);
  assert(strings_equal(result.permission_set_identifiers, expected_sets,
                       sizeof expected_sets / sizeof *expected_sets));
  assert(result.service_count == 2);
  assert(strings_equal(result.service_identifiers, expected_services,
                       sizeof expected_services / sizeof *expected_services));
  pst_permission_selection_result_destroy(&result);

  const char *unknown_set[] = {"missing"};
  const PSTPermissionSelectionView unknown_set_selection = {
      .permission_set_identifiers = unknown_set,
      .permission_set_count = 1,
  };
  assert(!pst_permission_selection_resolve(&catalog, &unknown_set_selection, 1, &result,
                                           &error));
  assert(error.code == PST_PERMISSION_SELECTION_ERROR_UNKNOWN_PERMISSION_SET);
  assert(strcmp(error.identifier, "missing") == 0);

  const char *unknown_service[] = {"missing"};
  const PSTPermissionSelectionView unknown_service_selection = {
      .included_service_identifiers = unknown_service,
      .included_service_count = 1,
  };
  assert(!pst_permission_selection_resolve(&catalog, &unknown_service_selection, 1,
                                           &result, &error));
  assert(error.code == PST_PERMISSION_SELECTION_ERROR_UNKNOWN_SERVICE);

  const char *only_accessibility[] = {"accessibility"};
  const PSTPermissionSelectionView empty_selection = {
      .included_service_identifiers = only_accessibility,
      .included_service_count = 1,
      .excluded_service_identifiers = only_accessibility,
      .excluded_service_count = 1,
  };
  assert(!pst_permission_selection_resolve(&catalog, &empty_selection, 1, &result,
                                           &error));
  assert(error.code == PST_PERMISSION_SELECTION_ERROR_EMPTY_RESULT);

  assert(!pst_permission_selection_resolve(nullptr, selections, 2, &result, &error));
  assert(error.code == PST_PERMISSION_SELECTION_ERROR_INVALID_INPUT);
  pst_permission_selection_result_destroy(&result);

  test_growing_collections_preserve_order();
  return 0;
}
