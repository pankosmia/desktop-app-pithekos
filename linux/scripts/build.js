const path = require('path');
const fse = require('fs-extra');
const copyDir = require('copy-dir');
// Locations
const BUILD_DIR = path.resolve('../build');
if (BUILD_DIR.split("/").length < 5) {
    throw new Error(`Deleting build dir, but the path '${BUILD_DIR}' seems dangerously short. Aborting!`);
}
const SPEC_PATH = path.resolve('../../buildSpec.json');
const LINUX_BUILD_RESOURCES = path.resolve("../buildResources");
// Delete build dir if it exists
if (fse.existsSync(BUILD_DIR)) {
    fse.rmSync(BUILD_DIR, { recursive: true, force: true });
}
// Make build directory
fse.mkdirSync(BUILD_DIR);
// Load spec and extract some reusable information
const spec = fse.readJsonSync(path.resolve(SPEC_PATH));
const APP_NAME = spec['app']['name'];
// Copy and rename launcher script
fse.copySync(
    path.join(LINUX_BUILD_RESOURCES, "appLauncher.bsh"),
    path.join(BUILD_DIR, APP_NAME)
);
// Copy and customize README
const readMe = fse.readFileSync(path.join(LINUX_BUILD_RESOURCES, "README.md"))
    .toString()
    .replace(/%%APP_NAME%%/g, APP_NAME);
fse.writeFileSync(
    path.join(BUILD_DIR, "README.md"),
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
fse.mkdirSync(path.join(BUILD_DIR, "lib"));
// Copy lib directories
for (const libSrc of spec['lib'].map(s => path.resolve(s.src))) {
    const srcLeaf = libSrc.split("/").reverse()[0];
    copyDir(
        libSrc,
        path.join(BUILD_DIR, "lib", srcLeaf),
        {}
    );
}
// Make lib/clients
fse.mkdirSync(path.join(BUILD_DIR, "lib", "clients"));
// Copy clients:
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
    copyDir(
        path.join(libClientSrc, "build"),
        path.join(clientDestParent, "build"),
        {}
    );
}