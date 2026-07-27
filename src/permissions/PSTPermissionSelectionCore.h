#ifndef PST_PERMISSION_SELECTION_CORE_H
#define PST_PERMISSION_SELECTION_CORE_H

#include "core/PSTC23.h"

#include <stddef.h>
#include <stdint.h>

typedef struct {
  const char *identifier;
  const char *const *service_identifiers;
  size_t service_count;
} PSTPermissionSetView;

typedef struct {
  const char *const *permission_set_identifiers;
  size_t permission_set_count;
  const char *const *included_service_identifiers;
  size_t included_service_count;
  const char *const *excluded_service_identifiers;
  size_t excluded_service_count;
} PSTPermissionSelectionView;

typedef struct {
  const char *const *service_identifiers;
  size_t service_count;
  const PSTPermissionSetView *permission_sets;
  size_t permission_set_count;
} PSTPermissionCatalogView;

typedef enum PSTPermissionSelectionErrorCode : uint8_t {
  PST_PERMISSION_SELECTION_ERROR_NONE = 0,
  PST_PERMISSION_SELECTION_ERROR_INVALID_INPUT,
  PST_PERMISSION_SELECTION_ERROR_OUT_OF_MEMORY,
  PST_PERMISSION_SELECTION_ERROR_UNKNOWN_PERMISSION_SET,
  PST_PERMISSION_SELECTION_ERROR_UNKNOWN_SERVICE,
  PST_PERMISSION_SELECTION_ERROR_EMPTY_RESULT,
} PSTPermissionSelectionErrorCode;

typedef struct {
  PSTPermissionSelectionErrorCode code;
  size_t selection_index;
  const char *identifier;
} PSTPermissionSelectionError;

typedef struct {
  const char **permission_set_identifiers;
  size_t permission_set_count;
  const char **service_identifiers;
  size_t service_count;
} PSTPermissionSelectionResult;

[[nodiscard]]
bool pst_permission_selection_resolve(const PSTPermissionCatalogView *catalog,
                                      const PSTPermissionSelectionView *selections,
                                      size_t selection_count,
                                      PSTPermissionSelectionResult *result,
                                      PSTPermissionSelectionError *error);

void pst_permission_selection_result_destroy(PSTPermissionSelectionResult *result);

#endif
