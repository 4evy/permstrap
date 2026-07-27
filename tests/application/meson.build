application_test_sources = files(
    'test_application_model.c',
    'test_command_line.c',
    'test_configuration_windows.m',
    'test_permission_confirmation_controller.m',
    'test_permission_targets_document.m',
)
test_sources += application_test_sources

application_unit_test_sources = {
    'application-model': 'test_application_model.c',
    'command-line': 'test_command_line.c',
}
foreach unit_test_name, unit_test_source : application_unit_test_sources
    unit_test_executable = executable(
        'test-' + unit_test_name,
        unit_test_source,
        dependencies: application_core_dep,
    )
    test_targets += unit_test_executable
    test(unit_test_name, unit_test_executable, suite: 'unit')
endforeach

permission_confirmation_controller_test = executable(
    'test-permission-confirmation-controller',
    'test_permission_confirmation_controller.m',
    permission_confirmation_source,
    ui_components_source,
    dependencies: [appkit_framework, permission_model_dep],
)
test_targets += permission_confirmation_controller_test
test(
    'permission-confirmation-controller',
    permission_confirmation_controller_test,
    args: [permission_manifest, permission_targets_example],
    suite: 'unit',
)

permission_targets_document_test = executable(
    'test-permission-targets-document',
    'test_permission_targets_document.m',
    permission_targets_document_source,
    dependencies: permission_model_dep,
)
test_targets += permission_targets_document_test
test(
    'permission-targets-document',
    permission_targets_document_test,
    args: [permission_manifest],
    suite: 'unit',
)

configuration_windows_test = executable(
    'test-configuration-windows',
    'test_configuration_windows.m',
    permission_targets_document_source,
    permission_targets_editor_source,
    about_window_source,
    ui_components_source,
    dependencies: [appkit_framework, permission_model_dep],
)
test_targets += configuration_windows_test
test(
    'configuration-windows',
    configuration_windows_test,
    args: [permission_manifest, permission_targets_example],
    suite: 'unit',
)
