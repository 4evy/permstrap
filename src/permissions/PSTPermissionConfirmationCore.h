#ifndef PST_PERMISSION_CONFIRMATION_CORE_H
#define PST_PERMISSION_CONFIRMATION_CORE_H

#include "core/PSTC23.h"

#include <stddef.h>

typedef const void *PSTPermissionConfirmationHandle;

typedef struct PSTPermissionConfirmationDataSource {
  size_t (*target_count)(void *context);
  PSTPermissionConfirmationHandle (*target_at)(size_t index, void *context);
  size_t (*target_service_count)(PSTPermissionConfirmationHandle target, void *context);
  PSTPermissionConfirmationHandle (*target_service_at)(
      PSTPermissionConfirmationHandle target, size_t index, void *context);
  size_t (*service_count)(void *context);
  PSTPermissionConfirmationHandle (*service_at)(size_t index, void *context);
  bool (*handles_equal)(PSTPermissionConfirmationHandle lhs,
                        PSTPermissionConfirmationHandle rhs, void *context);
} PSTPermissionConfirmationDataSource;

typedef struct PSTPermissionConfirmationGroupSink {
  void (*begin_group)(PSTPermissionConfirmationHandle representative_target,
                      size_t target_count, void *context);
  void (*emit_target)(PSTPermissionConfirmationHandle target, void *context);
  void (*end_group)(void *context);
} PSTPermissionConfirmationGroupSink;

[[nodiscard]] bool pst_permission_confirmation_targets_are_uniform(
    const PSTPermissionConfirmationDataSource *source, void *source_context);

[[nodiscard]] bool pst_permission_confirmation_service_is_used(
    const PSTPermissionConfirmationDataSource *source, void *source_context,
    PSTPermissionConfirmationHandle service);

[[nodiscard]] bool pst_permission_confirmation_enumerate_groups(
    const PSTPermissionConfirmationDataSource *source, void *source_context,
    const PSTPermissionConfirmationGroupSink *sink, void *sink_context);

#endif
