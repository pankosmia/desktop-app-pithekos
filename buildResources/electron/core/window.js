const path = require('path');
const { app, BrowserWindow, Menu, dialog, ipcMain } = require('electron');
const { env, START_SERVER, ELECTRON_ROOT_DIR } = require('../config/paths');

let canClose = true;

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
  const win = new BrowserWindow({
    title: app.name,
    width: 1024,
    height: 768,
    minWidth: 900,
    minHeight: 600,
    autoHideMenuBar: false,
    show: false,
    icon: path.join(ELECTRON_ROOT_DIR, 'favicon.png'),
    webPreferences: {
      preload: path.join(ELECTRON_ROOT_DIR, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true,
      enableRemoteModule: false,
      sandbox: false,
    },
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

  // Append " (Dev)" to page title in the development environment
  win.on('page-title-updated', (e, title) => {
    if (!START_SERVER) {
      e.preventDefault();
      win.setTitle(`${title} (Dev)`);
    }
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
  win.webContents.on('will-navigate', (event, url) => {
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
}

function InitializeMenu() {
  const isMac = process.platform === 'darwin';
  const template = [
    {
      label: 'Edit',
      submenu: [
        // {role: 'undo'},
        // {role: 'redo'},
        // {type: 'separator'},
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

module.exports = {
  createWindow,
  InitializeMenu,
  handleSetCanClose,
  installAudioCaptureHandlers,
};