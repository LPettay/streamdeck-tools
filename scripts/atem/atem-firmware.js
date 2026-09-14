const { Atem } = require('atem-connection');
const atem = new Atem();

atem.on('connected', () => {
  const ver = atem.state.info.apiVersion;
  const major = (ver >> 16) & 0xff;
  const minor = (ver >> 8) & 0xff;
  const patch = ver & 0xff;
  console.log('Protocol version:', major + '.' + minor + '.' + patch);
  console.log('Raw API version:', ver);
  console.log('Model ID:', atem.state.info.model);
  console.log('Product:', atem.state.info.productIdentifier);
  atem.disconnect();
  process.exit(0);
});

atem.on('error', (err) => { console.error(err.message); process.exit(1); });
setTimeout(() => { process.exit(1); }, 5000);
atem.connect('172.25.98.33');
