const { Atem } = require('atem-connection');
const fs = require('fs');
const path = require('path');
const atem = new Atem();

atem.on('connected', () => {
  // Deep dump everything
  const dump = JSON.stringify(atem.state, (key, value) => {
    // Skip huge binary data
    if (Buffer.isBuffer(value)) return '<Buffer>';
    if (value instanceof Uint8Array) return '<Uint8Array>';
    return value;
  }, 2);

  const outFile = path.join(__dirname, 'atem-state-dump.json');
  fs.writeFileSync(outFile, dump);
  console.log('Full state dumped to', outFile);
  console.log('Size:', dump.length, 'bytes');

  atem.disconnect();
  process.exit(0);
});

atem.on('error', (err) => { console.error(err.message); process.exit(1); });
setTimeout(() => { process.exit(1); }, 5000);
atem.connect('172.25.98.33');
