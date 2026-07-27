automatic_drag_preview_source = files('PSTAutomaticDragPreview.m')
automatic_drag_preview = executable(
    'permstrap-automatic-drag-preview',
    automatic_drag_preview_source,
    files('../src/automation/PSTAutomaticFileDrag.m'),
    build_by_default: false,
    dependencies: app_frameworks,
    include_directories: source_include,
)
run_target('automatic-drag-preview', command: automatic_drag_preview)

format_sources = (
    native_format_sources
    + test_sources
    + automatic_drag_preview_source
)
shell_scripts = files(
    'check-objective-c-boundaries.sh',
    'release.sh',
)
meson_program = find_program('meson', required: true)
bash = find_program('/bin/bash', required: true)
test(
    'objective-c-boundary',
    bash,
    args: [
        files('check-objective-c-boundaries.sh'),
        meson.project_source_root(),
        files('ObjectiveCBoundaries.txt'),
    ],
    suite: 'static',
)
shellcheck = find_program('shellcheck', required: developer_checks)
if shellcheck.found() and not developer_checks.disabled()
    test(
        'shellcheck',
        shellcheck,
        args: ['--shell=bash'] + shell_scripts,
        suite: 'static',
    )
endif
shfmt = find_program('shfmt', required: developer_checks)
if shfmt.found()
    if not developer_checks.disabled()
        test(
            'shfmt',
            shfmt,
            args: [
                '--diff',
                '--language-dialect',
                'bash',
            ] + shell_scripts,
            suite: 'static',
        )
    endif
    run_target(
        'format-shell',
        command: [
            shfmt,
            '--write',
            '--language-dialect',
            'bash',
        ] + shell_scripts,
    )
endif
clang_format = find_program(
    '/opt/homebrew/opt/llvm/bin/clang-format',
    'clang-format',
    required: false,
)
if not clang_format.found()
    clang_format_probe = run_command(xcrun, '--find', 'clang-format', check: false)
    if clang_format_probe.returncode() == 0
        clang_format = find_program(
            clang_format_probe.stdout().strip(),
            required: true,
        )
    endif
endif
if clang_format.found()
    if not developer_checks.disabled()
        test(
            'clang-format',
            clang_format,
            args: ['--dry-run', '--Werror'] + format_sources,
            suite: 'static',
        )
    endif
    run_target(
        'format',
        command: [clang_format, '-i'] + format_sources,
    )
elif developer_checks.enabled()
    error('developer_checks requires clang-format')
endif

static_analyzer = find_program(
    '/opt/homebrew/opt/llvm/bin/clang',
    'clang',
    required: developer_checks,
)
if static_analyzer.found() and not developer_checks.disabled()
    static_analysis_args = [
        '--analyze',
        '-std=c23',
        '-pedantic-errors',
        '-Werror',
        '-fno-color-diagnostics',
        '-isysroot',
        sdk_path,
        '-mmacosx-version-min=' + minimum_macos_version,
        '-I',
        meson.project_source_root() / 'src',
        '-I',
        meson.project_build_root(),
        '-I',
        argtable3_include_directory,
        '-I',
        yyjson_include_directory,
        '-isystem',
        cc_include_directory,
        '-I',
        utf8proc_include_directory,
        '-I',
        libsodium_include_directory,
        '-Xanalyzer',
        '-analyzer-output=text',
        '-Xanalyzer',
        '-analyzer-checker=core,deadcode,security,unix,osx,nullability,'
        + 'optin.performance,optin.portability',
    ]
    test(
        'static-analysis-c',
        static_analyzer,
        args: static_analysis_args + c_sources,
        suite: 'static',
        timeout: 300,
    )
    test(
        'static-analysis-objc',
        static_analyzer,
        args: static_analysis_args
        + [
            '-x',
            'objective-c',
            '-fblocks',
            '-fmodules',
            '-fobjc-arc',
        ]
        + objc_sources
        + probe_objc_sources,
        suite: 'static',
        timeout: 300,
    )
endif

run_target(
    'verify',
    command: [
        meson_program,
        'test',
        '--no-rebuild',
        '--print-errorlogs',
        '-C',
        meson.project_build_root(),
    ],
    depends: [app_bundle_signature, probe_executable] + test_targets,
)
