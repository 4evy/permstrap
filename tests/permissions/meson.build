permissions_test_sources = files(
    'test_permission_confirmation_core.c',
    'test_permission_manifest.m',
    'test_permission_manifest_validation.c',
    'test_permission_plan.m',
    'test_permission_plan_core.c',
    'test_permission_selection_core.c',
    'test_permission_types.c',
    'test_permission_workflow_core.c',
)
test_sources += permissions_test_sources

permission_unit_test_sources = {
    'permission-confirmation-core': 'test_permission_confirmation_core.c',
    'permission-manifest': 'test_permission_manifest.m',
    'permission-manifest-validation': 'test_permission_manifest_validation.c',
    'permission-plan': 'test_permission_plan.m',
    'permission-plan-core': 'test_permission_plan_core.c',
    'permission-selection-core': 'test_permission_selection_core.c',
    'permission-types': 'test_permission_types.c',
    'permission-workflow-core': 'test_permission_workflow_core.c',
}
permission_unit_test_dependencies = {
    'permission-confirmation-core': portable_core_dep,
    'permission-manifest': permission_model_dep,
    'permission-manifest-validation': permission_manifest_core_dep,
    'permission-plan': permission_model_dep,
    'permission-plan-core': portable_core_dep,
    'permission-selection-core': portable_core_dep,
    'permission-types': portable_core_dep,
    'permission-workflow-core': portable_core_dep,
}
permission_unit_test_arguments = {
    'permission-manifest': [permission_manifest, permission_targets_example],
    'permission-manifest-validation': [
        permission_manifest,
        permission_targets_example,
    ],
    'permission-plan': [permission_manifest, permission_targets_example],
}
foreach unit_test_name, unit_test_source : permission_unit_test_sources
    unit_test_executable = executable(
        'test-' + unit_test_name,
        unit_test_source,
        dependencies: permission_unit_test_dependencies[unit_test_name],
    )
    test_targets += unit_test_executable
    test(
        unit_test_name,
        unit_test_executable,
        args: permission_unit_test_arguments.get(unit_test_name, []),
        suite: 'unit',
    )
endforeach
