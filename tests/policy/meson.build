policy_test_sources = files(
    'test_declarative_policies.m',
    'test_runtime_policy.m',
    'test_runtime_policy_types.c',
    'test_runtime_policy_validation.c',
)
test_sources += policy_test_sources

runtime_policy_test = executable(
    'test-runtime-policy',
    'test_runtime_policy.m',
    dependencies: runtime_policy_dep,
)
test_targets += runtime_policy_test
test(
    'runtime-policy',
    runtime_policy_test,
    args: runtime_policy,
    suite: 'unit',
)

runtime_policy_types_test = executable(
    'test-runtime-policy-types',
    'test_runtime_policy_types.c',
    dependencies: portable_core_dep,
)
test_targets += runtime_policy_types_test
test('runtime-policy-types', runtime_policy_types_test, suite: 'unit')

runtime_policy_validation_test = executable(
    'test-runtime-policy-validation',
    'test_runtime_policy_validation.c',
    dependencies: runtime_policy_core_dep,
)
test_targets += runtime_policy_validation_test
test(
    'runtime-policy-validation',
    runtime_policy_validation_test,
    args: runtime_policy,
    suite: 'unit',
)

declarative_policies_test = executable(
    'test-declarative-policies',
    'test_declarative_policies.m',
    authorization_prompt_policy_source,
    system_settings_ui_profile_source,
    dependencies: [policy_frameworks, portable_core_dep, runtime_policy_dep],
    include_directories: source_include,
)
test_targets += declarative_policies_test
test(
    'declarative-policies',
    declarative_policies_test,
    args: runtime_policy,
    suite: 'unit',
)
