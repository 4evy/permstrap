#include "probe/PSTProbeCommandLine.h"

#include <argtable3.h>

constexpr size_t PST_PROBE_ARGUMENT_ENTRY_COUNT = 5;
constexpr int PST_PROBE_ARGUMENT_ERROR_CAPACITY = 8;
constexpr int PST_PROBE_OPTION_MAXIMUM_OCCURRENCES = 2;

typedef struct {
  arg_lit_t *stdout_only;
  arg_str_t *status_json;
  arg_lit_t *help;
  arg_lit_t *version;
  arg_end_t *end;
  void *entries[PST_PROBE_ARGUMENT_ENTRY_COUNT];
} PSTProbeArgumentTable;

static PSTProbeArgumentTable pst_probe_argument_table_create(int maximum_occurrences) {
  int option_capacity = maximum_occurrences > 0 ? maximum_occurrences : 1;
  PSTProbeArgumentTable table = {};
  table.stdout_only = arg_litn(nullptr, "stdout", 0, option_capacity,
                               "write the permission snapshot only to standard output");
  table.status_json = arg_strn(nullptr, "status-json", "PATH", 0, option_capacity,
                               "also write the permission snapshot to absolute PATH");
  table.help = arg_litn("h", "help", 0, option_capacity, "display this help and exit");
  table.version = arg_litn("V", "version", 0, option_capacity,
                           "output version information and exit");
  table.end = arg_end(PST_PROBE_ARGUMENT_ERROR_CAPACITY);

  table.entries[0] = table.stdout_only;
  table.entries[1] = table.status_json;
  table.entries[2] = table.help;
  table.entries[3] = table.version;
  table.entries[4] = table.end;
  return table;
}

static void pst_probe_argument_table_destroy(PSTProbeArgumentTable *table) {
  arg_freetable(table->entries, PST_ARRAY_COUNT(table->entries));
}

static PSTProbeCommandLine pst_probe_invalid(PSTProbeCommandLine command,
                                             PSTProbeCommandLineError error) {
  command.mode = PST_PROBE_COMMAND_INVALID;
  command.error = error;
  return command;
}

static PSTProbeCommandLineError
pst_probe_parser_error(const PSTProbeArgumentTable *table) {
  for (int index = 0; index < table->end->count; ++index) {
    if (table->end->error[index] == ARG_EMISSARG) {
      return PST_PROBE_COMMAND_LINE_ERROR_MISSING_VALUE;
    }
    if (table->end->error[index] == ARG_ENOMATCH) {
      return PST_PROBE_COMMAND_LINE_ERROR_UNEXPECTED_OPERAND;
    }
  }
  return PST_PROBE_COMMAND_LINE_ERROR_UNKNOWN_OPTION;
}

static bool pst_probe_argument_table_has_duplicate(const PSTProbeArgumentTable *table) {
  return table->stdout_only->count > 1 || table->status_json->count > 1;
}

PSTProbeCommandLine pst_probe_command_line_parse(int argument_count,
                                                 char *arguments[]) {
  PSTProbeCommandLine command = {.mode = PST_PROBE_COMMAND_WRITE_DEFAULT};
  if (argument_count < 1 || arguments == nullptr) {
    return pst_probe_invalid(command, PST_PROBE_COMMAND_LINE_ERROR_UNKNOWN_OPTION);
  }

  PSTProbeArgumentTable table =
      pst_probe_argument_table_create(PST_PROBE_OPTION_MAXIMUM_OCCURRENCES);
  if (arg_nullcheck(table.entries) != 0) {
    pst_probe_argument_table_destroy(&table);
    return pst_probe_invalid(command, PST_PROBE_COMMAND_LINE_ERROR_OUT_OF_MEMORY);
  }
  int parse_error_count = arg_parse(argument_count, arguments, table.entries);

  if (table.help->count > 0) {
    command.mode = PST_PROBE_COMMAND_HELP;
  } else if (table.version->count > 0) {
    command.mode = PST_PROBE_COMMAND_VERSION;
  } else if (pst_probe_argument_table_has_duplicate(&table)) {
    command = pst_probe_invalid(command, PST_PROBE_COMMAND_LINE_ERROR_DUPLICATE_OPTION);
  } else if (parse_error_count > 0) {
    command = pst_probe_invalid(command, pst_probe_parser_error(&table));
  } else if (table.stdout_only->count > 0 && table.status_json->count > 0) {
    command =
        pst_probe_invalid(command, PST_PROBE_COMMAND_LINE_ERROR_CONFLICTING_OUTPUTS);
  } else if (table.stdout_only->count > 0) {
    command.mode = PST_PROBE_COMMAND_WRITE_STDOUT;
  } else if (table.status_json->count > 0) {
    command.output_path = table.status_json->sval[0];
    if (command.output_path[0] != '/') {
      command =
          pst_probe_invalid(command, PST_PROBE_COMMAND_LINE_ERROR_PATH_NOT_ABSOLUTE);
    } else {
      command.mode = PST_PROBE_COMMAND_WRITE_PATH;
    }
  }

  pst_probe_argument_table_destroy(&table);
  return command;
}

const char *pst_probe_command_line_error_description(PSTProbeCommandLineError error) {
  switch (error) {
  case PST_PROBE_COMMAND_LINE_ERROR_NONE:
    return "no error";
  case PST_PROBE_COMMAND_LINE_ERROR_UNKNOWN_OPTION:
    return "unknown option";
  case PST_PROBE_COMMAND_LINE_ERROR_MISSING_VALUE:
    return "option value is missing";
  case PST_PROBE_COMMAND_LINE_ERROR_DUPLICATE_OPTION:
    return "option was provided more than once";
  case PST_PROBE_COMMAND_LINE_ERROR_CONFLICTING_OUTPUTS:
    return "options select conflicting output destinations";
  case PST_PROBE_COMMAND_LINE_ERROR_UNEXPECTED_OPERAND:
    return "unexpected positional argument";
  case PST_PROBE_COMMAND_LINE_ERROR_PATH_NOT_ABSOLUTE:
    return "status JSON path must be absolute";
  case PST_PROBE_COMMAND_LINE_ERROR_OUT_OF_MEMORY:
    return "insufficient memory";
  }
  return "unknown command-line error";
}

void pst_probe_command_line_print_help(FILE *stream, const char *executable) {
  if (stream == nullptr || executable == nullptr) {
    return;
  }

  PSTProbeArgumentTable table = pst_probe_argument_table_create(1);
  if (arg_nullcheck(table.entries) != 0) {
    pst_probe_argument_table_destroy(&table);
    return;
  }
  (void)fprintf(
      stream,
      "Usage: %s [OPTION]...\n"
      "\n"
      "Report this process's macOS privacy-permission status as JSON.\n"
      "\n"
      "With no option, also write the snapshot to Permstrap's cache directory.\n"
      "\n"
      "Options:\n",
      executable);
  arg_print_glossary_gnu(stream, table.entries);
  pst_probe_argument_table_destroy(&table);
}
