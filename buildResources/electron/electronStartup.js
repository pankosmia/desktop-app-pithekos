/**
 * @fileoverview Electron startup script for managing application lifecycle, server process, and window creation.
 *
 * @synopsis
 * This script serves as the main entry point for an Electron application, handling:
 * - Application window management
 * - Backend server process lifecycle
 * - Custom menu creation (especially for macOS)
 * - Application events and shutdown procedures
 * - On-demand Firefox browser engine download for Puppeteer
 *
 * @description
 * The script manages the lifecycle of both the Electron frontend and a backend server process.
 * It creates the main application window, starts/stops a backend server on the first available port starting at 19119,
 * and handles various application events like window creation, activation, and shutdown.
 * For macOS, it creates a custom application menu with standard operations.
 *
 * @requirements
 * - Electron.js
 * - A compatible backend server binary (server.bin for macOS/Linux or server.exe for Windows)
 * - The first available port starting at 19119 will be used by the backend server
 * - For macOS/Linux: lsof command must be available for port checking
 * - Environment variable APP_NAME must be set for proper application naming
 */

const { app, BrowserWindow, Menu, shell, ipcMain, ipcRenderer, contextBridge, dialog } = require('electron');
const { spawn, execSync } = require('child_process');
const path = require('path');
const net = require('net');
const fs = require('fs');
const puppeteer = require('puppeteer-core');
const os = require('os');
const { install, computeExecutablePath } = require('@puppeteer/browsers');
const { pipeline } = require('stream/promises');

const FIREFOX_VERSION = '149.0.2';
const FIREFOX_BUILD_ID = 'stable_' + FIREFOX_VERSION;
const ASSET_CACHE_DIR = path.join(app.getPath('home'), 'pankosmia', '_assets');
const FFMPEG_BASE_DIR = path.join(ASSET_CACHE_DIR, 'ffmpeg');
const FFMPEG_VERSION = '7.1.1'; // Matching url's entered for each OS/Arch
const FFMPEG_DIR = path.join(FFMPEG_BASE_DIR, FFMPEG_VERSION);

// Where the extracted Firefox binary lives on Windows
const FIREFOX_WIN_EXTRACT_DIR = path.join(ASSET_CACHE_DIR, 'firefox', 'win64-' + FIREFOX_BUILD_ID);

const env = {
  ...process.env,
  APP_RESOURCES_DIR: process.env.APP_RESOURCES_DIR === undefined ? './lib/' : process.env.APP_RESOURCES_DIR,
};

function findFreePort(start = 19119, end = 65535) {
  return new Promise((resolve, reject) => {
    let port = start;
    function tryPort() {
      if (port > end) return reject(new Error('free port not found'));
      const server = net.createServer();
      server.once('error', () => { port++; tryPort(); });
      server.once('listening', () => {
        server.close(() => resolve(port));
      });
      server.listen(port, '127.0.0.1');
    }
    tryPort();
  });
}

// Use existing env var or find one
async function getPort() {
  if (env.ROCKET_PORT && env.ROCKET_PORT.trim() !== '') {
    return Number(env.ROCKET_PORT);
  }
  return await findFreePort(19119);
}

getPort()
  .then(port => {
    console.log('Using port ', port);
    if (env.ROCKET_PORT === undefined) env.ROCKET_PORT = port;
  })
  .catch(err => {
    console.error('Failed to obtain port:', err);
    app.quit?.();
  });

let serverProcess = null;
app.name = '${APP_NAME}';
let canClose = true;

// Does user already have ffmpeg installed?
function getSystemFfmpegCommandName() {
  return process.platform === 'win32' ? 'ffmpeg.exe' : 'ffmpeg';
}

async function getSystemFfmpegCommand() {
  const command = getSystemFfmpegCommandName();

  try {
    await verifyFfmpegWorks(command);
    return command;
  } catch {
    return null;
  }
}

function verifyFfmpegWorks(ffmpegPathOrCommand) {
  return new Promise((resolve, reject) => {
    const child = spawn(ffmpegPathOrCommand, ['-version']);

    let stdout = '';
    let stderr = '';

    child.stdout.on('data', (d) => {
      stdout += d.toString();
    });

    child.stderr.on('data', (d) => {
      stderr += d.toString();
    });

    child.on('error', reject);

    child.on('close', (code) => {
      if (code === 0 && /ffmpeg version/i.test(stdout || stderr)) {
        resolve(true);
      } else {
        reject(new Error(`FFmpeg verification failed with exit code ${code}`));
      }
    });
  });
}

async function getAvailableFfmpegPath() {
  const bundledPath = getBundledFfmpegExecutablePath();
  if (bundledPath && fs.existsSync(bundledPath)) {
    try {
      await verifyFfmpegWorks(bundledPath);
      return bundledPath;
    } catch {
      // ignore broken bundled install
    }
  }

  const systemCommand = await getSystemFfmpegCommand();
  if (systemCommand) {
    return systemCommand;
  }

  return null;
}

// ffmpeg install details
function getPlatformInfo() {
  if (process.platform === 'win32') {
    if (process.arch === 'x64') {
      return {
        archiveExt: 'zip',
        executableName: 'ffmpeg.exe',
        downloadUrl:
          'https://github.com/GyanD/codexffmpeg/releases/download/7.1.1/ffmpeg-7.1.1-essentials_build.zip',
      };
    }

    if (process.arch === 'arm64') {
      return {
        archiveExt: '7z',
        executableName: 'ffmpeg.exe',
        downloadUrl:
          'https://github.com/tordona/ffmpeg-win-arm64/releases/download/7.1.1/ffmpeg-7.1.1-essentials-shared-win-arm64.7z',
      };
    }

    throw new Error(`Unsupported Windows architecture: ${process.arch}`);
  }

  if (process.platform === 'darwin') {
    if (process.arch === 'x64') {
      return {
        archiveExt: 'zip',
        executableName: 'ffmpeg',
        downloadUrl:
          'https://ffmpeg.martin-riedl.de/download/macos/amd64/1741001873_7.1.1/ffmpeg.zip',
      };
    }

    if (process.arch === 'arm64') {
      return {
        archiveExt: 'zip',
        executableName: 'ffmpeg',
        downloadUrl:
          'https://ffmpeg.martin-riedl.de/download/macos/arm64/1741000090_7.1.1/ffmpeg.zip',
      };
    }

    throw new Error(`Unsupported macOS architecture: ${process.arch}`);
  }

  if (process.platform === 'linux') {
    if (process.arch === 'x64') {
      return {
        archiveExt: 'zip',
        executableName: 'ffmpeg',
        downloadUrl:
          'https://ffmpeg.martin-riedl.de/download/linux/amd64/1741000776_7.1.1/ffmpeg.zip',
      };
    }

    if (process.arch === 'arm64') {
      return {
        archiveExt: 'zip',
        executableName: 'ffmpeg',
        downloadUrl:
          'https://ffmpeg.martin-riedl.de/download/linux/arm64/1740999880_7.1.1/ffmpeg.zip',
      };
    }

    throw new Error(`Unsupported Linux architecture: ${process.arch}`);
  }

  throw new Error(`Unsupported platform: ${process.platform}`);
}

function getBundledFfmpegExecutablePath() {
  const executableName = process.platform === 'win32' ? 'ffmpeg.exe' : 'ffmpeg';

  if (!fs.existsSync(FFMPEG_DIR)) return null;

  const stack = [FFMPEG_DIR];

  while (stack.length) {
    const current = stack.pop();
    const entries = fs.readdirSync(current, { withFileTypes: true });

    for (const entry of entries) {
      const fullPath = path.join(current, entry.name);

      if (entry.isDirectory()) {
        stack.push(fullPath);
      } else if (entry.isFile() && entry.name === executableName) {
        return fullPath;
      }
    }
  }

  return null;
}

async function isFfmpegInstalled() {
  const ffmpegPath = await getAvailableFfmpegPath();
  return !!ffmpegPath;
}

// Function to check if server is running (on port)
function isServerRunning() {
  try {
    // macOS & Linux: use lsof; Windows would require a different approach
    execSync(`lsof -i:${env.ROCKET_PORT} | grep LISTEN`, { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

// Helper to get the Firefox executable path (used by generate-pdf)
function getFirefoxExecutablePath() {
  return computeExecutablePath({
    browser: 'firefox',
    buildId: FIREFOX_BUILD_ID,
    cacheDir: ASSET_CACHE_DIR,
  });
}

// Helper to check if Firefox browser engine is downloaded
function isFirefoxInstalled() {
  try {
    const exePath = getFirefoxExecutablePath();
    return fs.existsSync(exePath);
  } catch {
    return false;
  }
}

/**
 * Downloads and extracts Firefox on Windows using the silent /ExtractDir flag.
 * This avoids running the installer and won't touch any existing Firefox installation.
 */
async function downloadFirefoxWindows(event) {
  const url = `https://archive.mozilla.org/pub/firefox/releases/${FIREFOX_VERSION}/win64/en-US/Firefox%20Setup%20${FIREFOX_VERSION}.exe`;
  const tempExe = path.join(os.tmpdir(), `firefox-setup-${FIREFOX_VERSION}.exe`);
  const extractDir = FIREFOX_WIN_EXTRACT_DIR;

  console.log('Download URL:', url);
  console.log('Temp file:', tempExe);
  console.log('Extract to:', extractDir);

  // Step 1: Download the .exe with progress
  event.sender.send('download-progress', 0);

  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Download failed: HTTP ${response.status} from ${url}`);
  }

  const totalBytes = parseInt(response.headers.get('content-length'), 10) || 0;
  let downloadedBytes = 0;

  // Ensure temp directory exists
  fs.mkdirSync(path.dirname(tempExe), { recursive: true });

  const fileStream = fs.createWriteStream(tempExe);
  const reader = response.body.getReader();

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    fileStream.write(Buffer.from(value));
    downloadedBytes += value.length;
    if (totalBytes > 0) {
      const percent = Math.round((downloadedBytes / totalBytes) * 100);
      event.sender.send('download-progress', percent);
    }
  }

  fileStream.end();
  await new Promise((resolve, reject) => {
    fileStream.on('finish', resolve);
    fileStream.on('error', reject);
  });

  console.log('Download complete, extracting...');
  event.sender.send('download-progress', 100);

  // Step 2: Extract the self-extracting 7z archive
  const _7z = require('7zip-min');

  await new Promise((resolve, reject) => {
    _7z.unpack(tempExe, extractDir, (err) => {
      if (err) reject(new Error(`Firefox extraction failed: ${err.message}`));
      else resolve();
    });
  });

  // Step 3: Clean up temp file
  try {
    fs.unlinkSync(tempExe);
    console.log('Temp file cleaned up');
  } catch {
    console.warn('Could not delete temp file:', tempExe);
  }

  // Step 4: Verify extraction
  const exePath = getFirefoxExecutablePath();
  if (!fs.existsSync(exePath)) {
    throw new Error(`Extraction appeared to succeed but firefox.exe not found at: ${exePath}`);
  }

  console.log('Firefox extracted successfully to:', exePath);
}

/**
 * Downloads Firefox on macOS/Linux using @puppeteer/browsers install().
 */
async function downloadFirefoxDefault(event) {
  event.sender.send('download-progress', null);

  await install({
    browser: 'firefox',
    buildId: FIREFOX_BUILD_ID,
    cacheDir: ASSET_CACHE_DIR,
    downloadProgressCallback: (downloadedBytes, totalBytes) => {
      if (
        typeof downloadedBytes === 'number' &&
        typeof totalBytes === 'number' &&
        totalBytes > 0
      ) {
        const percent = Math.round((downloadedBytes / totalBytes) * 100);
        event.sender.send('download-progress', percent);
      }
    },
  });
}

// ffmpeg
async function downloadToFile(url, destination, onProgress) {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Download failed: HTTP ${response.status} from ${url}`);
  }

  const totalBytes = parseInt(response.headers.get('content-length'), 10) || 0;
  let downloadedBytes = 0;

  fs.mkdirSync(path.dirname(destination), { recursive: true });

  const fileStream = fs.createWriteStream(destination);
  const reader = response.body.getReader();

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;

    fileStream.write(Buffer.from(value));
    downloadedBytes += value.length;

    if (totalBytes > 0 && onProgress) {
      const percent = Math.round((downloadedBytes / totalBytes) * 100);
      onProgress(percent);
    }
  }

  fileStream.end();

  await new Promise((resolve, reject) => {
    fileStream.on('finish', resolve);
    fileStream.on('error', reject);
  });
}

function extractZipWith7zip(zipPath, destinationDir) {
  return new Promise((resolve, reject) => {
    fs.mkdirSync(destinationDir, { recursive: true });

    // Same local-require pattern as your Firefox Windows extraction
    const _7z = require("7zip-min");

    _7z.unpack(zipPath, destinationDir, (err) => {
      if (err) {
        reject(new Error(`7zip extraction failed: ${err.message || err}`));
      } else {
        resolve();
      }
    });
  });
}

function extractZipWithDitto(zipPath, destinationDir) {
  return new Promise((resolve, reject) => {
    fs.mkdirSync(destinationDir, { recursive: true });

    const child = spawn("ditto", ["-x", "-k", zipPath, destinationDir]);

    let stderr = "";

    child.stderr.on("data", (data) => {
      stderr += data.toString();
    });

    child.on("error", (err) => {
      reject(new Error(`Failed to start ditto: ${err.message}`));
    });

    child.on("close", (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`ditto extraction failed with code ${code}: ${stderr}`));
      }
    });
  });
}

function extractZipWithUnzip(zipPath, destinationDir) {
  return new Promise((resolve, reject) => {
    fs.mkdirSync(destinationDir, { recursive: true });

    const child = spawn('unzip', ['-o', zipPath, '-d', destinationDir]);

    let stderr = '';

    child.stderr.on('data', (data) => {
      stderr += data.toString();
    });

    child.on('error', (err) => {
      reject(new Error(`Failed to start unzip: ${err.message}`));
    });

    child.on('close', (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`unzip extraction failed with code ${code}: ${stderr}`));
      }
    });
  });
}

function extractTarXzWithSystemTar(archivePath, destinationDir) {
  return new Promise((resolve, reject) => {
    fs.mkdirSync(destinationDir, { recursive: true });

    const child = spawn("tar", ["-xJf", archivePath, "-C", destinationDir]);

    let stderr = "";

    child.stderr.on("data", (data) => {
      stderr += data.toString();
    });

    child.on("error", (err) => {
      reject(new Error(`Failed to start tar: ${err.message}`));
    });

    child.on("close", (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`tar extraction failed with code ${code}: ${stderr}`));
      }
    });
  });
}

async function extractFfmpegArchive(archivePath, destinationDir, archiveExt) {
  fs.mkdirSync(destinationDir, { recursive: true });

  if (process.platform === 'win32' && (archiveExt === 'zip' || archiveExt === '7z')) {
    await extractZipWith7zip(archivePath, destinationDir);
    return;
  }

  if (process.platform === 'darwin' && archiveExt === 'zip') {
    await extractZipWithDitto(archivePath, destinationDir);
    return;
  }

  if (process.platform === 'linux' && archiveExt === 'zip') {
    await extractZipWithUnzip(archivePath, destinationDir);
    return;
  }

  throw new Error(
    `Unsupported archive/platform combination: ${process.platform} / ${archiveExt}`,
  );
}

function ensureExecutablePermissions(filePath) {
  if (process.platform !== 'win32') {
    fs.chmodSync(filePath, 0o755);
  }
}

async function downloadFfmpeg(event) {
  const { archiveExt, downloadUrl } = getPlatformInfo();
  const tempArchive = path.join(os.tmpdir(), `ffmpeg-${Date.now()}.${archiveExt}`);
  const extractDir = FFMPEG_DIR;

  event.sender.send('ffmpeg-download-progress', 0);

  fs.rmSync(FFMPEG_BASE_DIR, { recursive: true, force: true });
  fs.mkdirSync(extractDir, { recursive: true });

  await downloadToFile(downloadUrl, tempArchive, (percent) => {
    event.sender.send('ffmpeg-download-progress', percent);
  });

  await extractFfmpegArchive(tempArchive, extractDir, archiveExt);

  const exePath = getBundledFfmpegExecutablePath();
  if (!exePath || !fs.existsSync(exePath)) {
    throw new Error('FFmpeg extraction succeeded but executable was not found.');
  }

  ensureExecutablePermissions(exePath);
  await verifyFfmpegWorks(exePath);

  try {
    fs.unlinkSync(tempArchive);
  } catch {
    // ignore cleanup failure
  }

  event.sender.send('ffmpeg-download-progress', 100);
}

function InitializeMenu() {
  const isMac = process.platform === 'darwin';
  const template = [
    {
      label: 'Edit',
      submenu: [
        {role: 'undo'},
        {role: 'redo'},
        {type: 'separator'},
        {role: 'cut'},
        {role: 'copy'},
        {role: 'paste'},
        {role: 'pasteAndMatchStyle'},
        // {role: 'delete'},
        {role: 'selectAll'}
      ]
    },
    {
      label: 'View',
      submenu: [
        {
          label: 'Default Zoom',
          accelerator: isMac ? 'Cmd+0' : 'Ctrl+0',
          click: (_menuItem, browserWindow) => {
            const win = browserWindow || BrowserWindow.getFocusedWindow();
            if (!win) return;
            win.webContents.setZoomLevel(0);
          }
        },
        {role: 'zoomin'},
        {role: 'zoomout'},
        // {type: 'separator'}
        // {role: 'togglefullscreen'}
      ]
    },
    {
      label: 'Window',
      submenu: [
        {
          label: 'Reload',
          accelerator: isMac ? 'Cmd+R' : 'Ctrl+R',
          click: (menuItem, bw) => { if (bw) bw.webContents.reload(); }
        },
        {
          label: 'Force Reload',
          accelerator: isMac ? 'Shift+Cmd+R' : 'Ctrl+Shift+R',
          click: (menuItem, bw) => { if (bw) bw.webContents.reloadIgnoringCache(); }
        },
        {
          label: 'Toggle Developer Tools',
          accelerator: isMac ? 'Alt+Cmd+I' : 'Ctrl+Shift+I',
          click: (menuItem, bw) => { if (bw) bw.webContents.toggleDevTools(); }
        }
        // {role: 'minimize'},
        // {role: 'zoom'},
        // {type: 'separator'},
        // {role: 'front'},
        // {role: 'window'}
      ]
    }
  ];

  if (isMac) {
    template.unshift(  {
      label: app.name, // <--- This name will NOT show up in the macOS app menu, will need to update the Info.plist in the Electron folder
      submenu: [
        {role: 'hide'},
        {role: 'hideothers'},
        {role: 'unhide'},
        {type: 'separator'},
        {role: 'quit'}
      ]
    });
  }
    // Removed:
    /**
          {role: 'about'},
          {type: 'separator'},
          {role: 'services'},
          {type: 'separator'},
    */

    try {
      const initialMenu = Menu.getApplicationMenu();
      // console.log('initialMenu', initialMenu);

      // build menu
      // const menu = isMac ? Menu.buildFromTemplate(template) : [];
      const menu = Menu.buildFromTemplate(template);
      Menu.setApplicationMenu(menu);
      // console.log('Menu set successfully');

      const currentMenu = Menu.getApplicationMenu();
      // console.log('Current application menu:', currentMenu ? 'Set successfully' : 'Not set');
      // console.log('currentMenu', currentMenu);
    } catch (error) {
      console.error('Failed to set application menu:', error);
    }
}

/**
 * wraps timer in a Promise to make an async function that continues after a specific number of milliseconds.
 * @param {number} ms
 * @returns {Promise<unknown>}
 */
function delay(ms) {
  return new Promise((resolve) =>
    setTimeout(resolve, ms)
  );
}

const MAC_SERVER_PATH = './bin/server.bin';
const WIN_SERVER_PATH = './bin/server.exe';

function startServer() {
  if (!isServerRunning()) {
    const serverPath = process.platform === 'win32' ? WIN_SERVER_PATH : MAC_SERVER_PATH;
    const workingDir =  path.join(__dirname, '..');

  console.log('resourcesDir is ' + env.APP_RESOURCES_DIR);

    // console.log('startServer() - workingDir is ' + workingDir);
    // console.log('startServer() - resourcesDir is ' + resourcesDir);
    // console.log('startServer() - env is ', env);
    
    serverProcess = spawn(serverPath, [], {
      stdio: 'ignore',
      detached: true,
      env: env,
      cwd: workingDir
    });
    serverProcess.unref();
    // console.log('startServer() - Server started at ' + path.join(workingDir, serverPath));
  } else {
    // console.log(startServer() - 'Server already running.');
  }
}

function stopServer() {
  if (serverProcess) {
    // Kill the process we spawned (or use another mechanism if you need gentle shutdown)
    try {
      process.kill(serverProcess.pid);
      console.log('stopServer() - Server stopped.');
    } catch (e) {
      // It may have already exited
      console.error('stopServer() - Server Failed to stop - process ID kill failed.');
    }
  } else {
    // Optionally: kill whatever is listening on port
    try {
      console.log('stopServer() - Trying to stop server forcefully.');
      execSync(`lsof -t -i:${env.ROCKET_PORT} | xargs kill -9`);
      console.log('stopServer() - Server stopped forcefully.');
    } catch {
      // ignore if nothing is running
      console.error(`stopServer() - Server Failed to stop - process at port ${env.ROCKET_PORT} ID kill failed.`);
    }
  }
}

function handleSetCanClose(event, newCanClose) {
    canClose = newCanClose;
}

// Accorde la permission micro sans prompt OS : l'app est l'hôte de son propre
// contenu servi sur 127.0.0.1, donc le sélecteur de micro du recorder OBS peut
// énumérer les périphériques (labels remplis) et enregistrer directement.
function installAudioCaptureHandlers(ses) {
    ses.setPermissionRequestHandler((webContents, permission, callback) => {
        callback(permission === 'media' || permission === 'audioCapture');
    });
    ses.setPermissionCheckHandler((webContents, permission) => {
        return permission === 'media' || permission === 'audioCapture';
    });
}

function createWindow() {
    delay(500).then(() => {
        // console.log('createWindow() - after delay');
        const win = new BrowserWindow({
            width: 1024,
            height: 768,
            minWidth: 900,
            minHeight: 600,
            autoHideMenuBar: false,
            show: false,  // Don't show until ready to maximize
            icon: path.join(__dirname, 'favicon.png'),
            webPreferences: {
                preload: path.join(__dirname, 'preload.js'),
                nodeIntegration: false, //default is also false. True leads to console error.
                contextIsolation: true, //default is also true. What is the impact of changing this to false?
                enableRemoteModule: false, //default is also false. What is the impact of changing this to true?
                sandbox: false, // default is also false
              }
        });

        installAudioCaptureHandlers(win.webContents.session);

        win.once('ready-to-show', () => {
            win.maximize();
            win.show();
            setTimeout(() => {
              InitializeMenu();
              win.show();
              win.maximize();
            }, 300);
        });

        // Show a dialog to the user to confirm the close
        win.on('close', (event) => {
            if (!canClose) {
                event.preventDefault();
                dialog.showMessageBox(win, {
                    type: 'question',
                    title: 'Unsaved changes',
                    message: 'You have unsaved changes. Are you sure you want to close the application?',
                    buttons: ['Yes', 'No'],
                }).then((result) => {
                    if (result.response === 0) {
                        canClose = true;
                        win.close();
                    }
                });
            }
        });

        // Show a dialog to the user switch pages
        win.webContents.on('will-navigate', async (event, url) => {
            if (!canClose) {
                event.preventDefault();
                dialog.showMessageBox(win, {
                    title: 'Unsaved changes',
                    type: 'question',
                    message: 'You have unsaved changes. Are you sure you want to leave this page?',
                    buttons: ['Yes', 'No'],
                }).then((result) => {
                    if (result.response === 0) {
                        canClose = true;
                        win.loadURL(url);
                    }
                });
            }
        });

        win.loadURL(`http://127.0.0.1:${env.ROCKET_PORT}`);
    })

}

app.whenReady().then(() => {
  ipcMain.on('setCanClose', handleSetCanClose);

  // IPC: Check if Firefox browser engine is already downloaded
  ipcMain.handle('check-firefox-installed', async () => {
    return isFirefoxInstalled();
  });

  // IPC: Download Firefox browser engine on user request
  ipcMain.on('download-firefox', async (event) => {
    console.log('download-firefox triggered');
    console.log('Cache dir:', ASSET_CACHE_DIR);
    console.log('Build ID:', FIREFOX_BUILD_ID);
    console.log('Platform:', process.platform);

    try {
      if (process.platform === 'win32') {
        await downloadFirefoxWindows(event);
      } else {
        await downloadFirefoxDefault(event);
      }
      event.sender.send('download-complete', true);
    } catch (err) {
      console.error('Firefox download failed:', err.message);
      console.error('Full error:', err);
      event.sender.send('download-complete', false, err.message);
    }
  });

  ipcMain.handle("generate-pdf-temp", async (event, uuid) => {
    // Ensure Firefox is installed before attempting PDF generation
    if (!isFirefoxInstalled()) {
      throw new Error(
        "Firefox browser engine is not installed. Please download it first.",
      );
    }

    const browser = await puppeteer.launch({
      headless: true,
      browser: "firefox",
      // args: ["-safe-mode"],
      executablePath: getFirefoxExecutablePath(),
      extraPrefsFirefox: {
        "browser.startup.page": 1,
        "print.always_print_silent": true, // skip print dialog
        "print.show_print_progress": false, // disable progress UI
        "pdfjs.disabled": true, // don't intercept with PDF.js
      },
      protocolTimeout: 900000, // ← fixes your exact error
      timeout: 900000,
    });
    // const result = await dialog.showSaveDialog();

    const page = await browser.newPage();
    page.setDefaultTimeout(900000);
    page.setDefaultNavigationTimeout(900000);
   // Fetch HTML from temp storage


    await page.goto(`http://127.0.0.1:${env.ROCKET_PORT}/api/temp/html/${uuid}`, {
      waitUntil: "networkidle0",
    });


    await page.evaluate(async () => {
      await new Promise((resolve) => {
        let lastHeight = 0;

        const check = setInterval(() => {
          window.scrollTo(0, document.body.scrollHeight);

          if (document.body.scrollHeight === lastHeight) {
            clearInterval(check);
            resolve();
          }

          lastHeight = document.body.scrollHeight;
        }, 400);
      });
    });
    // await page.waitForSelector("#print-ready-marker");
    // Generate PDF buffer directly
    const pdfBuffer = await page.pdf({
      format: "A3",
      printBackground: true,
      timeout: 900000, // 5 minutes
    });
    // Create multipart form
    const formData = new FormData();

    const blob = new Blob([pdfBuffer], {
      type: "application/pdf",
    });

    formData.append("file", blob, "document.pdf");

    // Upload PDF to temp endpoint
    const uploadResponse = await fetch(
      `http://127.0.0.1:${env.ROCKET_PORT}/api/temp/bytes`,
      {
        method: "POST",
        body: formData,
      },
    );

    const uploadResult = await uploadResponse.json();

    // returns { uuid: "..." }
    // await browser.close();
    return JSON.parse(JSON.stringify(uploadResult.uuid));
  });
  ipcMain.handle("generate-pdf-final", async (event, uuid) => {
    const response = await fetch(
      `http://127.0.0.1:${env.ROCKET_PORT}/api/temp/bytes/${uuid}`,
      {
        method: "GET",
      }
    );

    // Convert response to binary data
    const arrayBuffer = await response.arrayBuffer();
    const buffer = Buffer.from(arrayBuffer);

    // Get Downloads folder
    const downloadsPath = app.getPath("downloads");

    // Create file name
    const filePath = path.join(downloadsPath, `document-${uuid}.pdf`);

    // Write file
    fs.writeFileSync(filePath, buffer);

    return filePath;
  });

  // Ensure ffmpeg is installed before using
  ipcMain.handle('check-ffmpeg-installed', async () => {
    return await isFfmpegInstalled();
  });

  ipcMain.handle('get-ffmpeg-path', async () => {
    return await getAvailableFfmpegPath();
  });

  ipcMain.on('download-ffmpeg', async (event) => {
    try {
      await downloadFfmpeg(event);
      event.sender.send('ffmpeg-download-complete', true);
    } catch (err) {
      console.error('FFmpeg download failed:', err);
      event.sender.send('ffmpeg-download-complete', false, err.message);
    }
  });
  
  startServer();
  setTimeout(createWindow, 2000); // Wait 2 seconds for server to start (adjust as needed)
});
app.on('window-all-closed', () => {
  console.log('window-all-closed() - app quitting');
  // On macOS, apps are expected to stay alive until explicitly quit
  // but we quit anyway so server doesn't remain running
  app.quit();
});

app.on('will-quit', () => {
  console.log('will-quit() - app quitting');
  stopServer();
});

app.on('before-quit', () => {
  console.log('before-quit() - app quitting');
  stopServer();
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    console.log('activate() - app creating window since there are none');
    createWindow();
  } else {
    console.log('activate() - app not creating window since there are already windows');
  }
});