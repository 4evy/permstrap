#include "permissions/PSTPermissionPlanCore.h"

#include <assert.h>

typedef struct TestTarget {
  bool path_exists;
  size_t service_count;
  const void *const *services;
} TestTarget;

typedef struct TestContext {
  const TestTarget *targets;
  size_t operation_count;
  size_t missing_count;
} TestContext;

static PSTPermissionPlanHandle target_at(size_t index, void *raw_context) {
  TestContext *context = raw_context;
  return &context->targets[index];
}

static PSTPermissionPlanHandle path_for_target(PSTPermissionPlanHandle raw_target,
                                               void *raw_context) {
  (void)raw_context;
  const TestTarget *target = raw_target;
  return target->path_exists ? target : nullptr;
}

static size_t service_count(PSTPermissionPlanHandle raw_target, void *raw_context) {
  (void)raw_context;
  const TestTarget *target = raw_target;
  return target->service_count;
}

static PSTPermissionPlanHandle service_at(PSTPermissionPlanHandle raw_target,
                                          size_t index, void *raw_context) {
  (void)raw_context;
  const TestTarget *target = raw_target;
  return target->services[index];
}

static void emit_operation(PSTPermissionPlanHandle target,
                           PSTPermissionPlanHandle service,
                           PSTPermissionPlanHandle path, void *raw_context) {
  assert(target != nullptr);
  assert(service != nullptr);
  assert(path != nullptr);
  TestContext *context = raw_context;
  ++context->operation_count;
}

static void emit_missing_target(PSTPermissionPlanHandle target, void *raw_context) {
  assert(target != nullptr);
  TestContext *context = raw_context;
  ++context->missing_count;
}

int main(void) {
  static const int first_service = 1;
  static const int second_service = 2;
  static const void *const valid_services[] = {
      &first_service,
      &second_service,
  };
  static const void *const missing_services[] = {
      &first_service,
      nullptr,
  };
  static const PSTPermissionPlanCallbacks callbacks = {
      .target_at = target_at,
      .path_for_target = path_for_target,
      .service_count = service_count,
      .service_at = service_at,
      .emit_operation = emit_operation,
      .emit_missing_target = emit_missing_target,
  };

  const TestTarget valid_targets[] = {
      {.path_exists = false},
      {
          .path_exists = true,
          .service_count = 2,
          .services = valid_services,
      },
  };
  TestContext context = {
      .targets = valid_targets,
  };
  PSTPermissionPlanBuildError error = {};
  assert(pst_permission_plan_build(2, &callbacks, &context, &error));
  assert(error.code == PSTPermissionPlanBuildErrorNone);
  assert(context.operation_count == 2);
  assert(context.missing_count == 1);

  const TestTarget invalid_targets[] = {
      {
          .path_exists = true,
          .service_count = 2,
          .services = missing_services,
      },
  };
  context = (TestContext){
      .targets = invalid_targets,
  };
  assert(!pst_permission_plan_build(1, &callbacks, &context, &error));
  assert(error.code == PSTPermissionPlanBuildErrorMissingService);
  assert(error.target_index == 0);
  assert(error.service_index == 1);
  assert(context.operation_count == 1);

  assert(!pst_permission_plan_build(0, nullptr, &context, &error));
  assert(error.code == PSTPermissionPlanBuildErrorInvalidCallbacks);
  return 0;
}
