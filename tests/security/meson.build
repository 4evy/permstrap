security_test_sources = files(
    'test_credential_validator.c',
    'test_secure_buffer.c',
    'test_trusted_process.m',
    'test_trusted_process_validation.c',
)
test_sources += security_test_sources

security_unit_test_sources = {
    'credential-validator': 'test_credential_validator.c',
    'secure-buffer': 'test_secure_buffer.c',
    'trusted-process-validation': 'test_trusted_process_validation.c',
}
foreach unit_test_name, unit_test_source : security_unit_test_sources
    unit_test_executable = executable(
        'test-' + unit_test_name,
        unit_test_source,
        dependencies: security_core_dep,
    )
    test_targets += unit_test_executable
    test(unit_test_name, unit_test_executable, suite: 'unit')
endforeach

trusted_process_test = executable(
    'test-trusted-process',
    'test_trusted_process.m',
    security_objc_sources,
    dependencies: [
        trusted_process_frameworks,
        portable_core_dep,
        runtime_policy_dep,
        security_core_dep,
    ],
    include_directories: source_include,
)
test_targets += trusted_process_test
test(
    'trusted-process',
    trusted_process_test,
    args: runtime_policy,
    suite: 'unit',
)
