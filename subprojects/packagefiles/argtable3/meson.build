project(
  'argtable3',
  'c',
  version: '3.3.1',
  license: 'BSD-3-Clause',
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
  '-fno-common',
  '-fstrict-flex-arrays=3',
  '-fstack-protector-strong',
  '-ftrivial-auto-var-init=' + auto_var_init,
  '-fvisibility=hidden',
  '-mbranch-protection=standard',
  '-mmacosx-version-min=13.0',
]

argtable3_inc = include_directories('dist')
argtable3_include_directory = meson.current_source_dir() / 'dist'

argtable3_lib = static_library(
  'argtable3',
  'dist/argtable3.c',
  c_args: c_args,
  include_directories: argtable3_inc,
)

argtable3_dep = declare_dependency(
  include_directories: argtable3_inc,
  link_with: argtable3_lib,
  variables: {'source_include': argtable3_include_directory},
)

meson.override_dependency('argtable3', argtable3_dep)
