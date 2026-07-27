project(
    'permstrap',
    'c',
    'objc',
    version: '1.0.0',
    meson_version: '>=1.11.0',
    default_options: [
        'b_asneeded=true',
        'b_lto=true',
        'b_lto_mode=thin',
        'b_lundef=true',
        'b_ndebug=false',
        'b_pie=true',
        'buildtype=debugoptimized',
        'c_std=c23',
        'warning_level=3',
        'werror=true',
    ],
)

version_configuration = configuration_data()
version_configuration.set_quoted('PST_VERSION', meson.project_version())
configure_file(
    output: 'PSTVersion.h',
    configuration: version_configuration,
)
generated_include = include_directories('.')

if host_machine.system() != 'darwin' or host_machine.cpu_family() != 'aarch64'
    error('permstrap can only be built for aarch64-darwin')
endif

c_compiler = meson.get_compiler('c')
objc_compiler = meson.get_compiler('objc')
if c_compiler.get_id() != 'clang' or objc_compiler.get_id() != 'clang'
    error('permstrap requires Clang')
endif

c23_probe = '''
#if !defined(__STDC_VERSION__) || __STDC_VERSION__ < 202311L
#error compiler does not provide the published ISO C23 language mode
#endif
#include <stddef.h>
#include <stdckdint.h>
typedef enum Probe : unsigned char { probe_value } Probe;
constexpr size_t probe_limit = 1'024;
static_assert(probe_limit == 1024);
[[nodiscard]] int probe(void) {
    auto operand = probe_limit;
    typeof(operand) result = {};
    return ckd_add(&result, operand, 1) || nullptr != nullptr;
}
'''
if not c_compiler.compiles(
    c23_probe,
    args: ['-std=c23', '-pedantic-errors'],
    name: 'published ISO C23 language and library subset',
)
    error('permstrap requires published ISO C23 support')
endif
if not objc_compiler.compiles(
    c23_probe,
    args: ['-std=c23', '-pedantic-errors'],
    name: 'Objective-C compiler using the ISO C23 base language',
)
    error('permstrap requires Objective-C with an ISO C23 base language')
endif

xcrun = find_program('xcrun', required: true)
developer_checks = get_option('developer_checks')
sdk_path = run_command(
    xcrun,
    '--show-sdk-path',
    check: true,
).stdout().strip()

strict_warning_args = [
    '-Walloca',
    '-Warray-bounds-pointer-arithmetic',
    '-Wcomma',
    '-Wconditional-uninitialized',
    '-Wconversion',
    '-Wdate-time',
    '-Wdouble-promotion',
    '-Wextra-semi',
    '-Wformat=2',
    '-Wimplicit-fallthrough',
    '-Wmissing-variable-declarations',
    '-Wnewline-eof',
    '-Wnull-dereference',
    '-Wnullability-completeness',
    '-Wpointer-arith',
    '-Wshadow',
    '-Wshift-sign-overflow',
    '-Wsign-conversion',
    '-Wswitch-enum',
    '-Wthread-safety',
    '-Wundef',
    '-Wunreachable-code-aggressive',
    '-Wunguarded-availability',
]
c_warning_args = [
    '-pedantic-errors',
    '-Wbad-function-cast',
    '-Wcast-align',
    '-Wcast-qual',
    '-Wmissing-prototypes',
    '-Wstrict-prototypes',
    '-Wvla',
    '-Wwrite-strings',
    '-Wzero-as-null-pointer-constant',
]
objc_warning_args = [
    '-Wblock-capture-autoreleasing',
    '-Wimplicit-retain-self',
    '-Wnullable-to-nonnull-conversion',
    '-Wobjc-missing-super-calls',
    '-Wobjc-property-no-attribute',
]
auto_var_init = get_option('buildtype') in ['release', 'minsize'] ? 'zero' : 'pattern'
hardening_args = [
    '-U_FORTIFY_SOURCE',
    '-D_FORTIFY_SOURCE=3',
    '-fno-common',
    '-fstrict-flex-arrays=3',
    '-fstack-protector-strong',
    '-ftrivial-auto-var-init=' + auto_var_init,
    '-fvisibility=hidden',
    '-mbranch-protection=standard',
]
minimum_macos_version = '26.0'
deployment_args = ['-mmacosx-version-min=' + minimum_macos_version]

sanitizer_args = []
sanitizer_selection = get_option('b_sanitize')
if not get_option('werror')
    error('permstrap requires warnings to be treated as errors')
endif
if not get_option('b_pie')
    error('permstrap requires position-independent executables')
endif
if sanitizer_selection == 'none' and not get_option('b_lundef')
    error('permstrap requires undefined symbols to fail the native link')
endif
if sanitizer_selection != 'none'
    sanitizer_args += [
        '-fno-omit-frame-pointer',
        '-fno-optimize-sibling-calls',
        '-fno-sanitize-recover=all',
    ]
endif

add_project_arguments(
    c_compiler.get_supported_arguments(
        deployment_args
        + strict_warning_args
        + c_warning_args
        + hardening_args
        + sanitizer_args,
    ),
    language: 'c',
)
add_project_arguments(
    objc_compiler.get_supported_arguments(
        deployment_args
        + strict_warning_args
        + objc_warning_args
        + hardening_args
        + sanitizer_args
        + [
            '-pedantic-errors',
            '-fmodules',
            '-fobjc-arc',
        ],
    ),
    language: 'objc',
)
add_project_link_arguments(
    deployment_args
    + sanitizer_args
    + [
        '-Wl,-dead_strip',
        '-Wl,-fatal_warnings',
    ],
    language: ['c', 'objc'],
)

subdir('src')
subdir('resources')
subdir('examples')

app_bundle_name = 'Permstrap.app'
app_bundle_contents = app_bundle_name / 'Contents'
app_bundle_macos = app_bundle_contents / 'MacOS'
app_bundle_resources = app_bundle_contents / 'Resources'
app_install_root = 'Applications' / app_bundle_name
app_install_contents = app_install_root / 'Contents'
app_install_macos = app_install_contents / 'MacOS'
app_install_resources = app_install_contents / 'Resources'

app_executable = executable(
    'permstrap',
    app_objc_sources,
    dependencies: [
        app_frameworks,
        portable_core_dep,
        application_core_dep,
        security_core_dep,
        permission_model_dep,
        runtime_policy_dep,
    ],
    include_directories: [source_include, generated_include],
    link_language: 'objc',
    pie: true,
)
copy_file = find_program('/bin/cp', required: true)
bundle_app_executable = custom_target(
    'bundle-application-executable',
    input: app_executable,
    output: 'permstrap',
    command: [copy_file, '@INPUT@', '@OUTPUT@'],
    build_subdir: app_bundle_macos,
    install: true,
    install_dir: app_install_macos,
)

probe_executable = executable(
    'permstrap-probe',
    probe_objc_sources,
    dependencies: [probe_frameworks, probe_core_dep],
    include_directories: [source_include, generated_include],
    install: true,
    pie: true,
)

configure_file(
    input: info_plist,
    output: 'Info.plist',
    build_subdir: app_bundle_contents,
    copy: true,
    install_dir: app_install_contents,
)
bundle_resource_files = {
    'Permissions.json': permission_manifest,
    'Permissions.schema.json': permission_manifest_schema,
    'PermissionTargets.schema.json': permission_targets_schema,
    'RuntimePolicy.json': runtime_policy,
    'RuntimePolicy.schema.json': runtime_policy_schema,
}
foreach bundle_filename, bundle_source : bundle_resource_files
    configure_file(
        input: bundle_source,
        output: bundle_filename,
        build_subdir: app_bundle_resources,
        copy: true,
        install_dir: app_install_resources,
    )
endforeach

app_icon = custom_target(
    'application-icon',
    input: app_icon_sources,
    output: [
        'AppIcon.icns',
        'Assets.car',
        'AppIcon.partial.plist',
    ],
    command: [
        xcrun,
        'actool',
        '--compile', meson.current_build_dir() / app_bundle_resources,
        '--platform', 'macosx',
        '--minimum-deployment-target', minimum_macos_version,
        '--app-icon', 'AppIcon',
        '--output-partial-info-plist', meson.current_build_dir() / app_bundle_resources / 'AppIcon.partial.plist',
        app_icon_document,
    ],
    build_subdir: app_bundle_resources,
    build_by_default: true,
    install: true,
    install_dir: [
        app_install_resources,
        app_install_resources,
        app_install_resources,
    ],
)
codesign = find_program('/usr/bin/codesign', required: true)
app_bundle_path = meson.current_build_dir() / app_bundle_name
app_bundle_signature = custom_target(
    'application-bundle-signature',
    input: [
        bundle_app_executable,
        app_icon[0],
        app_icon[1],
    ],
    output: 'CodeResources',
    command: [
        codesign,
        '--force',
        '--options', 'runtime',
        '--sign',
        '-', app_bundle_path,
    ],
    build_subdir: app_bundle_contents / '_CodeSignature',
    build_always_stale: true,
    build_by_default: true,
    install: true,
    install_dir: app_install_contents / '_CodeSignature',
)

subdir('tests')
subdir('developer')

summary(
    {
        'Application bundle': app_bundle_path,
        'Permission probe': probe_executable.full_path(),
        'C standard': get_option('c_std'),
        'Sanitizers': sanitizer_selection,
        'SDK': sdk_path,
    },
    section: 'Artifacts',
)
