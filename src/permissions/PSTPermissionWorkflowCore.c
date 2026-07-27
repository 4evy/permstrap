#include "permissions/PSTPermissionWorkflowCore.h"

bool pst_permission_workflow_execute(size_t operation_count,
                                     PSTPermissionWorkflowExecutor executor,
                                     void *context,
                                     PSTPermissionWorkflowOutcome *outcome) {
  if (outcome == nullptr || (operation_count > 0 && executor == nullptr)) {
    return false;
  }

  *outcome = (PSTPermissionWorkflowOutcome){
      .operation_count = operation_count,
  };
  for (size_t operation_index = 0; operation_index < operation_count;
       ++operation_index) {
    ++outcome->attempted_count;
    PSTPermissionWorkflowOperationResult result = executor(operation_index, context);
    switch (result) {
    case PSTPermissionWorkflowOperationSucceeded:
      ++outcome->completed_count;
      break;
    case PSTPermissionWorkflowOperationFailedAndContinue:
      ++outcome->failed_count;
      break;
    case PSTPermissionWorkflowOperationFailedAndStop:
      ++outcome->failed_count;
      outcome->stopped_for_safety = true;
      return true;
    }
  }
  return true;
}

bool pst_permission_workflow_succeeded(const PSTPermissionWorkflowOutcome *outcome) {
  return outcome != nullptr && outcome->failed_count == 0 &&
         outcome->attempted_count == outcome->operation_count;
}
