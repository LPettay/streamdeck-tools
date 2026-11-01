const { Atem } = require('atem-connection');
const fs = require('fs');
const path = require('path');

const ATEM_IP = '172.25.98.33';
const STATE_FILE = path.join(__dirname, 'state.json');
const action = process.argv[2]; // "cut", "preview"
const input = parseInt(process.argv[3]); // 1-4

const atem = new Atem();

function readState() {
  try {
    return JSON.parse(fs.readFileSync(STATE_FILE, 'utf8'));
  } catch {
    return {};
  }
}

function writeState(program, preview) {
  const state = readState();
  state.program = String(program);
  state.preview = String(preview);
  fs.writeFileSync(STATE_FILE, JSON.stringify(state));
  console.log(JSON.stringify(state));
}

atem.on('connected', async () => {
  const me = atem.state.video.mixEffects[0];

  if (action === 'cut' && input >= 1 && input <= 4) {
    await atem.changeProgramInput(input);
    writeState(input, me.previewInput);
  } else if (action === 'preview' && input >= 1 && input <= 4) {
    await atem.changePreviewInput(input);
    writeState(me.programInput, input);
  } else {
    writeState(me.programInput, me.previewInput);
  }

  atem.disconnect();
  process.exit(0);
});

atem.on('error', (err) => {
  console.error(err.message);
  process.exit(1);
});

atem.connect(ATEM_IP);
