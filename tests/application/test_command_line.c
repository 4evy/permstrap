#include "application/PSTCommandLine.h"

#include <assert.h>
#include <string.h>

static PSTCommandLine parse(int count, const char *const source[]) {
  static char storage[12][256];
  char *arguments[12] = {};
  assert(count <= 12);
  for (int index = 0; index < count; index++) {
    size_t length = strlen(source[index]);
    assert(length < sizeof storage[index]);
    memcpy(storage[index], source[index], length + 1);
    arguments[index] = storage[index];
  }
  return pst_command_line_parse(count, arguments);
}

int main(void) {
  const char *gui[] = {"permstrap"};
  PSTCommandLine command = parse(1, gui);
  assert(command.mode == PST_COMMAND_GUI);
  assert(command.error == PST_COMMAND_LINE_ERROR_NONE);

  const char *configured_gui[] = {
      "permstrap",
      "--password=secret",
      "--runtime-policy=/tmp/policy.json",
      "--targets=/tmp/targets.json",
  };
  command = parse(4, configured_gui);
  assert(command.mode == PST_COMMAND_GUI);
  assert(strcmp(command.password, "secret") == 0);
  assert(strcmp(command.runtime_policy_path, "/tmp/policy.json") == 0);
  assert(strcmp(command.targets_path, "/tmp/targets.json") == 0);

  const char *check[] = {
      "permstrap",
      "--runtime-policy",
      "/tmp/policy.json",
      "--self-ch",
  };
  command = parse(4, check);
  assert(command.mode == PST_COMMAND_SELF_CHECK);
  assert(strcmp(command.runtime_policy_path, "/tmp/policy.json") == 0);

  const char *dump[] = {"permstrap", "--dump-ax=42"};
  command = parse(2, dump);
  assert(command.mode == PST_COMMAND_DUMP_AX);
  assert(command.process_identifier == 42);

  const char *verify[] = {"permstrap", "--verify-agent", "7"};
  command = parse(3, verify);
  assert(command.mode == PST_COMMAND_VERIFY_AGENT);
  assert(command.process_identifier == 7);

  const char *help[] = {"permstrap", "-Vh", "--unknown"};
  command = parse(3, help);
  assert(command.mode == PST_COMMAND_HELP);

  const char *version[] = {"permstrap", "--version"};
  command = parse(2, version);
  assert(command.mode == PST_COMMAND_VERSION);

  const char *password_with_dash[] = {"permstrap", "--password=-secret"};
  command = parse(2, password_with_dash);
  assert(command.mode == PST_COMMAND_GUI);
  assert(strcmp(command.password, "-secret") == 0);

  const char *missing[] = {"permstrap", "--password"};
  command = parse(2, missing);
  assert(command.mode == PST_COMMAND_INVALID);
  assert(command.error == PST_COMMAND_LINE_ERROR_MISSING_VALUE);

  const char *duplicate[] = {
      "permstrap", "--runtime-policy", "a", "--runtime-policy", "b",
  };
  command = parse(5, duplicate);
  assert(command.error == PST_COMMAND_LINE_ERROR_DUPLICATE_OPTION);

  const char *duplicate_targets[] = {
      "permstrap", "--targets", "a", "--targets", "b",
  };
  command = parse(5, duplicate_targets);
  assert(command.error == PST_COMMAND_LINE_ERROR_DUPLICATE_OPTION);

  const char *conflicting[] = {"permstrap", "--password", "secret", "--self-check"};
  command = parse(4, conflicting);
  assert(command.error == PST_COMMAND_LINE_ERROR_CONFLICTING_ACTIONS);

  const char *conflicting_actions[] = {
      "permstrap",
      "--self-check",
      "--dump-ax=42",
  };
  command = parse(3, conflicting_actions);
  assert(command.error == PST_COMMAND_LINE_ERROR_CONFLICTING_ACTIONS);

  const char *invalid_pid[] = {"permstrap", "--dump-ax", "-1"};
  command = parse(3, invalid_pid);
  assert(command.error == PST_COMMAND_LINE_ERROR_INVALID_PROCESS_IDENTIFIER);
  assert(strstr(pst_command_line_error_description(command.error), "positive") !=
         nullptr);

  const char *non_decimal_pid[] = {"permstrap", "--dump-ax=0x2a"};
  command = parse(2, non_decimal_pid);
  assert(command.error == PST_COMMAND_LINE_ERROR_INVALID_PROCESS_IDENTIFIER);

  const char *unknown[] = {"permstrap", "--wat"};
  command = parse(2, unknown);
  assert(command.error == PST_COMMAND_LINE_ERROR_UNKNOWN_OPTION);

  const char *ambiguous[] = {"permstrap", "--ver"};
  command = parse(2, ambiguous);
  assert(command.error == PST_COMMAND_LINE_ERROR_UNKNOWN_OPTION);

  const char *terminated[] = {"permstrap", "--", "--help"};
  command = parse(3, terminated);
  assert(command.error == PST_COMMAND_LINE_ERROR_UNEXPECTED_OPERAND);

  return 0;
}
