#include "permissions/PSTPermissionConfirmationCore.h"

static bool pst_source_is_valid(const PSTPermissionConfirmationDataSource *source) {
  return source != nullptr && source->target_count != nullptr &&
         source->target_at != nullptr && source->target_service_count != nullptr &&
         source->target_service_at != nullptr && source->service_count != nullptr &&
         source->service_at != nullptr && source->handles_equal != nullptr;
}

static bool pst_target_services_equal(const PSTPermissionConfirmationDataSource *source,
                                      void *context,
                                      PSTPermissionConfirmationHandle lhs,
                                      PSTPermissionConfirmationHandle rhs) {
  const size_t service_count = source->target_service_count(lhs, context);
  if (service_count != source->target_service_count(rhs, context)) {
    return false;
  }
  for (size_t index = 0; index < service_count; ++index) {
    PSTPermissionConfirmationHandle lhs_service =
        source->target_service_at(lhs, index, context);
    PSTPermissionConfirmationHandle rhs_service =
        source->target_service_at(rhs, index, context);
    if (!source->handles_equal(lhs_service, rhs_service, context)) {
      return false;
    }
  }
  return true;
}

bool pst_permission_confirmation_targets_are_uniform(
    const PSTPermissionConfirmationDataSource *source, void *source_context) {
  if (!pst_source_is_valid(source)) {
    return false;
  }
  const size_t target_count = source->target_count(source_context);
  if (target_count < 2) {
    return true;
  }
  PSTPermissionConfirmationHandle first = source->target_at(0, source_context);
  for (size_t index = 1; index < target_count; ++index) {
    if (!pst_target_services_equal(source, source_context, first,
                                   source->target_at(index, source_context))) {
      return false;
    }
  }
  return true;
}

bool pst_permission_confirmation_service_is_used(
    const PSTPermissionConfirmationDataSource *source, void *source_context,
    PSTPermissionConfirmationHandle service) {
  if (!pst_source_is_valid(source) || service == nullptr) {
    return false;
  }
  const size_t target_count = source->target_count(source_context);
  for (size_t target_index = 0; target_index < target_count; ++target_index) {
    PSTPermissionConfirmationHandle target =
        source->target_at(target_index, source_context);
    const size_t service_count = source->target_service_count(target, source_context);
    for (size_t service_index = 0; service_index < service_count; ++service_index) {
      if (source->handles_equal(
              source->target_service_at(target, service_index, source_context), service,
              source_context)) {
        return true;
      }
    }
  }
  return false;
}

bool pst_permission_confirmation_enumerate_groups(
    const PSTPermissionConfirmationDataSource *source, void *source_context,
    const PSTPermissionConfirmationGroupSink *sink, void *sink_context) {
  if (!pst_source_is_valid(source) || sink == nullptr || sink->begin_group == nullptr ||
      sink->emit_target == nullptr || sink->end_group == nullptr) {
    return false;
  }
  const size_t target_count = source->target_count(source_context);
  for (size_t representative_index = 0; representative_index < target_count;
       ++representative_index) {
    PSTPermissionConfirmationHandle representative =
        source->target_at(representative_index, source_context);
    bool already_emitted = false;
    for (size_t previous_index = 0; previous_index < representative_index;
         ++previous_index) {
      if (pst_target_services_equal(
              source, source_context, representative,
              source->target_at(previous_index, source_context))) {
        already_emitted = true;
        break;
      }
    }
    if (already_emitted) {
      continue;
    }

    size_t group_target_count = 0;
    for (size_t index = representative_index; index < target_count; ++index) {
      if (pst_target_services_equal(source, source_context, representative,
                                    source->target_at(index, source_context))) {
        ++group_target_count;
      }
    }
    sink->begin_group(representative, group_target_count, sink_context);
    for (size_t index = representative_index; index < target_count; ++index) {
      PSTPermissionConfirmationHandle target = source->target_at(index, source_context);
      if (pst_target_services_equal(source, source_context, representative, target)) {
        sink->emit_target(target, sink_context);
      }
    }
    sink->end_group(sink_context);
  }
  return true;
}
