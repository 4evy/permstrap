authorization_type_sources = files('PSTAuthorizationInjectionTypes.c')
authorization_platform_sources = files('PSTAuthorizationPlatform.c')
authorization_readiness_sources = files('PSTAuthorizationReadiness.c')
authorization_c_sources = (
    authorization_platform_sources
    + authorization_readiness_sources
)

authorization_prompt_policy_source = files('PSTAuthorizationPromptPolicy.m')
authorization_objc_sources = (
    files('PSTAuthorizationInjector.m')
    + authorization_prompt_policy_source
)

authorization_headers = files(
    'PSTAuthorizationInjectionTypes.h',
    'PSTAuthorizationInjector.h',
    'PSTAuthorizationPromptPolicy.h',
    'PSTAuthorizationPlatform.h',
    'PSTAuthorizationReadiness.h',
)
