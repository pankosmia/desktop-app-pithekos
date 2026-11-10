const path = require('path');
const fs = require('fs-extra');
const { build } = require('../../buildCommon.js');

build({
  separator: "/",
  cliExt: "zsh",
  findFreePort: "find_free_port.sh",
  binSrcSuffix: "",
  binDest: "server.bin",
  writeScripts: ({ OS_BUILD_RESOURCES, BUILD_DIR, FILE_APP_NAME, CLI_EXT, APP_NAME }) => {
    fs.copySync(path.join(OS_BUILD_RESOURCES, "appLauncher.zsh"), path.join(BUILD_DIR, FILE_APP_NAME + "." + CLI_EXT));
    const postInstallSh = fs.readFileSync(path.join(OS_BUILD_RESOURCES, "post_install_script.sh"))
      .toString().replace(/%%APP_NAME%%/g, APP_NAME).replace(/%%FILE_APP_NAME%%/g, FILE_APP_NAME);
    fs.writeFileSync(path.join(BUILD_DIR, "post_install_script.sh"), postInstallSh);
  },
  readmeReplace: (readMe, { APP_NAME, FILE_APP_NAME, CLI_EXT, APP_VERSION }) =>
    readMe
      .replace(/%%APP_NAME%%/g, APP_NAME)
      .replace(/%%FILE_APP_NAME%%/g, FILE_APP_NAME)
      .replace(/%%CLI_EXT%%/g, CLI_EXT)
      .replace(/%%APP_VERSION%%/g, APP_VERSION),
  copyIcon: null,
  postProcess: null,
});
