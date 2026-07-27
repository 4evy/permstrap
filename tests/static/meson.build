plutil = find_program('/usr/bin/plutil', required: true)
info_plist_icon_name = run_command(
    plutil,
    '-extract',
    'CFBundleIconName',
    'raw',
    '-o',
    '-',
    info_plist,
    check: true,
).stdout().strip()
if info_plist_icon_name != 'AppIcon'
    error('resources/Info.plist must declare CFBundleIconName as AppIcon')
endif

test(
    'info-plist',
    plutil,
    args: ['-lint', app_bundle_path / 'Contents' / 'Info.plist'],
    depends: app_bundle_signature,
    suite: 'static',
)
