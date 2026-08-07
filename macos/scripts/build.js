const path = require('path');
const fs = require('fs-extra');
const copyDir = require('copy-dir');
const crypto = require('crypto');
require('@dotenvx/dotenvx').config({
  path: ['../../app_config.env'],
  quiet: true
});

function formatProductDatetime() {
  const now = new Date();

  const pad = (n) => String(n).padStart(2, '0');
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  const day = pad(now.getDate());
  const month = months[now.getMonth()];
  const year = now.getFullYear();
  const hours = pad(now.getHours());
  const minutes = pad(now.getMinutes());
  const seconds = pad(now.getSeconds());

  const offsetMinutes = -now.getTimezoneOffset();
  const sign = offsetMinutes >= 0 ? '+' : '-';
  const offsetHours = pad(Math.floor(Math.abs(offsetMinutes) / 60));
  const offsetMins = pad(Math.abs(offsetMinutes) % 60);

  return `${day} ${month} ${year} ${hours}:${minutes}:${seconds} UTC${sign}${offsetHours}:${offsetMins}`;
}

function writeProductJson() {
  const productPath = path.resolve(__dirname, '../../globalBuildResources/product.json');

  const product = {
    name: (process.env.APP_NAME || '').replace(/^'|'$/g, ''),
    short_name: process.env.APP_SHORT_NAME || '',
    version: process.env.APP_VERSION || '',
    datetime: formatProductDatetime(),
    homepage: process.env.HOMEPAGE || '',
    start_offline: process.env.START_OFFLINE === 'true' ? true : false,
  };

  fs.writeFileSync(productPath, JSON.stringify(product, null, 2) + '\n', 'utf8');

  return productPath;
}

// Locations
const BUILD_DIR = path.resolve('../build');
if (BUILD_DIR.split("/").length < 5) {
    throw new Error(`Deleting build dir, but the path '${BUILD_DIR}' seems dangerously short. Aborting!`);
}
const SPEC_PATH = path.resolve('../../buildSpec.json');
const MACOS_BUILD_RESOURCES = path.resolve("../buildResources");
const REPO_ROOT = path.resolve("../../");
// Delete build dir if it exists
if (fs.existsSync(BUILD_DIR)) {
    fs.rmSync(BUILD_DIR, {recursive: true, force: true});
}
// Make build directory
fs.mkdirSync(BUILD_DIR);
// Load spec and extract some reusable information
const spec = fs.readJsonSync(path.resolve(SPEC_PATH));
const APP_NAME = spec['app']['name']
const FILE_APP_NAME = spec['app']['name'].toLowerCase().replace(/ /g, "-");
const APP_EXT = "zsh";
const APP_VERSION = process.env.APP_VERSION;
// Copy Rocket config
fs.copySync(
    path.join(REPO_ROOT, "Rocket.toml"),
    path.join(BUILD_DIR, "Rocket.toml")
);
// Copy and rename launcher script
fs.copySync(
    path.join(MACOS_BUILD_RESOURCES, "appLauncher.zsh"),
    path.join(BUILD_DIR, FILE_APP_NAME + "." + APP_EXT)
);
// Copy and customize sh launcher for pkg
const appLauncherSh = fs.readFileSync(path.join(MACOS_BUILD_RESOURCES, "appLauncher.sh"))
    .toString()
    .replace(/%%APP_NAME%%/g, APP_NAME)
    .replace(/%%FILE_APP_NAME%%/g, FILE_APP_NAME);
fs.writeFileSync(
    path.join(BUILD_DIR, "appLauncher.sh"),
    appLauncherSh
);
// Copy and customize sh post-install script for pkg
const postInstallSh = fs.readFileSync(path.join(MACOS_BUILD_RESOURCES, "post_install_script.sh"))
    .toString()
    .replace(/%%APP_NAME%%/g, APP_NAME)
    .replace(/%%FILE_APP_NAME%%/g, FILE_APP_NAME);
fs.writeFileSync(
    path.join(BUILD_DIR, "post_install_script.sh"),
    postInstallSh
);
// Copy port checker
const FIND_FREE_PORT = "find_free_port.sh";
fs.copySync(
    path.join(MACOS_BUILD_RESOURCES, FIND_FREE_PORT),
    path.join(BUILD_DIR, FIND_FREE_PORT)
);
// Copy and customize README
const readMe = fs.readFileSync(path.join(MACOS_BUILD_RESOURCES, "README.txt"))
    .toString()
    .replace(/%%APP_NAME%%/g, APP_NAME)
    .replace(/%%FILE_APP_NAME%%/g, FILE_APP_NAME)
    .replace(/%%APP_EXT%%/g, APP_EXT)
    .replace(/%%APP_VERSION%%/g, APP_VERSION);
fs.writeFileSync(
    path.join(BUILD_DIR, "README.txt"),
    readMe
);
// Make bin directory
fs.mkdirSync(path.join(BUILD_DIR, "bin"));
// Copy bin
const BIN_SRC = path.resolve(spec['bin']['src']);
fs.copySync(
    BIN_SRC,
    path.join(BUILD_DIR, "bin", "server.bin")
);
// Make lib directory
const libDirPath = path.join(BUILD_DIR, "lib");
fs.mkdirSync(libDirPath);
// Copy lib directories
for (
    const libSpec of spec['lib']
    .map(
        s => {
            return {
                src: path.resolve(s.src),
                dest: path.join(libDirPath, s.targetName)
            }
        }
    )
    ) {
    copyDir.sync(
        libSpec.src,
        path.join(libSpec.dest),
        {}
    );
}
// Patch i18n
const builtI18nPath = path.join(BUILD_DIR, "lib", "templates", "i18n.json");
const i18nJson = fs.readJsonSync(builtI18nPath);
const i18nPatchPath = path.resolve("../../globalBuildResources/i18nPatch.json");
const patchJson = fs.readJsonSync(i18nPatchPath);
for ([level1, level1Values] of Object.entries(patchJson)) {
    for ([level2, level2Values] of Object.entries(level1Values)) {
        for ([level3, payload] of Object.entries(level2Values)) {
            if (!i18nJson[level1] || !i18nJson[level1][level2] || !i18nJson[level1][level2][level3]) {
                throw new Error(`Trying to patch i18n for '${level1}/${level2}/${level3}' which does not exist in i18n template`);
            }
            i18nJson[level1][level2][level3] = payload;
        }
    }
}
fs.writeJsonSync(builtI18nPath, i18nJson);
// Make lib/clients
fs.mkdirSync(path.join(BUILD_DIR, "lib", "clients"));
// Copy clients and, optionally, favicon:
for (const libClientSrc of spec['libClients'].map(s => path.resolve(s))) {
    const clientSrcLeaf = libClientSrc.split("/").reverse()[0];
    const clientDestParent = path.join(BUILD_DIR, "lib", "clients", clientSrcLeaf);
    // - mkdir
    fs.mkdirSync(clientDestParent);
    // - storage_id.json
    fs.writeFileSync(
        path.join(clientDestParent, 'storage_id.json'),
        JSON.stringify({ id: crypto.randomUUID() })
    );
    // - package.json
    fs.copySync(
        path.join(libClientSrc, "package.json"),
        path.join(clientDestParent, "package.json")
    );
    // - pankosmia-metadata.json
    fs.copySync(
        path.join(libClientSrc, "pankosmia_metadata.json"),
        path.join(clientDestParent, "pankosmia_metadata.json")
    );
    // - client build/
    copyDir.sync(
        path.join(libClientSrc, "build"),
        path.join(clientDestParent, "build"),
        {}
    );
    // - maybe favicon
    if (spec.favIcon) {
        fs.copySync(
            path.resolve(spec.favIcon),
            path.join(clientDestParent, "build", "favicon.ico")
        );
    }
}
// Theme
if (spec.theme) {
    fs.copySync(
        path.resolve(spec.theme),
        path.join(BUILD_DIR, "lib", "app_resources", "themes", "default.json")
    );
}
// Product
const generatedProductPath = writeProductJson();

if (spec.product) {
  fs.copySync(
    generatedProductPath,
    path.join(BUILD_DIR, "lib", "app_resources", "product", "product.json")
  );
}
// i18n Overrides
const I18N_OVERRIDES = "../../globalBuildResources/i18n-overrides.json";
if (I18N_OVERRIDES) {
    fs.copySync(
        path.resolve(I18N_OVERRIDES),
        path.join(BUILD_DIR, "lib", "app_resources", "product", "i18n-overrides.json")
    );
}
// client_config
if (spec.client_config) {
    fs.copySync(
        path.resolve(spec.client_config),
        path.join(BUILD_DIR, "lib", "app_resources", "product", "client_config.json")
    );
}
// Product Resources
fs.copySync(
    path.resolve("../../globalBuildResources/product_resources"),
    path.join(BUILD_DIR, "lib", "app_resources", "product", "product_resources"),
    { recursive: true }
);