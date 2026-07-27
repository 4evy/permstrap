ax_utility_sources = files('PSTAXUtilities.c')
system_settings_control_sources = files('PSTSystemSettingsControl.c')
automation_c_sources = (
    ax_utility_sources
    + system_settings_control_sources
)
automation_type_sources = files('PSTSystemSettingsTypes.c')

system_settings_ui_profile_source = files('PSTSystemSettingsUIProfile.m')
automation_objc_sources = (
    files(
        'PSTAutomaticFileDrag.m',
        'PSTSystemSettingsAutomator.m',
    )
    + system_settings_ui_profile_source
)

automation_headers = files(
    'PSTAXUtilities.h',
    'PSTAutomaticFileDrag.h',
    'PSTSystemSettingsAutomator.h',
    'PSTSystemSettingsControl.h',
    'PSTSystemSettingsTypes.h',
    'PSTSystemSettingsUIProfile.h',
)
