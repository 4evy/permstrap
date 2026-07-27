#include "permissions/PSTPermissionWorkflowCore.h"

#include <assert.h>

typedef struct PSTWorkflowFixture {
  const PSTPermissionWorkflowOperationResult *results;
  size_t callback_count;
} PSTWorkflowFixture;

static PSTPermissionWorkflowOperationResult execute_operation(size_t operation_index,
                                                              void *raw_context) {
  PSTWorkflowFixture *fixture = raw_context;
  ++fixture->callback_count;
  return fixture->results[operation_index];
}

int main(void) {
  const PSTPermissionWorkflowOperationResult success_results[] = {
      PSTPermissionWorkflowOperationSucceeded,
      PSTPermissionWorkflowOperationSucceeded,
  };
  PSTWorkflowFixture fixture = {
      .results = success_results,
  };
  PSTPermissionWorkflowOutcome outcome = {};
  assert(pst_permission_workflow_execute(2, execute_operation, &fixture, &outcome));
  assert(outcome.operation_count == 2);
  assert(outcome.attempted_count == 2);
  assert(outcome.completed_count == 2);
  assert(outcome.failed_count == 0);
  assert(!outcome.stopped_for_safety);
  assert(pst_permission_workflow_succeeded(&outcome));
  assert(fixture.callback_count == 2);

  const PSTPermissionWorkflowOperationResult recoverable_results[] = {
      PSTPermissionWorkflowOperationFailedAndContinue,
      PSTPermissionWorkflowOperationSucceeded,
  };
  fixture = (PSTWorkflowFixture){
      .results = recoverable_results,
  };
  assert(pst_permission_workflow_execute(2, execute_operation, &fixture, &outcome));
  assert(outcome.attempted_count == 2);
  assert(outcome.completed_count == 1);
  assert(outcome.failed_count == 1);
  assert(!outcome.stopped_for_safety);
  assert(!pst_permission_workflow_succeeded(&outcome));
  assert(fixture.callback_count == 2);

  const PSTPermissionWorkflowOperationResult fatal_results[] = {
      PSTPermissionWorkflowOperationSucceeded,
      PSTPermissionWorkflowOperationFailedAndStop,
      PSTPermissionWorkflowOperationSucceeded,
  };
  fixture = (PSTWorkflowFixture){
      .results = fatal_results,
  };
  assert(pst_permission_workflow_execute(3, execute_operation, &fixture, &outcome));
  assert(outcome.operation_count == 3);
  assert(outcome.attempted_count == 2);
  assert(outcome.completed_count == 1);
  assert(outcome.failed_count == 1);
  assert(outcome.stopped_for_safety);
  assert(!pst_permission_workflow_succeeded(&outcome));
  assert(fixture.callback_count == 2);

  assert(pst_permission_workflow_execute(0, nullptr, nullptr, &outcome));
  assert(pst_permission_workflow_succeeded(&outcome));
  assert(!pst_permission_workflow_execute(1, nullptr, nullptr, &outcome));
  assert(!pst_permission_workflow_execute(0, nullptr, nullptr, nullptr));
  assert(!pst_permission_workflow_succeeded(nullptr));
  return 0;
}
