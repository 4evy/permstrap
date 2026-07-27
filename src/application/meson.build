application_c_sources = files(
    'PSTApplicationModel.c',
    'PSTCommandLine.c',
)

permission_confirmation_source = files(
    'PSTPermissionConfirmationController.m',
)
ui_components_source = files(
    'PSTUIComponents.m',
)
permission_targets_document_source = files(
    'PSTPermissionTargetsDocument.m',
)
permission_targets_editor_source = files(
    'PSTPermissionTargetsEditorController.m',
)
about_window_source = files(
    'PSTAboutWindowController.m',
)
application_sources = files(
    'main.m',
    'PSTAppDelegate.m',
) + permission_confirmation_source + permission_targets_document_source
application_sources += ui_components_source
application_sources += permission_targets_editor_source + about_window_source

application_headers = files(
    'PSTAboutWindowController.h',
    'PSTApplicationModel.h',
    'PSTAppDelegate.h',
    'PSTCommandLine.h',
    'PSTPermissionConfirmationController.h',
    'PSTPermissionTargetsDocument.h',
    'PSTPermissionTargetsEditorController.h',
    'PSTUIComponents.h',
)
