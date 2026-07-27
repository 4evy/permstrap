#ifndef PST_APPLICATION_MODEL_H
#define PST_APPLICATION_MODEL_H

#include "core/PSTC23.h"

#include <stdint.h>

typedef enum PSTPresentationTone : uint8_t {
  PST_PRESENTATION_TONE_NEUTRAL = 0,
  PST_PRESENTATION_TONE_SUCCESS,
  PST_PRESENTATION_TONE_WARNING,
  PST_PRESENTATION_TONE_ERROR,
} PSTPresentationTone;

typedef enum PSTCredentialState : uint8_t {
  PST_CREDENTIAL_EMPTY = 0,
  PST_CREDENTIAL_INPUT_INVALID,
  PST_CREDENTIAL_VALIDATING,
  PST_CREDENTIAL_VALIDATED,
  PST_CREDENTIAL_REJECTED,
} PSTCredentialState;

typedef enum PSTWorkflowState : uint8_t {
  PST_WORKFLOW_IDLE = 0,
  PST_WORKFLOW_RUNNING,
  PST_WORKFLOW_SUCCEEDED,
  PST_WORKFLOW_FAILED,
} PSTWorkflowState;

typedef struct {
  bool configuration_available;
  bool accessibility_trusted;
  PSTCredentialState credential;
  PSTWorkflowState workflow;
} PSTApplicationModel;

typedef struct {
  const char *trust_status;
  const char *trust_symbol;
  const char *trust_symbol_description;
  PSTPresentationTone trust_tone;
  bool trust_button_visible;

  const char *credential_status;
  const char *credential_symbol;
  const char *credential_symbol_description;
  PSTPresentationTone credential_tone;
  bool password_entry_visible;
  bool password_entry_enabled;
  bool forget_button_visible;
  bool forget_button_enabled;

  const char *run_button_title;
  bool run_button_enabled;

  const char *activity_title;
  const char *activity_detail;
  const char *activity_symbol;
  PSTPresentationTone activity_tone;
  bool activity_busy;
} PSTApplicationPresentation;

[[nodiscard]]
PSTApplicationModel pst_application_model_make(bool configuration_available);
void pst_application_model_set_configuration_available(PSTApplicationModel *model,
                                                       bool configuration_available);
void pst_application_model_set_accessibility(PSTApplicationModel *model, bool trusted);

[[nodiscard]]
bool pst_application_model_can_validate_credential(const PSTApplicationModel *model);
[[nodiscard]]
bool pst_application_model_begin_credential_validation(PSTApplicationModel *model);
void pst_application_model_finish_credential_validation(PSTApplicationModel *model,
                                                        bool accepted);
void pst_application_model_mark_credential_input_invalid(PSTApplicationModel *model);
[[nodiscard]]
bool pst_application_model_forget_credential(PSTApplicationModel *model);

[[nodiscard]]
bool pst_application_model_can_begin_workflow(const PSTApplicationModel *model);
[[nodiscard]]
bool pst_application_model_begin_workflow(PSTApplicationModel *model);
void pst_application_model_finish_workflow(PSTApplicationModel *model, bool succeeded);

[[nodiscard]]
PSTApplicationPresentation
pst_application_model_present(const PSTApplicationModel *model);

#endif
