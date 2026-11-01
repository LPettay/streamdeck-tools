const { Atem } = require('atem-connection');
const atem = new Atem();

atem.on('connected', () => {
  console.log('API Version:', atem.state.info.apiVersion);
  console.log('Model:', atem.state.info.model);
  console.log('Product:', atem.state.info.productIdentifier);
  console.log('Last State:', JSON.stringify(atem.state.info.lastState, null, 2));

  // Check all top-level state keys
  console.log('\nState keys:', Object.keys(atem.state));

  atem.disconnect();
  process.exit(0);
});

atem.on('error', (err) => { console.error(err.message); process.exit(1); });
setTimeout(() => { process.exit(1); }, 5000);
atem.connect('172.25.98.33');
