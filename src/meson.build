source_include = include_directories('.')

subdir('application')
subdir('authorization')
subdir('automation')
subdir('core')
subdir('permissions')
subdir('policy')
subdir('probe')
subdir('security')

portable_core_sources = (
    authorization_type_sources
    + automation_type_sources
    + core_sources
    + permission_type_sources
    + permission_confirmation_core_sources
    + permission_plan_core_sources
    + permission_selection_core_sources
    + permission_workflow_core_sources
    + policy_type_sources
)
c_sources = (
    portable_core_sources
    + platform_core_sources
    + application_c_sources
    + automation_c_sources
    + authorization_c_sources
    + permission_manifest_core_sources
    + policy_c_sources
    + probe_c_sources
    + security_c_sources
)
objc_sources = (
    application_sources
    + automation_objc_sources
    + authorization_objc_sources
    + permissions_sources
    + policy_objc_sources
    + security_objc_sources
)
app_objc_sources = (
    application_sources
    + platform_core_sources
    + automation_c_sources
    + automation_objc_sources
    + authorization_c_sources
    + authorization_objc_sources
    + permission_workflow_sources
    + security_objc_sources
)

native_headers = (
    core_headers
    + application_headers
    + automation_headers
    + authorization_headers
    + permissions_headers
    + policy_headers
    + probe_headers
    + security_headers
)
native_format_sources = c_sources + objc_sources + probe_objc_sources + native_headers

app_frameworks = dependency(
    'appleframeworks',
    modules: [
        'AppKit',
        'ApplicationServices',
        'CoreFoundation',
        'CoreGraphics',
        'Foundation',
        'Security',
        'UniformTypeIdentifiers',
    ],
)
probe_frameworks = dependency(
    'appleframeworks',
    modules: [
        'ApplicationServices',
        'AVFoundation',
        'Contacts',
        'CoreBluetooth',
        'CoreLocation',
        'EventKit',
        'Foundation',
        'Photos',
        'Speech',
    ],
)
foundation_framework = dependency('appleframeworks', modules: 'Foundation')
security_framework = dependency(
    'appleframeworks',
    modules: ['CoreFoundation', 'Security'],
)
appkit_framework = dependency(
    'appleframeworks',
    modules: ['AppKit', 'Foundation', 'UniformTypeIdentifiers'],
)
policy_frameworks = dependency(
    'appleframeworks',
    modules: ['ApplicationServices', 'Foundation'],
)
trusted_process_frameworks = dependency(
    'appleframeworks',
    modules: ['AppKit', 'Security'],
)

# Permstrap always uses its pinned, checksum-verified wrap subprojects.
argtable3_project = subproject('argtable3')
argtable3_dep = argtable3_project.get_variable('argtable3_dep')
argtable3_include_directory = argtable3_project.get_variable(
    'argtable3_include_directory',
)
yyjson_project = subproject(
    'yyjson',
    default_options: {
        'default_library': 'static',
        'fast-fp-conv': 'disabled',
        'incr-reader': 'disabled',
        'non-standard-json': 'disabled',
        'utf8-validation': 'enabled',
        'utils': 'disabled',
        'writer': 'disabled',
    },
)
yyjson_dep = yyjson_project.get_variable('yyjson_dep')
yyjson_include_directory = yyjson_project.get_variable(
    'yyjson_include_directory',
)
utf8proc_project = subproject('utf8proc')
utf8proc_dep = utf8proc_project.get_variable('utf8proc_dep')
utf8proc_include_directory = utf8proc_project.get_variable(
    'utf8proc_include_directory',
)
cc_project = subproject('cc')
cc_dep = cc_project.get_variable('cc_dep')
cc_include_directory = cc_project.get_variable('cc_include_directory')
libsodium_project = subproject('libsodium')
libsodium_dep = libsodium_project.get_variable('libsodium_dep')
libsodium_include_directory = libsodium_project.get_variable(
    'libsodium_include_directory',
)
proc_library = objc_compiler.find_library('proc', required: true)

portable_core_library = static_library(
    'pst-portable-core',
    portable_core_sources,
    dependencies: [cc_dep, utf8proc_dep],
    include_directories: source_include,
)
portable_core_dep = declare_dependency(
    include_directories: source_include,
    link_with: portable_core_library,
)
application_core_library = static_library(
    'pst-application-core',
    application_c_sources,
    dependencies: [portable_core_dep, argtable3_dep],
    include_directories: source_include,
)
application_core_dep = declare_dependency(
    dependencies: argtable3_dep,
    include_directories: source_include,
    link_with: application_core_library,
)
probe_core_library = static_library(
    'pst-probe-core',
    probe_c_sources,
    dependencies: argtable3_dep,
    include_directories: source_include,
)
probe_core_dep = declare_dependency(
    dependencies: argtable3_dep,
    include_directories: source_include,
    link_with: probe_core_library,
)
security_core_library = static_library(
    'pst-security-core',
    security_c_sources,
    dependencies: libsodium_dep,
    include_directories: source_include,
)
security_core_dep = declare_dependency(
    dependencies: [security_framework, proc_library],
    include_directories: source_include,
    link_with: security_core_library,
)
permission_manifest_core_library = static_library(
    'pst-permission-manifest-core',
    permission_manifest_core_sources,
    dependencies: [portable_core_dep, yyjson_dep],
    include_directories: source_include,
)
permission_manifest_core_dep = declare_dependency(
    dependencies: [portable_core_dep, yyjson_dep],
    include_directories: source_include,
    link_with: permission_manifest_core_library,
)
permission_model_library = static_library(
    'pst-permission-model',
    permission_model_sources,
    dependencies: [foundation_framework, permission_manifest_core_dep],
    include_directories: source_include,
)
permission_model_dep = declare_dependency(
    dependencies: [foundation_framework, permission_manifest_core_dep],
    include_directories: source_include,
    link_with: permission_model_library,
)
runtime_policy_core_library = static_library(
    'pst-runtime-policy-core',
    policy_c_sources,
    dependencies: [portable_core_dep, yyjson_dep],
    include_directories: source_include,
)
runtime_policy_core_dep = declare_dependency(
    dependencies: [portable_core_dep, yyjson_dep],
    include_directories: source_include,
    link_with: runtime_policy_core_library,
)
runtime_policy_library = static_library(
    'pst-runtime-policy',
    policy_objc_sources,
    dependencies: [foundation_framework, runtime_policy_core_dep],
    include_directories: source_include,
)
runtime_policy_dep = declare_dependency(
    dependencies: [foundation_framework, runtime_policy_core_dep],
    include_directories: source_include,
    link_with: runtime_policy_library,
)
