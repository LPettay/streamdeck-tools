const { default: OBSWebSocket } = require('obs-websocket-js');
const obsConfig = require('./obs-config');

(async () => {
  const obs = new OBSWebSocket();
  try {
    await obs.connect(obsConfig.url, obsConfig.password);
    const { monitors } = await obs.call('GetMonitorList');
    monitors.forEach(m => {
      console.log('Index: ' + m.monitorIndex + ' | ' + m.monitorName + ' | ' + m.monitorWidth + 'x' + m.monitorHeight);
    });
    await obs.disconnect();
  } catch (err) {
    console.error('Error: ' + err.message);
    console.error('Code: ' + err.code);
    console.error(JSON.stringify(err, null, 2));
    process.exit(1);
  }
})();
