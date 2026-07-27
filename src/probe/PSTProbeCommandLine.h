#ifndef PST_PROBE_COMMAND_LINE_H
#define PST_PROBE_COMMAND_LINE_H

#include "core/PSTC23.h"

#include <stdint.h>
#include <stdio.h>

typedef enum PSTProbeCommandMode : uint8_t {
  PST_PROBE_COMMAND_WRITE_DEFAULT = 0,
  PST_PROBE_COMMAND_WRITE_STDOUT,
  PST_PROBE_COMMAND_WRITE_PATH,
  PST_PROBE_COMMAND_HELP,
  PST_PROBE_COMMAND_VERSION,
  PST_PROBE_COMMAND_INVALID,
} PSTProbeCommandMode;

typedef enum PSTProbeCommandLineError : uint8_t {
  PST_PROBE_COMMAND_LINE_ERROR_NONE = 0,
  PST_PROBE_COMMAND_LINE_ERROR_UNKNOWN_OPTION,
  PST_PROBE_COMMAND_LINE_ERROR_MISSING_VALUE,
  PST_PROBE_COMMAND_LINE_ERROR_DUPLICATE_OPTION,
  PST_PROBE_COMMAND_LINE_ERROR_CONFLICTING_OUTPUTS,
  PST_PROBE_COMMAND_LINE_ERROR_UNEXPECTED_OPERAND,
  PST_PROBE_COMMAND_LINE_ERROR_PATH_NOT_ABSOLUTE,
  PST_PROBE_COMMAND_LINE_ERROR_OUT_OF_MEMORY,
} PSTProbeCommandLineError;

typedef struct {
  PSTProbeCommandMode mode;
  PSTProbeCommandLineError error;
  const char *output_path;
} PSTProbeCommandLine;

[[nodiscard]]
PSTProbeCommandLine pst_probe_command_line_parse(int argument_count, char *arguments[]);
[[nodiscard]]
const char *pst_probe_command_line_error_description(PSTProbeCommandLineError error);
void pst_probe_command_line_print_help(FILE *stream, const char *executable);

#endif
