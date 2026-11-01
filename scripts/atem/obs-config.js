// OBS WebSocket connection settings. The password lives in obs.local.json
// (gitignored) so it never lands in the repo:
//   { "url": "ws://localhost:4455", "password": "..." }
const fs = require('fs');
const path = require('path');

const LOCAL_FILE = path.join(__dirname, 'obs.local.json');

function readLocal() {
  try {
    return JSON.parse(fs.readFileSync(LOCAL_FILE, 'utf8'));
  } catch {
    return {};
  }
}

const local = readLocal();

module.exports = {
  url: local.url || 'ws://localhost:4455',
  password: local.password,
};
