const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("electronAPI", {
  // Existing
  setCanClose: (canClose) => ipcRenderer.send("setCanClose", canClose),

  // Firefox download
  downloadFirefox: () => ipcRenderer.send("download-firefox"),
  checkFirefoxInstalled: () => ipcRenderer.invoke("check-firefox-installed"),
  onDownloadProgress: (callback) => {
    const handler = (_event, percent) => callback(percent);
    ipcRenderer.on("download-progress", handler);
    return () => ipcRenderer.removeListener("download-progress", handler);
  },
  onDownloadComplete: (callback) => {
    const handler = (_event, success, errorMessage) =>
      callback(success, errorMessage);
    ipcRenderer.on("download-complete", handler);
    return () => ipcRenderer.removeListener("download-complete", handler);
  },
});

contextBridge.exposeInMainWorld("api", {
  generatePdf: async (uuid) => ipcRenderer.invoke("generate-pdf-temp", uuid),
  generatePdfToFile: async (uuid) =>
    ipcRenderer.invoke("generate-pdf-final", uuid),
});
