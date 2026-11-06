const path = require('path');
const fs = require('fs-extra');
const { build } = require('../../buildCommon.js');

build({
  separator: "/",
  cliExt: "sh",
  findFreePort: "find_free_port.sh",
  binSrcSuffix: "",
  binDest: "server.bin",
  writeScripts: ({ OS_BUILD_RESOURCES, BUILD_DIR, FILE_APP_NAME, CLI_EXT }) => {
    fs.copySync(path.join(OS_BUILD_RESOURCES, "appLauncher.sh"), path.join(BUILD_DIR, FILE_APP_NAME + "." + CLI_EXT));
  },
  readmeReplace: (readMe, { APP_NAME, APP_VERSION, FILE_APP_NAME }) =>
    readMe.replace(/%%APP_NAME%%/g, APP_NAME).replace(/%%APP_VERSION%%/g, APP_VERSION).replace(/%%FILE_APP_NAME%%/g, FILE_APP_NAME),
  copyIcon: null,
  postProcess: null,
});
