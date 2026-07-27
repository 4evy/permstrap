#include "permissions/PSTPermissionConfirmationCore.h"

#include <assert.h>
#include <stdint.h>

typedef struct Target {
  const uintptr_t *services;
  size_t service_count;
} Target;

typedef struct Fixture {
  const Target *targets;
  size_t target_count;
  const uintptr_t *services;
  size_t service_count;
} Fixture;

typedef struct SinkState {
  size_t group_count;
  size_t target_count;
  size_t current_expected_count;
  size_t current_emitted_count;
} SinkState;

static size_t target_count(void *context) { return ((Fixture *)context)->target_count; }

static PSTPermissionConfirmationHandle target_at(size_t index, void *context) {
  return &((Fixture *)context)->targets[index];
}

static size_t target_service_count(PSTPermissionConfirmationHandle handle,
                                   void *context) {
  (void)context;
  return ((const Target *)handle)->service_count;
}

static PSTPermissionConfirmationHandle
target_service_at(PSTPermissionConfirmationHandle handle, size_t index, void *context) {
  (void)context;
  return (const void *)((const Target *)handle)->services[index];
}

static size_t service_count(void *context) {
  return ((Fixture *)context)->service_count;
}

static PSTPermissionConfirmationHandle service_at(size_t index, void *context) {
  return (const void *)((Fixture *)context)->services[index];
}

static bool handles_equal(PSTPermissionConfirmationHandle lhs,
                          PSTPermissionConfirmationHandle rhs, void *context) {
  (void)context;
  return lhs == rhs;
}

static void begin_group(PSTPermissionConfirmationHandle representative, size_t count,
                        void *context) {
  assert(representative != nullptr);
  SinkState *state = context;
  ++state->group_count;
  state->current_expected_count = count;
  state->current_emitted_count = 0;
}

static void emit_target(PSTPermissionConfirmationHandle target, void *context) {
  assert(target != nullptr);
  SinkState *state = context;
  ++state->target_count;
  ++state->current_emitted_count;
}

static void end_group(void *context) {
  SinkState *state = context;
  assert(state->current_emitted_count == state->current_expected_count);
}

int main(void) {
  static const uintptr_t all_services[] = {1, 2, 3};
  static const uintptr_t first_services[] = {1, 2};
  static const uintptr_t second_services[] = {1, 2};
  static const uintptr_t third_services[] = {3};
  static const Target targets[] = {
      {first_services, 2},
      {second_services, 2},
      {third_services, 1},
  };
  Fixture fixture = {
      .targets = targets,
      .target_count = 3,
      .services = all_services,
      .service_count = 3,
  };
  const PSTPermissionConfirmationDataSource source = {
      .target_count = target_count,
      .target_at = target_at,
      .target_service_count = target_service_count,
      .target_service_at = target_service_at,
      .service_count = service_count,
      .service_at = service_at,
      .handles_equal = handles_equal,
  };
  assert(!pst_permission_confirmation_targets_are_uniform(&source, &fixture));
  assert(pst_permission_confirmation_service_is_used(&source, &fixture,
                                                     (const void *)all_services[0]));
  assert(!pst_permission_confirmation_service_is_used(&source, &fixture,
                                                      (const void *)(uintptr_t)4));

  SinkState state = {};
  const PSTPermissionConfirmationGroupSink sink = {
      .begin_group = begin_group,
      .emit_target = emit_target,
      .end_group = end_group,
  };
  assert(
      pst_permission_confirmation_enumerate_groups(&source, &fixture, &sink, &state));
  assert(state.group_count == 2);
  assert(state.target_count == 3);

  fixture.target_count = 2;
  assert(pst_permission_confirmation_targets_are_uniform(&source, &fixture));
  fixture.target_count = 0;
  assert(pst_permission_confirmation_targets_are_uniform(&source, &fixture));
  return 0;
}
