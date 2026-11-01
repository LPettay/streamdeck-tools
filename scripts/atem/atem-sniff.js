const { Atem } = require('atem-connection');
const atem = new Atem({ debugBuffers: true });

// Collect all unique command names we receive
const commands = new Set();

atem.on('connected', () => {
  console.log('Connected. Waiting 2s to collect all state commands...');
  setTimeout(() => {
    console.log('\nAll received command types (' + commands.size + '):');
    const sorted = [...commands].sort();
    sorted.forEach(c => console.log(' ', c));
    atem.disconnect();
    process.exit(0);
  }, 2000);
});

// Intercept raw packets by monkey-patching
const origEmit = atem.emit.bind(atem);
atem.emit = function(event, ...args) {
  if (event === 'receivedCommands') {
    for (const cmd of args[0]) {
      const name = cmd.constructor?.rawName || cmd.constructor?.name || 'unknown';
      commands.add(name);
    }
  }
  return origEmit(event, ...args);
};

atem.on('error', (err) => { console.error(err.message); process.exit(1); });
setTimeout(() => { process.exit(1); }, 10000);
atem.connect('172.25.98.33');
