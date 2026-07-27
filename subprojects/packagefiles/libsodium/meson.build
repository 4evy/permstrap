project(
    'libsodium',
    'c',
    version: '1.0.22',
    license: 'ISC',
    meson_version: '>=1.11.0',
)

auto_var_init = get_option('buildtype') in ['release', 'minsize'] ? 'zero' : 'pattern'
external_c_args = [
    '-U_FORTIFY_SOURCE',
    '-D_FORTIFY_SOURCE=3',
    '-fno-common',
    '-fstrict-flex-arrays=3',
    '-fstack-protector-strong',
    '-ftrivial-auto-var-init=' + auto_var_init,
    '-fvisibility=hidden',
    '-mbranch-protection=standard',
    '-mmacosx-version-min=26.0',
]
optimization = get_option('optimization')
if optimization != 'plain'
    external_c_args += '-O' + optimization
endif
if get_option('debug')
    external_c_args += '-g'
endif
if get_option('b_lto')
    external_c_args += '-flto=thin'
endif
sanitizers = get_option('b_sanitize')
if sanitizers != 'none'
    external_c_args += [
        '-fno-omit-frame-pointer',
        '-fno-optimize-sibling-calls',
        '-fno-sanitize-recover=all',
        '-fsanitize=' + sanitizers,
    ]
endif
external_environment = environment({
    'CFLAGS': ' '.join(external_c_args),
})

external_project = import('unstable-external_project')
libsodium_project = external_project.add_project(
    'configure',
    configure_options: [
        '--disable-dependency-tracking',
        '--disable-pie',
        '--disable-shared',
        '--disable-ssp',
        '--enable-minimal',
        '--enable-static',
    ],
    env: external_environment,
)
libsodium_dep = libsodium_project.dependency('sodium')
libsodium_include_directory = meson.current_source_dir() / 'src' / 'libsodium' / 'include'

meson.override_dependency('libsodium', libsodium_dep)
