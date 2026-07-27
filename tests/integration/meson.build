application_cli_cases = {
    'command-line-help': ['--help', '--unknown-is-ignored'],
    'command-line-version': ['--version'],
}
foreach test_name, test_arguments : application_cli_cases
    test(
        test_name,
        app_executable,
        args: test_arguments,
        suite: 'integration',
    )
endforeach

application_cli_rejections = {
    'conflicting-actions': [
        '--password',
        'not-a-real-password',
        '--self-check',
    ],
    'duplicate-option': ['--runtime-policy=one', '--runtime-policy=two'],
    'invalid-pid': ['--dump-ax=not-a-pid'],
    'missing-password': ['--password'],
    'missing-runtime-policy': [
        '--runtime-policy=@0@'.format(
            meson.project_build_root() / 'missing-runtime-policy.json',
        ),
    ],
    'option-terminator-operand': ['--', '--help'],
    'password-stdin': ['--password-stdin'],
    'trailing-argument': [
        '--password',
        'not-a-real-password',
        'unexpected',
    ],
}
foreach rejection_name, test_arguments : application_cli_rejections
    test(
        'command-line-reject-' + rejection_name,
        app_executable,
        args: test_arguments,
        expected_exitcode: 1,
        suite: 'integration',
    )
endforeach

permission_probe_cases = {
    'permission-probe': ['--stdout'],
    'permission-probe-help': ['--help', '--unknown-is-ignored'],
    'permission-probe-version': ['--version'],
}
foreach test_name, test_arguments : permission_probe_cases
    test(
        test_name,
        probe_executable,
        args: test_arguments,
        suite: 'integration',
    )
endforeach
test(
    'permission-probe-reject-relative-path',
    probe_executable,
    args: '--status-json=relative.json',
    expected_exitcode: 1,
    suite: 'integration',
)

test(
    'application-bundle-signature',
    codesign,
    args: ['--verify', '--deep', '--strict', app_bundle_path],
    depends: app_bundle_signature,
    suite: 'integration',
)
test(
    'application-bundle-self-check',
    bundle_app_executable,
    args: '--self-check',
    depends: app_bundle_signature,
    suite: 'integration',
)
test(
    'application-bundle-target-self-check',
    bundle_app_executable,
    args: ['--self-check', '--targets', permission_targets_example],
    depends: app_bundle_signature,
    suite: 'integration',
)
