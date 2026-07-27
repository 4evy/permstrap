#include "permissions/PSTPermissionManifestValidation.h"

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void *read_file(const char *path, size_t *length) {
  FILE *file = fopen(path, "rb");
  assert(file != nullptr);
  assert(fseek(file, 0, SEEK_END) == 0);
  const long file_length = ftell(file);
  assert(file_length > 0);
  assert(fseek(file, 0, SEEK_SET) == 0);

  *length = (size_t)file_length;
  void *data = malloc(*length);
  assert(data != nullptr);
  assert(fread(data, 1, *length, file) == *length);
  assert(fclose(file) == 0);
  return data;
}

static void assert_invalid_catalog(const char *json,
                                   PSTPermissionManifestValidationCode expected_code) {
  PSTPermissionManifestValidationError error = {};
  assert(!pst_permission_catalog_validate(json, strlen(json), &error));
  assert(error.code == expected_code);
  assert(error.path[0] != '\0');
  assert(error.description[0] != '\0');
}

static void assert_invalid_targets(const char *json,
                                   PSTPermissionManifestValidationCode expected_code) {
  PSTPermissionManifestValidationError error = {};
  assert(!pst_permission_targets_validate(json, strlen(json), &error));
  assert(error.code == expected_code);
  assert(error.path[0] != '\0');
  assert(error.description[0] != '\0');
}

int main(int argc, char *argv[]) {
  assert(argc == 3);
  size_t length = 0;
  void *data = read_file(argv[1], &length);
  PSTPermissionManifestValidationError error = {};
  assert(pst_permission_catalog_validate(data, length, &error));
  free(data);

  data = read_file(argv[2], &length);
  assert(pst_permission_targets_validate(data, length, &error));
  free(data);

  assert_invalid_catalog("{", PSTPermissionManifestValidationInvalidJSON);
  assert_invalid_catalog("[]", PSTPermissionManifestValidationInvalidJSON);
  assert_invalid_catalog("{\"magic\":true}",
                         PSTPermissionManifestValidationInvalidJSON);
  assert_invalid_catalog("{\"$schema\":\"./Permissions.schema.json\",\"version\":1,"
                         "\"version\":1,\"services\":[],\"permissionSets\":{}}",
                         PSTPermissionManifestValidationInvalidJSON);
  assert_invalid_catalog("{\"$schema\":\"./Permissions.schema.json\",\"version\":1,"
                         "\"services\":[{\"id\":\"x\\u0000\",\"name\":\"X\","
                         "\"route\":\"X\",\"requiresAdmin\":true,"
                         "\"mode\":\"application-list\"}],\"permissionSets\":{"
                         "\"all\":{\"name\":\"All\",\"services\":[\"x\"]}}}",
                         PSTPermissionManifestValidationInvalidService);
  assert_invalid_catalog("{\"$schema\":\"./Permissions.schema.json\",\"version\":1,"
                         "\"services\":[{\"id\":\"x\",\"name\":\"X\",\"route\":\"X\","
                         "\"requiresAdmin\":true,\"mode\":\"application-list\"}],"
                         "\"permissionSets\":{\"all\":{\"name\":\"All\","
                         "\"services\":[\"missing\"]}}}",
                         PSTPermissionManifestValidationUnknownService);
  assert_invalid_targets("{\"$schema\":\"./PermissionTargets.schema.json\","
                         "\"version\":1,\"targets\":[{\"id\":\"x\",\"name\":\"X\","
                         "\"kind\":\"executable\",\"bundleIdentifiers\":[\"dev.x\"],"
                         "\"pathCandidates\":[\"/tmp/x\"],"
                         "\"permissions\":{\"include\":[\"x\"]}}]}",
                         PSTPermissionManifestValidationInvalidTarget);
  assert_invalid_targets("{\"$schema\":\"./PermissionTargets.schema.json\","
                         "\"version\":1,\"targets\":[{\"id\":\"x\",\"name\":\"X\","
                         "\"bundleIdentifiers\":[\"dev.x\"],"
                         "\"permissions\":{\"inheritDefaults\":true}}]}",
                         PSTPermissionManifestValidationInvalidTarget);
  return 0;
}
