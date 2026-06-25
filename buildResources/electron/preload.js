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

  // FFmpeg download
  downloadFfmpeg: () => ipcRenderer.send('download-ffmpeg'),
  checkFfmpegInstalled: () => ipcRenderer.invoke('check-ffmpeg-installed'),
  onFfmpegDownloadProgress: (callback) => {
    const handler = (_event, percent) => callback(percent);
    ipcRenderer.on('ffmpeg-download-progress', handler);
    return () => ipcRenderer.removeListener('ffmpeg-download-progress', handler);
  },
  onFfmpegDownloadComplete: (callback) => {
    const handler = (_event, success, errorMessage) => callback(success, errorMessage);
    ipcRenderer.on('ffmpeg-download-complete', handler);
    return () => ipcRenderer.removeListener('ffmpeg-download-complete', handler);
  },
});

contextBridge.exposeInMainWorld("api", {
  generatePdf: async (uuid) => ipcRenderer.invoke("generate-pdf-temp", uuid),
  generatePdfToFile: async (uuid) =>
    ipcRenderer.invoke("generate-pdf-final", uuid),
});
