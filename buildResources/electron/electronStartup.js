/**
 * @fileoverview Entry point that orchestrates Electron startup, window creation, application lifecycle for Window, MacOS, and Linux.
 *  - For production Window and MacOS it also manages the server process.
 *
 * @synopsis
 * - resolves a free port (Win/MacOS Production)
 * - launches the backend server (Win/MacOS Production)
 * - creates the main window with custom menu creation (Win/MacOS/Linux)
 * - registers IPC (Inter-Process Communication) handlers for Firefox/Puppeteer, PDF generation, FFmpeg, and AudioCapture (Win/MacOS/Linux)
 * - on-demand Firefox browser engine download for Puppeteer
 * - on-demand FFMPEG download
 * - handles application events (Win/MacOS/Linux)
 * - handles the shutdown procedures (Win/MacOS Production)
 *
 * @description
 * The script manages the lifecycle of both the Electron frontend (Win/MacOS/Linux) and a backend server process (Win/MacOS Production).
 * It creates the main application window (Win/MacOS/Linux), starts/stops a backend server (Win/MacOS Production) on the first available port starting at 19119,
 * and handles various application events (Win/MacOS/Linux) like window creation, activation, and shutdown (Win/MacOS Production).
 *
 * @requirements
 * - Electron.js
 * - A compatible backend server binary (server.bin for macOS/Linux or server.exe for Windows)
 * - The first available port starting at 19119 will be used by the backend server
 * - Environment variable APP_NAME must be set for proper application naming
 */
const { app, BrowserWindow, ipcMain } = require('electron');
const path = require('path');

const { env, START_SERVER } = require('./config/paths');
const { getPort } = require('./core/ports');
const { startServer, stopServer } = require('./core/server');
const { createWindow, handleSetCanClose } = require('./core/window');
const {
  attemptStartup,
  showStartupFailure,
  setCreateWindow,
} = require('./core/startupErrors');
const { registerFirefoxHandlers } = require('./features/firefox'); // Can omit for a no-Puppeteer app, with node_modules also to reduce.
const { registerPdfHandlers } = require('./features/pdf');          // Can omit for a no-Puppeteer app, with node_modules also to reduce.
const { registerFfmpegHandlers } = require('./features/ffmpeg');    // Can omit for a no-FFMPEG app, with node_modules also to reduce.

// The portable app build process expects the next 3 lines to remain as is, including spaces. Change replacement commands if editing. It becomes 4 lines in the portable app.
if (START_SERVER) {
  app.setName('${APP_NAME}');
} else {
// The portable app build process expects the above 3 lines to remain as is, including spaces. Change replacement commands if editing. It becomes 4 lines in the portable app.
  app.setName('${APP_NAME} (Dev)');
  app.setPath('userData', path.join(app.getPath('appData'), '${APP_NAME}-dev'));  
}

let shutdownStarted = false;

const hasSingleInstanceLock = app.requestSingleInstanceLock();

if (!hasSingleInstanceLock) {
  // Another instance already owns the application lock.
  app.quit();
} else {
  // Use the existing instance.
  app.on('second-instance', () => {
    const windows = BrowserWindow.getAllWindows();

    if (windows.length === 0) {
      createWindow();
      return;
    }

    const mainWindow = windows[0];

    if (mainWindow.isMinimized()) {
      mainWindow.restore();
    }

    if (!mainWindow.isVisible()) {
      mainWindow.show();
    }

    mainWindow.focus();
  });

  app.whenReady().then(async () => {
    ipcMain.on('setCanClose', handleSetCanClose);

    setCreateWindow(createWindow);

    registerFirefoxHandlers();
    registerPdfHandlers();
    registerFfmpegHandlers();

    const port = await getPort();
    env.ROCKET_PORT = String(port);

    try {
      await attemptStartup(port);
      createWindow();
    } catch (err) {
      showStartupFailure(err, port);
    }
  });

  app.on('window-all-closed', () => {
    console.log('window-all-closed() - app quitting');

    // On macOS, apps are normally kept alive until explicitly quit.
    // This application quits so the server does not remain running.
    app.quit();
  });

  if (START_SERVER) {
    app.on('will-quit', (event) => {
      if (shutdownStarted) {
        return;
      }

      shutdownStarted = true;
      event.preventDefault();

      const maximumShutdownTimeMs = 15000;

      const shutdownTimeout = new Promise((resolve) => {
        setTimeout(() => {
          resolve('timeout');
        }, maximumShutdownTimeMs);
      });

      Promise.race([
        Promise.resolve()
          .then(() => stopServer())
          .then(() => 'completed')
          .catch((err) => {
            console.error(
              'will-quit() - Server shutdown failed:',
              err
            );
            return 'failed';
          }),

        shutdownTimeout,
      ]).then((result) => {
        if (result === 'timeout') {
          console.error(
            'will-quit() - Server shutdown timed out; continuing application quit.'
          );
        }

        app.exit(0);
      });
    });
  }

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      console.log('activate() - app creating window since there are none');
      createWindow();
    } else {
      console.log('activate() - app not creating window since there are already windows');
    }
  });
}
