#include "application/PSTCommandLine.h"

#include <argtable3.h>

#include <errno.h>
#include <limits.h>
#include <stddef.h>
#include <stdlib.h>

constexpr size_t PST_ARGUMENT_ENTRY_COUNT = 9;
constexpr int PST_ARGUMENT_ERROR_CAPACITY = 16;
constexpr int PST_OPTION_MAXIMUM_OCCURRENCES = 2;

typedef struct {
  arg_str_t *runtime_policy;
  arg_str_t *targets;
  arg_str_t *password;
  arg_lit_t *self_check;
  arg_str_t *dump_ax;
  arg_str_t *verify_agent;
  arg_lit_t *help;
  arg_lit_t *version;
  arg_end_t *end;
  void *entries[PST_ARGUMENT_ENTRY_COUNT];
} PSTArgumentTable;

static PSTArgumentTable pst_argument_table_create(int maximum_occurrences) {
  PSTArgumentTable table = {};
  int option_capacity = maximum_occurrences > 0 ? maximum_occurrences : 1;
  table.runtime_policy = arg_strn(
      nullptr, "runtime-policy", "PATH", 0, option_capacity,
      "load and validate RuntimePolicy.json from PATH instead of the application "
      "bundle");
  table.targets = arg_strn(
      nullptr, "targets", "PATH", 0, option_capacity,
      "load permission targets from PATH instead of choosing a file in the GUI");
  table.password = arg_strn(
      nullptr, "password", "PASSWORD", 0, option_capacity,
      "copy a literal password into locked memory and validate it automatically");
  table.self_check = arg_litn(nullptr, "self-check", 0, option_capacity,
                              "validate the runtime configuration and exit");
  table.dump_ax = arg_strn(nullptr, "dump-ax", "PID", 0, option_capacity,
                           "print the Accessibility tree for the process PID");
  table.verify_agent =
      arg_strn(nullptr, "verify-agent", "PID", 0, option_capacity,
               "verify the trusted identity of an authorization agent PID");
  table.help = arg_litn("h", "help", 0, option_capacity, "display this help and exit");
  table.version = arg_litn("V", "version", 0, option_capacity,
                           "output version information and exit");
  table.end = arg_end(PST_ARGUMENT_ERROR_CAPACITY);

  table.entries[0] = table.runtime_policy;
  table.entries[1] = table.targets;
  table.entries[2] = table.password;
  table.entries[3] = table.self_check;
  table.entries[4] = table.dump_ax;
  table.entries[5] = table.verify_agent;
  table.entries[6] = table.help;
  table.entries[7] = table.version;
  table.entries[8] = table.end;
  return table;
}

static void pst_argument_table_destroy(PSTArgumentTable *table) {
  arg_freetable(table->entries, PST_ARRAY_COUNT(table->entries));
}

static PSTCommandLine pst_invalid(PSTCommandLine command, PSTCommandLineError error) {
  command.mode = PST_COMMAND_INVALID;
  command.error = error;
  return command;
}

static bool pst_argument_table_has_duplicate(const PSTArgumentTable *table) {
  return table->runtime_policy->count > 1 || table->targets->count > 1 ||
         table->password->count > 1 || table->self_check->count > 1 ||
         table->dump_ax->count > 1 || table->verify_agent->count > 1;
}

static PSTCommandLineError pst_parser_error(const PSTArgumentTable *table) {
  for (int index = 0; index < table->end->count; ++index) {
    if (table->end->error[index] == ARG_EMISSARG) {
      return PST_COMMAND_LINE_ERROR_MISSING_VALUE;
    }
    if (table->end->error[index] == ARG_ENOMATCH) {
      return PST_COMMAND_LINE_ERROR_UNEXPECTED_OPERAND;
    }
  }
  return PST_COMMAND_LINE_ERROR_UNKNOWN_OPTION;
}

static bool pst_parse_process_identifier(const char *text, pid_t *process_identifier) {
  char *end = nullptr;
  errno = 0;
  long parsed = strtol(text, &end, 10);
  if (errno != 0 || end == text || *end != '\0' || parsed <= 0 || parsed > INT_MAX) {
    return false;
  }
  *process_identifier = (pid_t)parsed;
  return true;
}

PSTCommandLine pst_command_line_parse(int argument_count, char *arguments[]) {
  PSTCommandLine command = {.mode = PST_COMMAND_GUI};
  if (argument_count < 1 || arguments == nullptr) {
    return pst_invalid(command, PST_COMMAND_LINE_ERROR_UNKNOWN_OPTION);
  }

  PSTArgumentTable table = pst_argument_table_create(PST_OPTION_MAXIMUM_OCCURRENCES);
  if (arg_nullcheck(table.entries) != 0) {
    pst_argument_table_destroy(&table);
    return pst_invalid(command, PST_COMMAND_LINE_ERROR_OUT_OF_MEMORY);
  }
  int parse_error_count = arg_parse(argument_count, arguments, table.entries);

  /*
   * GNU --help takes precedence over other options and syntax errors. Argtable
   * retains successfully parsed flags alongside its collected error records,
   * so this remains possible without pre-scanning or partially reimplementing
   * option syntax.
   */
  if (table.help->count > 0) {
    command.mode = PST_COMMAND_HELP;
    pst_argument_table_destroy(&table);
    return command;
  }
  if (table.version->count > 0) {
    command.mode = PST_COMMAND_VERSION;
    pst_argument_table_destroy(&table);
    return command;
  }
  if (pst_argument_table_has_duplicate(&table)) {
    command = pst_invalid(command, PST_COMMAND_LINE_ERROR_DUPLICATE_OPTION);
    pst_argument_table_destroy(&table);
    return command;
  }
  if (parse_error_count > 0) {
    command = pst_invalid(command, pst_parser_error(&table));
    pst_argument_table_destroy(&table);
    return command;
  }

  int action_count =
      table.self_check->count + table.dump_ax->count + table.verify_agent->count;
  if (action_count > 1 || (action_count > 0 && table.password->count > 0)) {
    command = pst_invalid(command, PST_COMMAND_LINE_ERROR_CONFLICTING_ACTIONS);
    pst_argument_table_destroy(&table);
    return command;
  }

  if (table.runtime_policy->count > 0) {
    command.runtime_policy_path = table.runtime_policy->sval[0];
  }
  if (table.targets->count > 0) {
    command.targets_path = table.targets->sval[0];
  }
  if (table.password->count > 0) {
    /*
     * Argtable exposes string values as const views, but argv strings are
     * writable by definition. Permstrap deliberately retains the writable
     * pointer so PSTSecureBuffer can erase the password in argv after moving it
     * into locked memory.
     */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-qual"
    command.password = (char *)table.password->sval[0];
#pragma clang diagnostic pop
  }

  if (table.self_check->count > 0) {
    command.mode = PST_COMMAND_SELF_CHECK;
  } else if (table.dump_ax->count > 0) {
    if (!pst_parse_process_identifier(table.dump_ax->sval[0],
                                      &command.process_identifier)) {
      command = pst_invalid(command, PST_COMMAND_LINE_ERROR_INVALID_PROCESS_IDENTIFIER);
    } else {
      command.mode = PST_COMMAND_DUMP_AX;
    }
  } else if (table.verify_agent->count > 0) {
    if (!pst_parse_process_identifier(table.verify_agent->sval[0],
                                      &command.process_identifier)) {
      command = pst_invalid(command, PST_COMMAND_LINE_ERROR_INVALID_PROCESS_IDENTIFIER);
    } else {
      command.mode = PST_COMMAND_VERIFY_AGENT;
    }
  }

  pst_argument_table_destroy(&table);
  return command;
}

const char *pst_command_line_error_description(PSTCommandLineError error) {
  switch (error) {
  case PST_COMMAND_LINE_ERROR_NONE:
    return "no error";
  case PST_COMMAND_LINE_ERROR_UNKNOWN_OPTION:
    return "unknown option";
  case PST_COMMAND_LINE_ERROR_MISSING_VALUE:
    return "option value is missing";
  case PST_COMMAND_LINE_ERROR_DUPLICATE_OPTION:
    return "option was provided more than once";
  case PST_COMMAND_LINE_ERROR_CONFLICTING_ACTIONS:
    return "options select conflicting actions";
  case PST_COMMAND_LINE_ERROR_INVALID_PROCESS_IDENTIFIER:
    return "process identifier must be a positive integer";
  case PST_COMMAND_LINE_ERROR_UNEXPECTED_OPERAND:
    return "unexpected positional argument";
  case PST_COMMAND_LINE_ERROR_OUT_OF_MEMORY:
    return "insufficient memory";
  }
  return "unknown command-line error";
}

void pst_command_line_print_help(FILE *stream, const char *executable) {
  if (stream == nullptr || executable == nullptr) {
    return;
  }

  PSTArgumentTable table = pst_argument_table_create(1);
  if (arg_nullcheck(table.entries) != 0) {
    pst_argument_table_destroy(&table);
    return;
  }
  (void)fprintf(stream,
                "Usage: %s [OPTION]...\n"
                "\n"
                "Bootstrap Privacy & Security permissions through System Settings.\n"
                "\n"
                "With no action option, launch the graphical permission workflow.\n"
                "\n"
                "Options:\n",
                executable);
  arg_print_glossary_gnu(stream, table.entries);
  (void)fprintf(stream,
                "Long option arguments can be passed as --OPTION=VALUE or as a\n"
                "separate argument. Use -- to end option processing.\n"
                "\n"
                "Report bugs at: <https://github.com/4evy/permstrap/issues>\n"
                "Permstrap home page: <https://github.com/4evy/permstrap>\n");
  pst_argument_table_destroy(&table);
}
