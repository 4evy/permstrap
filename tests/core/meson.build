core_test_sources = files(
    'test_platform_poll.c',
    'test_poll.c',
    'test_text_match.c',
)
test_sources += core_test_sources

core_unit_test_sources = {
    'poll': 'test_poll.c',
    'text-match': 'test_text_match.c',
}
foreach unit_test_name, unit_test_source : core_unit_test_sources
    unit_test_executable = executable(
        'test-' + unit_test_name,
        unit_test_source,
        dependencies: portable_core_dep,
    )
    test_targets += unit_test_executable
    test(unit_test_name, unit_test_executable, suite: 'unit')
endforeach

platform_poll_test = executable(
    'test-platform-poll',
    'test_platform_poll.c',
    platform_core_sources,
    include_directories: source_include,
)
test_targets += platform_poll_test
test('platform-poll', platform_poll_test, suite: 'unit')
