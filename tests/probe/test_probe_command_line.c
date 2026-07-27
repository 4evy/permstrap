#include "probe/PSTProbeCommandLine.h"

#include <assert.h>
#include <string.h>

static PSTProbeCommandLine parse(int count, const char *const source[]) {
  static char storage[8][256];
  char *arguments[8] = {};
  assert(count <= 8);
  for (int index = 0; index < count; ++index) {
    size_t length = strlen(source[index]);
    assert(length < sizeof storage[index]);
    memcpy(storage[index], source[index], length + 1);
    arguments[index] = storage[index];
  }
  return pst_probe_command_line_parse(count, arguments);
}

int main(void) {
  const char *default_output[] = {"permstrap-probe"};
  PSTProbeCommandLine command = parse(1, default_output);
  assert(command.mode == PST_PROBE_COMMAND_WRITE_DEFAULT);

  const char *stdout_only[] = {"permstrap-probe", "--stdout"};
  command = parse(2, stdout_only);
  assert(command.mode == PST_PROBE_COMMAND_WRITE_STDOUT);

  const char *path[] = {"permstrap-probe", "--status-json=/tmp/status.json"};
  command = parse(2, path);
  assert(command.mode == PST_PROBE_COMMAND_WRITE_PATH);
  assert(strcmp(command.output_path, "/tmp/status.json") == 0);

  const char *abbreviated[] = {"permstrap-probe", "--status-j", "/tmp/status.json"};
  command = parse(3, abbreviated);
  assert(command.mode == PST_PROBE_COMMAND_WRITE_PATH);

  const char *relative[] = {"permstrap-probe", "--status-json", "status.json"};
  command = parse(3, relative);
  assert(command.error == PST_PROBE_COMMAND_LINE_ERROR_PATH_NOT_ABSOLUTE);

  const char *conflicting[] = {
      "permstrap-probe",
      "--stdout",
      "--status-json=/tmp/status.json",
  };
  command = parse(3, conflicting);
  assert(command.error == PST_PROBE_COMMAND_LINE_ERROR_CONFLICTING_OUTPUTS);

  const char *duplicate[] = {"permstrap-probe", "--stdout", "--stdout"};
  command = parse(3, duplicate);
  assert(command.error == PST_PROBE_COMMAND_LINE_ERROR_DUPLICATE_OPTION);

  const char *help[] = {"permstrap-probe", "-hV", "--unknown"};
  command = parse(3, help);
  assert(command.mode == PST_PROBE_COMMAND_HELP);

  const char *version[] = {"permstrap-probe", "--version"};
  command = parse(2, version);
  assert(command.mode == PST_PROBE_COMMAND_VERSION);

  const char *terminated[] = {"permstrap-probe", "--", "--stdout"};
  command = parse(3, terminated);
  assert(command.error == PST_PROBE_COMMAND_LINE_ERROR_UNEXPECTED_OPERAND);

  return 0;
}
