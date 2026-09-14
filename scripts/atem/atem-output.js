const { Atem } = require('atem-connection');
const fs = require('fs');
const path = require('path');

const ATEM_IP = '172.25.98.33';
const STATE_FILE = path.join(__dirname, 'state.json');
const action = process.argv[2]; // "toggle", "program", "multiview"

// ATEM source IDs for output routing
const SOURCE_PROGRAM = 10010;   // ME1 Program
const SOURCE_MULTIVIEW = 9001;  // Multiview 1

const atem = new Atem();

function readState() {
  try {
    return JSON.parse(fs.readFileSync(STATE_FILE, 'utf8'));
  } catch {
    return {};
  }
}

function writeState(state) {
  fs.writeFileSync(STATE_FILE, JSON.stringify(state));
  console.log(JSON.stringify(state));
}

atem.on('connected', async () => {
  const state = readState();

  // Read current aux output (HDMI out = aux bus 0 on ATEM Mini Pro)
  const currentAux = atem.state.video.auxilliaries?.[0];
  const currentIsMultiview = currentAux === SOURCE_MULTIVIEW;

  let targetSource;

  if (action === 'program') {
    targetSource = SOURCE_PROGRAM;
  } else if (action === 'multiview') {
    targetSource = SOURCE_MULTIVIEW;
  } else {
    // toggle (default)
    targetSource = currentIsMultiview ? SOURCE_PROGRAM : SOURCE_MULTIVIEW;
  }

  await atem.setAuxSource(targetSource, 0);

  const outputMode = targetSource === SOURCE_MULTIVIEW ? 'multiview' : 'program';
  state.output = outputMode;
  writeState(state);

  atem.disconnect();
  process.exit(0);
});

atem.on('error', (err) => {
  console.error(err.message);
  process.exit(1);
});

atem.connect(ATEM_IP);
