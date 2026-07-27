project(
    'cc',
    'c',
    version: '1.4.3',
    license: 'MIT',
    meson_version: '>=0.58.0',
    default_options: [
        'c_std=c23',
        'warning_level=0',
        'werror=false',
    ],
)

cc_inc = include_directories('.', is_system: true)
cc_include_directory = meson.current_source_dir()
cc_dep = declare_dependency(include_directories: cc_inc)

meson.override_dependency('cc', cc_dep)
