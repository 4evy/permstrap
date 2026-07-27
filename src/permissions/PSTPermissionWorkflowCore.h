#ifndef PST_PERMISSION_WORKFLOW_CORE_H
#define PST_PERMISSION_WORKFLOW_CORE_H

#include "core/PSTC23.h"

#include <stddef.h>
#include <stdint.h>

typedef enum PSTPermissionWorkflowOperationResult : uint8_t {
  PSTPermissionWorkflowOperationSucceeded,
  PSTPermissionWorkflowOperationFailedAndContinue,
  PSTPermissionWorkflowOperationFailedAndStop,
} PSTPermissionWorkflowOperationResult;

typedef struct PSTPermissionWorkflowOutcome {
  size_t operation_count;
  size_t attempted_count;
  size_t completed_count;
  size_t failed_count;
  bool stopped_for_safety;
} PSTPermissionWorkflowOutcome;

typedef PSTPermissionWorkflowOperationResult (*PSTPermissionWorkflowExecutor)(
    size_t operation_index, void *context);

[[nodiscard("workflow callback validation must be handled")]]
bool pst_permission_workflow_execute(size_t operation_count,
                                     PSTPermissionWorkflowExecutor executor,
                                     void *context,
                                     PSTPermissionWorkflowOutcome *outcome);

[[nodiscard]]
bool pst_permission_workflow_succeeded(const PSTPermissionWorkflowOutcome *outcome);

#endif
