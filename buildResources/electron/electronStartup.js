/**
 * @fileoverview Electron startup script for managing application lifecycle, server process, and window creation.
 *
 * @synopsis
 * This script serves as the main entry point for an Electron application, handling:
 * - Application window management
 * - Backend server process lifecycle
 * - Custom menu creation (especially for macOS)
 * - Application events and shutdown procedures
 *
 * @description
 * The script manages the lifecycle of both the Electron frontend and a backend server process.
 * It creates the main application window, starts/stops a backend server on port 19119,
 * and handles various application events like window creation, activation, and shutdown.
 * For macOS, it creates a custom application menu with standard operations.
 *
 * @requirements
 * - Electron.js
 * - A compatible backend server binary (server.bin for macOS/Linux or server.exe for Windows)
 * - Port 19119 must be available for the backend server
 * - For macOS/Linux: lsof command must be available for port checking
 * - Environment variable APP_NAME must be set for proper application naming
 */

const { app, BrowserWindow, Menu, shell, ipcMain, ipcRenderer, contextBridge, dialog } = require('electron');
const { spawn, execSync } = require('child_process');
const path = require('path');

let serverProcess = null;
app.name = '${APP_NAME}';
const port = '19119';
let canClose = true;

// Function to check if server is running (on port)
function isServerRunning() {
  try {
    // macOS & Linux: use lsof; Windows would require a different approach
    execSync(`lsof -i:${port} | grep LISTEN`, { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
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
    const resourcesDir = './lib/';
    const workingDir =  path.join(__dirname, '..');
    // console.log('startServer() - workingDir is ' + workingDir);

    // console.log('startServer() - resourcesDir is ' + resourcesDir);
    const env = {
      ...process.env,
      APP_RESOURCES_DIR: resourcesDir,
      ROCKET_PORT: port
    };

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
      execSync(`lsof -t -i:${port} | xargs kill -9`);
      console.log('stopServer() - Server stopped forcefully.');
    } catch {
      // ignore if nothing is running
      console.error(`stopServer() - Server Failed to stop - process at port ${port} ID kill failed.`);
    }
  }
}

function handleSetCanClose(event, newCanClose) {
    canClose = newCanClose;
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

        win.loadURL(`http://127.0.0.1:${port}`);
    })

}

app.whenReady().then(() => {
  ipcMain.on('setCanClose', handleSetCanClose);  
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
