#include "application/PSTApplicationModel.h"

#include <assert.h>
#include <stddef.h>

typedef struct {
  const char *title;
  const char *detail;
  const char *symbol;
  PSTPresentationTone tone;
  bool busy;
} PSTActivityPresentation;

typedef struct {
  const char *status;
  const char *status_without_accessibility;
  const char *symbol;
  const char *symbol_description;
  PSTPresentationTone tone;
} PSTCredentialPresentation;

typedef enum PSTActivityKind : uint8_t {
  PST_ACTIVITY_WORKFLOW_RUNNING,
  PST_ACTIVITY_CREDENTIAL_VALIDATING,
  PST_ACTIVITY_CONFIGURATION_UNAVAILABLE,
  PST_ACTIVITY_ACCESSIBILITY_REQUIRED,
  PST_ACTIVITY_WORKFLOW_SUCCEEDED,
  PST_ACTIVITY_WORKFLOW_FAILED,
  PST_ACTIVITY_CREDENTIAL_INPUT_INVALID,
  PST_ACTIVITY_CREDENTIAL_REJECTED,
  PST_ACTIVITY_READY,
  PST_ACTIVITY_CREDENTIAL_REQUIRED,
  PST_ACTIVITY_COUNT,
} PSTActivityKind;

typedef struct {
  const char *title;
} PSTWorkflowPresentation;

static const PSTActivityPresentation PST_ACTIVITY_PRESENTATIONS[] = {
    [PST_ACTIVITY_WORKFLOW_RUNNING] =
        {
            .title = "Granting Permissions",
            .detail = "System Settings may open while permissions are updated.",
            .busy = true,
        },
    [PST_ACTIVITY_CREDENTIAL_VALIDATING] =
        {
            .title = "Validating Password",
            .detail = "Checking the credential with macOS…",
            .busy = true,
        },
    [PST_ACTIVITY_CONFIGURATION_UNAVAILABLE] =
        {
            .title = "Permission Targets Required",
            .detail = "Choose a valid runtime target JSON file to continue.",
            .symbol = "doc.badge.gearshape",
            .tone = PST_PRESENTATION_TONE_WARNING,
        },
    [PST_ACTIVITY_ACCESSIBILITY_REQUIRED] =
        {
            .title = "Automation Access Required",
            .detail =
                "Allow Accessibility control and native event posting for this app.",
            .symbol = "exclamationmark.circle.fill",
            .tone = PST_PRESENTATION_TONE_WARNING,
        },
    [PST_ACTIVITY_WORKFLOW_SUCCEEDED] =
        {
            .title = "Permissions Granted",
            .detail = "The configured permission workflow completed.",
            .symbol = "checkmark.circle.fill",
            .tone = PST_PRESENTATION_TONE_SUCCESS,
        },
    [PST_ACTIVITY_WORKFLOW_FAILED] =
        {
            .title = "Finished with Issues",
            .detail = "Some permission changes could not be completed. Check Details.",
            .symbol = "exclamationmark.triangle.fill",
            .tone = PST_PRESENTATION_TONE_WARNING,
        },
    [PST_ACTIVITY_CREDENTIAL_INPUT_INVALID] =
        {
            .title = "Password Required",
            .detail = "Enter the administrator password and choose Validate.",
            .symbol = "exclamationmark.circle.fill",
            .tone = PST_PRESENTATION_TONE_WARNING,
        },
    [PST_ACTIVITY_CREDENTIAL_REJECTED] =
        {
            .title = "Password Not Accepted",
            .detail = "Enter the administrator password and try again.",
            .symbol = "xmark.circle.fill",
            .tone = PST_PRESENTATION_TONE_ERROR,
        },
    [PST_ACTIVITY_READY] =
        {
            .title = "Ready to Review",
            .detail = "Review the affected apps and permissions before continuing.",
            .symbol = "checkmark.circle.fill",
            .tone = PST_PRESENTATION_TONE_SUCCESS,
        },
    [PST_ACTIVITY_CREDENTIAL_REQUIRED] =
        {
            .title = "Administrator Password Needed",
            .detail = "Enter and validate your password to continue.",
            .symbol = "lock.circle",
            .tone = PST_PRESENTATION_TONE_NEUTRAL,
        },
};

static const PSTCredentialPresentation PST_CREDENTIAL_PRESENTATIONS[] = {
    [PST_CREDENTIAL_EMPTY] =
        {
            .status = "Used only for verified Apple authorization prompts",
            .status_without_accessibility =
                "Available after automation access is granted",
            .symbol = "lock.fill",
            .symbol_description = "Administrator password",
            .tone = PST_PRESENTATION_TONE_NEUTRAL,
        },
    [PST_CREDENTIAL_INPUT_INVALID] =
        {
            .status = "Enter a valid password",
            .symbol = "exclamationmark.circle.fill",
            .symbol_description = "Password required",
            .tone = PST_PRESENTATION_TONE_WARNING,
        },
    [PST_CREDENTIAL_VALIDATING] =
        {
            .status = "Validating with macOS…",
            .symbol = "lock.fill",
            .symbol_description = "Validating password",
            .tone = PST_PRESENTATION_TONE_NEUTRAL,
        },
    [PST_CREDENTIAL_VALIDATED] =
        {
            .status = "Validated and stored in locked memory",
            .symbol = "checkmark.circle.fill",
            .symbol_description = "Password validated",
            .tone = PST_PRESENTATION_TONE_SUCCESS,
        },
    [PST_CREDENTIAL_REJECTED] =
        {
            .status = "Password validation failed",
            .symbol = "xmark.circle.fill",
            .symbol_description = "Password validation failed",
            .tone = PST_PRESENTATION_TONE_ERROR,
        },
};

static const PSTWorkflowPresentation PST_WORKFLOW_PRESENTATIONS[] = {
    [PST_WORKFLOW_IDLE] =
        {
            .title = "Review Permissions…",
        },
    [PST_WORKFLOW_RUNNING] =
        {
            .title = "Granting Permissions…",
        },
    [PST_WORKFLOW_SUCCEEDED] =
        {
            .title = "Review Permissions Again…",
        },
    [PST_WORKFLOW_FAILED] =
        {
            .title = "Review Permissions Again…",
        },
};

static_assert(PST_ARRAY_COUNT(PST_CREDENTIAL_PRESENTATIONS) ==
              PST_CREDENTIAL_REJECTED + 1);
static_assert(PST_ARRAY_COUNT(PST_WORKFLOW_PRESENTATIONS) == PST_WORKFLOW_FAILED + 1);
static_assert(PST_ARRAY_COUNT(PST_ACTIVITY_PRESENTATIONS) == PST_ACTIVITY_COUNT);

PSTApplicationModel pst_application_model_make(bool configuration_available) {
  return (PSTApplicationModel){
      .configuration_available = configuration_available,
      .credential = PST_CREDENTIAL_EMPTY,
      .workflow = PST_WORKFLOW_IDLE,
  };
}

void pst_application_model_set_configuration_available(PSTApplicationModel *model,
                                                       bool configuration_available) {
  model->configuration_available = configuration_available;
}

void pst_application_model_set_accessibility(PSTApplicationModel *model, bool trusted) {
  assert(model != nullptr);
  model->accessibility_trusted = trusted;
}

bool pst_application_model_can_validate_credential(const PSTApplicationModel *model) {
  assert(model != nullptr);
  return model->accessibility_trusted &&
         model->credential != PST_CREDENTIAL_VALIDATING &&
         model->credential != PST_CREDENTIAL_VALIDATED &&
         model->workflow != PST_WORKFLOW_RUNNING;
}

bool pst_application_model_begin_credential_validation(PSTApplicationModel *model) {
  assert(model != nullptr);
  if (!pst_application_model_can_validate_credential(model)) {
    return false;
  }
  model->credential = PST_CREDENTIAL_VALIDATING;
  return true;
}

void pst_application_model_finish_credential_validation(PSTApplicationModel *model,
                                                        bool accepted) {
  assert(model != nullptr);
  if (model->credential != PST_CREDENTIAL_VALIDATING) {
    return;
  }
  model->credential = accepted ? PST_CREDENTIAL_VALIDATED : PST_CREDENTIAL_REJECTED;
}

void pst_application_model_mark_credential_input_invalid(PSTApplicationModel *model) {
  assert(model != nullptr);
  if (model->workflow != PST_WORKFLOW_RUNNING) {
    model->credential = PST_CREDENTIAL_INPUT_INVALID;
  }
}

bool pst_application_model_forget_credential(PSTApplicationModel *model) {
  assert(model != nullptr);
  if (model->workflow == PST_WORKFLOW_RUNNING) {
    return false;
  }
  model->credential = PST_CREDENTIAL_EMPTY;
  model->workflow = PST_WORKFLOW_IDLE;
  return true;
}

bool pst_application_model_can_begin_workflow(const PSTApplicationModel *model) {
  assert(model != nullptr);
  return model->configuration_available && model->accessibility_trusted &&
         model->credential == PST_CREDENTIAL_VALIDATED &&
         model->workflow != PST_WORKFLOW_RUNNING;
}

bool pst_application_model_begin_workflow(PSTApplicationModel *model) {
  assert(model != nullptr);
  if (!pst_application_model_can_begin_workflow(model)) {
    return false;
  }
  model->workflow = PST_WORKFLOW_RUNNING;
  return true;
}

void pst_application_model_finish_workflow(PSTApplicationModel *model, bool succeeded) {
  assert(model != nullptr);
  if (model->workflow != PST_WORKFLOW_RUNNING) {
    return;
  }
  model->workflow = succeeded ? PST_WORKFLOW_SUCCEEDED : PST_WORKFLOW_FAILED;
}

static PSTActivityKind pst_activity_kind(const PSTApplicationModel *model) {
  if (model->workflow == PST_WORKFLOW_RUNNING) {
    return PST_ACTIVITY_WORKFLOW_RUNNING;
  }
  if (model->credential == PST_CREDENTIAL_VALIDATING) {
    return PST_ACTIVITY_CREDENTIAL_VALIDATING;
  }
  if (!model->configuration_available) {
    return PST_ACTIVITY_CONFIGURATION_UNAVAILABLE;
  }
  if (!model->accessibility_trusted) {
    return PST_ACTIVITY_ACCESSIBILITY_REQUIRED;
  }
  if (model->workflow == PST_WORKFLOW_SUCCEEDED) {
    return PST_ACTIVITY_WORKFLOW_SUCCEEDED;
  }
  if (model->workflow == PST_WORKFLOW_FAILED) {
    return PST_ACTIVITY_WORKFLOW_FAILED;
  }
  if (model->credential == PST_CREDENTIAL_INPUT_INVALID) {
    return PST_ACTIVITY_CREDENTIAL_INPUT_INVALID;
  }
  if (model->credential == PST_CREDENTIAL_REJECTED) {
    return PST_ACTIVITY_CREDENTIAL_REJECTED;
  }
  if (model->credential == PST_CREDENTIAL_VALIDATED) {
    return PST_ACTIVITY_READY;
  }
  return PST_ACTIVITY_CREDENTIAL_REQUIRED;
}

PSTApplicationPresentation
pst_application_model_present(const PSTApplicationModel *model) {
  assert(model != nullptr);
  assert((size_t)model->credential < PST_ARRAY_COUNT(PST_CREDENTIAL_PRESENTATIONS));
  assert((size_t)model->workflow < PST_ARRAY_COUNT(PST_WORKFLOW_PRESENTATIONS));
  const bool trusted = model->accessibility_trusted;
  const bool validated = model->credential == PST_CREDENTIAL_VALIDATED;
  const bool running = model->workflow == PST_WORKFLOW_RUNNING;
  const PSTActivityPresentation *activity =
      &PST_ACTIVITY_PRESENTATIONS[pst_activity_kind(model)];
  const PSTCredentialPresentation *credential =
      &PST_CREDENTIAL_PRESENTATIONS[model->credential];
  const PSTWorkflowPresentation *workflow =
      &PST_WORKFLOW_PRESENTATIONS[model->workflow];

  PSTApplicationPresentation presentation = {
      .trust_status = trusted ? "Granted" : "Accessibility and event posting required",
      .trust_symbol = trusted ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
      .trust_symbol_description =
          trusted ? "Automation access granted" : "Automation access required",
      .trust_tone =
          trusted ? PST_PRESENTATION_TONE_SUCCESS : PST_PRESENTATION_TONE_WARNING,
      .trust_button_visible = !trusted,
      .password_entry_visible = !validated,
      .password_entry_enabled = pst_application_model_can_validate_credential(model),
      .forget_button_visible = validated,
      .forget_button_enabled = validated && !running,
      .run_button_title = workflow->title,
      .run_button_enabled = pst_application_model_can_begin_workflow(model),
      .activity_title = activity->title,
      .activity_detail = activity->detail,
      .activity_symbol = activity->symbol,
      .activity_tone = activity->tone,
      .activity_busy = activity->busy,
  };

  presentation.credential_status =
      !trusted && credential->status_without_accessibility != nullptr
          ? credential->status_without_accessibility
          : credential->status;
  presentation.credential_symbol = credential->symbol;
  presentation.credential_symbol_description = credential->symbol_description;
  presentation.credential_tone = credential->tone;

  return presentation;
}
