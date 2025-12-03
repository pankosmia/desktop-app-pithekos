const path = require('path');
const fse = require('fs-extra');
const copyDir = require('copy-dir');
require('@dotenvx/dotenvx').config({path: ['../../app_config.env'], quiet: true});

// Locations
const BUILD_DIR = path.resolve('../build');
if (BUILD_DIR.split("/").length < 5) {
    throw new Error(`Deleting build dir, but the path '${BUILD_DIR}' seems dangerously short. Aborting!`);
}
const SPEC_PATH = path.resolve('../../buildSpec.json');
const LINUX_BUILD_RESOURCES = path.resolve("../buildResources");
// Delete build dir if it exists
if (fse.existsSync(BUILD_DIR)) {
    fse.rmSync(BUILD_DIR, {recursive: true, force: true});
}
// Make build directory
fse.mkdirSync(BUILD_DIR);
// Load spec and extract some reusable information
const spec = fse.readJsonSync(path.resolve(SPEC_PATH));
const APP_NAME = spec['app']['name']
const FILE_APP_NAME = spec['app']['name'].toLowerCase().replace(/ /g, "-");
const APP_VERSION = process.env.APP_VERSION;
// Copy and rename launcher script
fse.copySync(
    path.join(LINUX_BUILD_RESOURCES, "appLauncher.bsh"),
    path.join(BUILD_DIR, FILE_APP_NAME)
);
// Copy and customize README
const readMe = fse.readFileSync(path.join(LINUX_BUILD_RESOURCES, "README.txt"))
    .toString()
    .replace(/%%APP_NAME%%/g, APP_NAME)
    .replace(/%%APP_VERSION%%/g, APP_VERSION);
fse.writeFileSync(
    path.join(BUILD_DIR, "README.txt"),
    readMe
);
// Make bin directory
fse.mkdirSync(path.join(BUILD_DIR, "bin"));
// Copy bin
const BIN_SRC = path.resolve(spec['bin']['src']);
fse.copySync(
    BIN_SRC,
    path.join(BUILD_DIR, "bin", "server.bin")
);
// Make lib directory
const libDirPath = path.join(BUILD_DIR, "lib");
fse.mkdirSync(libDirPath);
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
const i18nJson = fse.readJsonSync(builtI18nPath);
const i18nPatchPath = path.resolve("../../globalBuildResources/i18nPatch.json");
const patchJson = fse.readJsonSync(i18nPatchPath);
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
fse.writeJsonSync(builtI18nPath, i18nJson);
// Make lib/clients
fse.mkdirSync(path.join(BUILD_DIR, "lib", "clients"));
// Copy clients and, optionally, favicon:
for (const libClientSrc of spec['libClients'].map(s => path.resolve(s))) {
    const clientSrcLeaf = libClientSrc.split("/").reverse()[0];
    const clientDestParent = path.join(BUILD_DIR, "lib", "clients", clientSrcLeaf);
    // - mkdir
    fse.mkdirSync(clientDestParent);
    // - package.json
    fse.copySync(
        path.join(libClientSrc, "package.json"),
        path.join(clientDestParent, "package.json")
    );
    // - pankosmia-metadata.json
    fse.copySync(
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
        fse.copySync(
            path.resolve(spec.favIcon),
            path.join(clientDestParent, "build", "favicon.ico")
        );
    }
}
// Theme
if (spec.theme) {
    fse.copySync(
        path.resolve(spec.theme),
        path.join(BUILD_DIR, "lib", "app_resources", "themes", "default.json")
    );
}
// Product
if (spec.product) {
    fse.copySync(
        path.resolve(spec.product),
        path.join(BUILD_DIR, "lib", "app_resources", "product", "product.json")
    );
}