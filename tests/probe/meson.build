probe_test_sources = files('test_probe_command_line.c')
test_sources += probe_test_sources

probe_command_line_test = executable(
    'test-probe-command-line',
    'test_probe_command_line.c',
    dependencies: probe_core_dep,
)
test_targets += probe_command_line_test
test('probe-command-line', probe_command_line_test, suite: 'unit')
