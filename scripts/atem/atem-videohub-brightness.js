const net = require('net');

const ATEM_IP = '172.25.98.33';
const PORT = 9990;

const client = new net.Socket();
let buffer = '';

client.connect(PORT, ATEM_IP, () => {
  console.log('Connected to Videohub protocol');
});

client.on('data', (data) => {
  buffer += data.toString();

  // Wait for END PRELUDE
  if (buffer.includes('END PRELUDE:')) {
    console.log('Got full device state');

    // Try various configuration commands for brightness
    const commands = [
      'CONFIGURATION:\nLED brightness: 0\n\n',
      'CONFIGURATION:\nPanel brightness: 0\n\n',
      'DEVICE SETTINGS:\nLED brightness: 0\n\n',
      'DEVICE SETTINGS:\nPanel brightness: 0\n\n',
      'CONFIGURATION:\nButton brightness: 0\n\n',
    ];

    let i = 0;
    const tryNext = () => {
      if (i < commands.length) {
        const cmd = commands[i];
        console.log('Trying:', cmd.trim().replace(/\n/g, ' | '));
        client.write(cmd);
        i++;
        setTimeout(tryNext, 500);
      } else {
        console.log('Done trying commands');
        client.destroy();
        process.exit(0);
      }
    };

    setTimeout(tryNext, 500);
  }
});

client.on('error', (err) => {
  console.error('Error:', err.message);
  process.exit(1);
});

setTimeout(() => { client.destroy(); process.exit(0); }, 10000);
