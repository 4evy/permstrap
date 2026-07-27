#ifndef PST_COMMAND_LINE_H
#define PST_COMMAND_LINE_H

#include "core/PSTC23.h"

#include <stdint.h>
#include <stdio.h>
#include <sys/types.h>

typedef enum PSTCommandMode : uint8_t {
  PST_COMMAND_GUI = 0,
  PST_COMMAND_HELP,
  PST_COMMAND_VERSION,
  PST_COMMAND_SELF_CHECK,
  PST_COMMAND_DUMP_AX,
  PST_COMMAND_VERIFY_AGENT,
  PST_COMMAND_INVALID,
} PSTCommandMode;

typedef enum PSTCommandLineError : uint8_t {
  PST_COMMAND_LINE_ERROR_NONE = 0,
  PST_COMMAND_LINE_ERROR_UNKNOWN_OPTION,
  PST_COMMAND_LINE_ERROR_MISSING_VALUE,
  PST_COMMAND_LINE_ERROR_DUPLICATE_OPTION,
  PST_COMMAND_LINE_ERROR_CONFLICTING_ACTIONS,
  PST_COMMAND_LINE_ERROR_INVALID_PROCESS_IDENTIFIER,
  PST_COMMAND_LINE_ERROR_UNEXPECTED_OPERAND,
  PST_COMMAND_LINE_ERROR_OUT_OF_MEMORY,
} PSTCommandLineError;

typedef struct {
  PSTCommandMode mode;
  PSTCommandLineError error;
  const char *runtime_policy_path;
  const char *targets_path;
  char *password;
  pid_t process_identifier;
} PSTCommandLine;

[[nodiscard]]
PSTCommandLine pst_command_line_parse(int argument_count, char *arguments[]);
[[nodiscard]]
const char *pst_command_line_error_description(PSTCommandLineError error);
void pst_command_line_print_help(FILE *stream, const char *executable);

#endif
