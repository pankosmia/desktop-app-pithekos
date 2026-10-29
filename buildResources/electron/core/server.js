const { spawn, execFile } = require('child_process');

const {
  env,
  APP_ROOT_DIR,
  SERVER_EXECUTABLE_PATH,
} = require('../config/paths');

let serverProcess = null;
let serverExitPromise = null;
let stopPromise = null;

let serverPort = null;
let serverVersion = null;

const MIN_GRACEFUL_SHUTDOWN_VERSION = '0.18.8';

function delay(ms) {
  return new Promise((resolve) =>
    setTimeout(resolve, ms)
  );
}

function parseVersion(version) {
  if (typeof version !== 'string') {
    return null;
  }

  const match = version.trim().match(/^(\d+)\.(\d+)\.(\d+)/);

  if (!match) {
    return null;
  }

  return {
    major: Number(match[1]),
    minor: Number(match[2]),
    patch: Number(match[3]),
  };
}

function isVersionAtLeast(version, minimumVersion) {
  const actual = parseVersion(version);
  const minimum = parseVersion(minimumVersion);

  if (!actual || !minimum) {
    return false;
  }

  if (actual.major !== minimum.major) {
    return actual.major > minimum.major;
  }

  if (actual.minor !== minimum.minor) {
    return actual.minor > minimum.minor;
  }

  return actual.patch >= minimum.patch;
}

function supportsGracefulShutdown() {
  return isVersionAtLeast(
    serverVersion,
    MIN_GRACEFUL_SHUTDOWN_VERSION
  );
}

async function waitForServerReady(port, opts = {}) {
  const {
    overallTimeoutMs = 20000,
    perRequestTimeoutMs = 2000,
    intervalMs = 300,
  } = opts;

  const url = `http://127.0.0.1:${port}/api/version`;
  const deadline = Date.now() + overallTimeoutMs;
  let lastError = null;

  while (Date.now() < deadline) {
    try {
      const res = await fetch(url, {
        signal: AbortSignal.timeout(perRequestTimeoutMs),
        // Avoid any caching surprises during startup probing:
        cache: 'no-store',
      });

      if (res.ok) {
        return await res.json(); // server is ready
      } else {
        // A response but not 2xx (e.g. 404/500 while booting) → keep trying.
        lastError = new Error(`Unexpected status ${res.status} from ${url}`);
      }
    } catch (err) {
      // ECONNREFUSED, socket reset, DNS, invalid JSON,
      // or per-request AbortError → keep trying.
      lastError = err;
    }

    // Guard against sleeping when there's not enough time left
    const remaining = deadline - Date.now();
    if (remaining <= 0) break;

    await delay(Math.min(intervalMs, remaining));
  }

  const e = new Error(
    `Server did not become ready within ${overallTimeoutMs} ms` +
    (lastError ? ` (last error: ${lastError.message})` : '')
  );

  e.code = 'STARTUP_TIMEOUT'; // <-- tag used to write a friendlier production message
  throw e;
}

function startServer(port) {
  if (serverProcess && serverProcess.exitCode === null) {
    return serverProcess;
  }

  // console.log('resourcesDir is ' + env.APP_RESOURCES_DIR);
  // console.log('startServer() - workingDir is ' + APP_ROOT_DIR);
  // console.log('startServer() - env is ', env);

  serverPort = port;
  serverVersion = null;

  env.ROCKET_PORT = String(port);

  // The portable app build process expects `spawn(SERVER_EXECUTABLE_PATH, []` to remain as is. Change replacement commands if editing. The `[]` will be filled in with a path in the portable app.
  serverProcess = spawn(SERVER_EXECUTABLE_PATH, [], {
    stdio: 'ignore',
    detached: false,
    env,
    cwd: APP_ROOT_DIR,
  });

  serverExitPromise = new Promise((resolve) => {
    serverProcess.once('exit', (code, signal) => {
      console.log(
        `startServer() - Server exited. code=${code}, signal=${signal}`
      );

      resolve({ code, signal });

      serverProcess = null;
      serverExitPromise = null;
      serverPort = null;
      serverVersion = null;
    });

    serverProcess.once('error', (err) => {
      console.error('startServer() - Server process error:', err);
    });
  });

  return serverProcess;
}

function setServerVersion(version) {
  serverVersion = version;
}

function waitForProcessExit(processToStop, timeoutMs) {
  if (!processToStop) {
    return Promise.resolve(true);
  }

  if (processToStop.exitCode !== null) {
    return Promise.resolve(true);
  }

  const exitPromise =
    processToStop === serverProcess && serverExitPromise
      ? serverExitPromise.then(() => true)
      : new Promise((resolve) => {
          processToStop.once('exit', () => resolve(true));
        });

  return Promise.race([
    exitPromise,
    delay(timeoutMs).then(() => false),
  ]);
}

function forceKillProcess(processToKill, timeoutMs = 2000) {
  if (!processToKill || processToKill.pid == null) {
    return Promise.resolve();
  }

  const pid = String(processToKill.pid);

  if (process.platform === 'win32') {
    return new Promise((resolve) => {
      let settled = false;

      const finish = () => {
        if (settled) return;
        settled = true;
        clearTimeout(timeout);
        resolve();
      };

      // Kill the process we spawned and any children it created.
      const taskkillProcess = execFile(
        'taskkill',
        ['/pid', pid, '/t', '/f'],
        (error, stdout, stderr) => {
          if (error) {
            // It may have already exited.
            console.error(
              'stopServer() - Windows forceful termination failed:',
              error.message
            );

            if (stderr) {
              console.error(
                'stopServer() - taskkill stderr:',
                stderr
              );
            }
          } else {
            console.log(
              'stopServer() - Server forcefully terminated.'
            );
          }

          finish();
        }
      );

      const timeout = setTimeout(() => {
        console.error(
          'stopServer() - taskkill timed out; terminating taskkill itself.'
        );

        try {
          taskkillProcess.kill();
        } catch {
          // taskkill may already have exited
        }

        finish();
      }, timeoutMs);
    });
  }

  return new Promise((resolve) => {
    try {
      process.kill(processToKill.pid, 'SIGKILL');
      console.log('stopServer() - Server forcefully terminated.');
    } catch (e) {
      // It may have already exited
      if (e.code !== 'ESRCH') {
        console.error(
          'stopServer() - Server forceful termination failed:',
          e.message
        );
      }
    }

    resolve();
  });
}

async function requestGracefulShutdown(port) {
  const url = `http://127.0.0.1:${port}/api/system/shutdown`;

  const res = await fetch(url, {
    method: 'POST',
    signal: AbortSignal.timeout(2000),
    cache: 'no-store',
  });

  if (!res.ok) {
    throw new Error(
      `Graceful shutdown returned HTTP status ${res.status}.`
    );
  }

  const body = await res.json();

  if (!body || body.is_good !== true) {
    throw new Error(
      'Graceful shutdown returned an unsuccessful response.'
    );
  }

  console.log('stopServer() - Graceful shutdown requested.');
}

async function stopServer() {
  if (stopPromise) {
    return stopPromise;
  }

  stopPromise = (async () => {
    const processToStop = serverProcess;
    const portToStop = serverPort;

    if (!processToStop) {
      console.log('stopServer() - No owned server process to stop.');
      return;
    }

    if (processToStop.exitCode !== null) {
      console.log('stopServer() - Server has already exited.');
      return;
    }

    const shouldAttemptGracefulShutdown =
      !serverVersion ||
      isVersionAtLeast(
        serverVersion,
        MIN_GRACEFUL_SHUTDOWN_VERSION
      );

    if (shouldAttemptGracefulShutdown && portToStop !== null) {
      try {
        await requestGracefulShutdown(portToStop);

        if (await waitForProcessExit(processToStop, 5000)) {
          console.log(
            'stopServer() - Server stopped gracefully.'
          );
          return;
        }

        console.log(
          'stopServer() - Graceful shutdown timed out.'
        );
      } catch (err) {
        console.error(
          'stopServer() - Graceful shutdown failed:',
          err.message
        );
      }
    }

    await forceKillProcess(processToStop, 2000);

    if (await waitForProcessExit(processToStop, 2000)) {
      console.log(
        'stopServer() - Server stopped forcefully.'
      );
    } else {
      console.error(
        'stopServer() - Server did not confirm exit after forceful termination.'
      );
    }
  })();

  try {
    return await stopPromise;
  } finally {
    stopPromise = null;
  }
}

module.exports = {
  startServer,
  stopServer,
  waitForServerReady,
  delay,
  setServerVersion,
};
