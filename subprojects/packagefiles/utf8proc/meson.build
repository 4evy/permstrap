project(
    'utf8proc',
    'c',
    version: '2.11.3',
    license: ['MIT', 'Unicode-3.0'],
    meson_version: '>=0.58.0',
    default_options: [
        'c_std=c23',
        'warning_level=0',
        'werror=false',
    ],
)

auto_var_init = get_option('buildtype') in ['release', 'minsize'] ? 'zero' : 'pattern'
c_args = [
    '-std=c23',
    '-U_FORTIFY_SOURCE',
    '-D_FORTIFY_SOURCE=3',
    '-DUTF8PROC_STATIC',
    '-fno-common',
    '-fstrict-flex-arrays=3',
    '-fstack-protector-strong',
    '-ftrivial-auto-var-init=' + auto_var_init,
    '-fvisibility=hidden',
    '-mbranch-protection=standard',
    '-mmacosx-version-min=26.0',
]

utf8proc_inc = include_directories('.')
utf8proc_include_directory = meson.current_source_dir()
utf8proc_lib = static_library(
    'utf8proc',
    'utf8proc.c',
    c_args: c_args,
    include_directories: utf8proc_inc,
)
utf8proc_dep = declare_dependency(
    compile_args: '-DUTF8PROC_STATIC',
    include_directories: utf8proc_inc,
    link_with: utf8proc_lib,
)

meson.override_dependency('utf8proc', utf8proc_dep)
