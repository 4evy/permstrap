automation_test_sources = files(
    'test_automatic_file_drag.m',
    'test_ax_utilities.c',
    'test_system_settings_control.c',
    'test_system_settings_types.c',
)
test_sources += automation_test_sources

system_settings_types_test = executable(
    'test-system-settings-types',
    'test_system_settings_types.c',
    dependencies: portable_core_dep,
)
test_targets += system_settings_types_test
test('system-settings-types', system_settings_types_test, suite: 'unit')

automatic_file_drag_test = executable(
    'test-automatic-file-drag',
    'test_automatic_file_drag.m',
    files('../../src/automation/PSTAutomaticFileDrag.m'),
    dependencies: app_frameworks,
    include_directories: source_include,
)
test_targets += automatic_file_drag_test
test(
    'automatic-file-drag',
    automatic_file_drag_test,
    suite: 'unit',
)

ax_utilities_test = executable(
    'test-ax-utilities',
    'test_ax_utilities.c',
    ax_utility_sources,
    dependencies: app_frameworks,
    include_directories: source_include,
)
test_targets += ax_utilities_test
test('ax-utilities', ax_utilities_test, suite: 'unit')

system_settings_control_test = executable(
    'test-system-settings-control',
    'test_system_settings_control.c',
    system_settings_control_sources,
    ax_utility_sources,
    dependencies: app_frameworks,
    include_directories: source_include,
)
test_targets += system_settings_control_test
test(
    'system-settings-control',
    system_settings_control_test,
    suite: 'unit',
)
