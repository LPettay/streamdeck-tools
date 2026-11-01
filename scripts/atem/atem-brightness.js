const { Atem } = require('atem-connection');

const ATEM_IP = '172.25.98.33';
const brightness = parseInt(process.argv[2]); // 0-255 (0=off, 255=max)

if (isNaN(brightness) || brightness < 0 || brightness > 255) {
  console.error('Usage: node atem-brightness.js <0-255>');
  console.error('  0 = off, 255 = max brightness');
  process.exit(1);
}

// Custom command for ATEM panel button brightness
// Protocol command: "PnBr" (Panel Brightness)
class PanelBrightnessCommand {
  constructor(brightness) {
    this.brightness = brightness;
  }

  serialize() {
    const buffer = Buffer.alloc(4);
    buffer.writeUInt16BE(this.brightness, 0);
    // bytes 2-3 padding
    return buffer;
  }
}
PanelBrightnessCommand.rawName = 'PnBr';

const atem = new Atem();

atem.on('connected', async () => {
  try {
    await atem.sendCommand(new PanelBrightnessCommand(brightness));
    console.log(`LED brightness set to ${brightness}`);
  } catch (err) {
    console.error('Failed:', err.message);
  }
  atem.disconnect();
  process.exit(0);
});

atem.on('error', (err) => {
  console.error(err.message);
  process.exit(1);
});

setTimeout(() => { console.error('Timeout'); process.exit(1); }, 5000);
atem.connect(ATEM_IP);
