authorization_test_sources = files(
    'test_authorization_injection_types.c',
    'test_authorization_platform.c',
    'test_authorization_readiness.c',
)
test_sources += authorization_test_sources

authorization_injection_types_test = executable(
    'test-authorization-injection-types',
    'test_authorization_injection_types.c',
    dependencies: portable_core_dep,
)
test_targets += authorization_injection_types_test
test(
    'authorization-injection-types',
    authorization_injection_types_test,
    suite: 'unit',
)

authorization_readiness_test = executable(
    'test-authorization-readiness',
    'test_authorization_readiness.c',
    authorization_readiness_sources,
    platform_core_sources,
    dependencies: [foundation_framework, portable_core_dep],
    include_directories: source_include,
)
test_targets += authorization_readiness_test
test('authorization-readiness', authorization_readiness_test, suite: 'unit')

authorization_platform_test = executable(
    'test-authorization-platform',
    'test_authorization_platform.c',
    authorization_platform_sources,
    authorization_readiness_sources,
    platform_core_sources,
    ax_utility_sources,
    dependencies: [app_frameworks, security_core_dep, portable_core_dep],
    include_directories: source_include,
)
test_targets += authorization_platform_test
test(
    'authorization-platform',
    authorization_platform_test,
    suite: 'unit',
)
