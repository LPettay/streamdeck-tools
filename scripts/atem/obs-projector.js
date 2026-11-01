const { default: OBSWebSocket } = require('obs-websocket-js');
const { execSync } = require('child_process');
const path = require('path');
const obsConfig = require('./obs-config');

const monitor = parseInt(process.argv[2] || '0');
const ps1 = path.join(__dirname, 'projector-toggle.ps1');

function runPs(action) {
  return execSync(
    `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${ps1}" ${action}`,
    { encoding: 'utf-8' }
  ).trim();
}

(async () => {
  try {
    // Check if projector is open — if so, close it
    const result = runPs('close');
    if (result === 'closed') {
      console.log('{"projector":"off"}');
      process.exit(0);
    }

    // Otherwise open it
    console.log('{"projector":"on"}');
    const obs = new OBSWebSocket();
    await obs.connect(obsConfig.url, obsConfig.password);
    await obs.call('OpenVideoMixProjector', {
      videoMixType: 'OBS_WEBSOCKET_VIDEO_MIX_TYPE_PROGRAM',
      monitorIndex: monitor
    });
    await obs.disconnect();

    // Focus after it appears
    setTimeout(() => runPs('focus'), 500);
  } catch (err) {
    console.error(err.message);
    process.exit(1);
  }
})();
