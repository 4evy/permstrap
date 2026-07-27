#include "application/PSTApplicationModel.h"

#include <assert.h>
#include <string.h>

static void assert_text(const char *actual, const char *expected) {
  assert(actual != nullptr);
  assert(strcmp(actual, expected) == 0);
}

int main(void) {
  PSTApplicationModel model = pst_application_model_make(true);
  PSTApplicationPresentation view = pst_application_model_present(&model);
  assert_text(view.activity_title, "Automation Access Required");
  assert(view.trust_button_visible);
  assert(!view.password_entry_enabled);
  assert(!view.run_button_enabled);

  pst_application_model_set_accessibility(&model, true);
  view = pst_application_model_present(&model);
  assert_text(view.activity_title, "Administrator Password Needed");
  assert(view.password_entry_visible);
  assert(view.password_entry_enabled);
  assert(!view.forget_button_visible);

  pst_application_model_mark_credential_input_invalid(&model);
  view = pst_application_model_present(&model);
  assert_text(view.credential_status, "Enter a valid password");
  assert_text(view.activity_title, "Password Required");
  assert(view.credential_tone == PST_PRESENTATION_TONE_WARNING);

  assert(pst_application_model_begin_credential_validation(&model));
  assert(!pst_application_model_begin_credential_validation(&model));
  view = pst_application_model_present(&model);
  assert_text(view.activity_title, "Validating Password");
  assert_text(view.activity_detail, "Checking the credential with macOS…");
  assert_text(view.credential_status, "Validating with macOS…");
  assert(view.activity_busy);
  assert(!view.password_entry_enabled);

  pst_application_model_finish_credential_validation(&model, false);
  view = pst_application_model_present(&model);
  assert_text(view.credential_status, "Password validation failed");
  assert_text(view.activity_title, "Password Not Accepted");
  assert(view.credential_tone == PST_PRESENTATION_TONE_ERROR);
  assert(view.password_entry_enabled);

  assert(pst_application_model_begin_credential_validation(&model));
  pst_application_model_finish_credential_validation(&model, true);
  view = pst_application_model_present(&model);
  assert_text(view.activity_title, "Ready to Review");
  assert(!view.password_entry_visible);
  assert(view.forget_button_visible);
  assert(view.run_button_enabled);

  assert(pst_application_model_begin_workflow(&model));
  view = pst_application_model_present(&model);
  assert_text(view.run_button_title, "Granting Permissions…");
  assert_text(view.activity_title, "Granting Permissions");
  assert(view.activity_busy);
  assert(!view.run_button_enabled);
  assert(!view.forget_button_enabled);

  pst_application_model_set_accessibility(&model, false);
  view = pst_application_model_present(&model);
  assert_text(view.activity_title, "Granting Permissions");
  assert(!view.run_button_enabled);

  pst_application_model_finish_workflow(&model, false);
  view = pst_application_model_present(&model);
  assert_text(view.activity_title, "Automation Access Required");
  assert_text(view.run_button_title, "Review Permissions Again…");

  pst_application_model_set_accessibility(&model, true);
  view = pst_application_model_present(&model);
  assert_text(view.activity_title, "Finished with Issues");
  assert(view.activity_tone == PST_PRESENTATION_TONE_WARNING);
  assert(view.run_button_enabled);

  assert(pst_application_model_forget_credential(&model));
  view = pst_application_model_present(&model);
  assert_text(view.activity_title, "Administrator Password Needed");
  assert_text(view.run_button_title, "Review Permissions…");

  PSTApplicationModel unavailable = pst_application_model_make(false);
  pst_application_model_set_accessibility(&unavailable, true);
  view = pst_application_model_present(&unavailable);
  assert_text(view.activity_title, "Permission Targets Required");
  assert(!view.run_button_enabled);
  pst_application_model_set_configuration_available(&unavailable, true);
  view = pst_application_model_present(&unavailable);
  assert_text(view.activity_title, "Administrator Password Needed");

  PSTApplicationModel guarded = pst_application_model_make(true);
  assert(!pst_application_model_begin_credential_validation(&guarded));
  pst_application_model_finish_credential_validation(&guarded, true);
  assert(guarded.credential == PST_CREDENTIAL_EMPTY);
  pst_application_model_finish_workflow(&guarded, true);
  assert(guarded.workflow == PST_WORKFLOW_IDLE);

  return 0;
}
