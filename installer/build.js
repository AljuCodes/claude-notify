#!/usr/bin/env node
/**
 * Builds a self-contained installer .tgz that includes:
 *   - setup.js (installer script)
 *   - hooks/*.js (all hook files)
 *   - service-account-key.json (Firebase credentials)
 *
 * Output: claude-notify-setup-<version>.tgz
 *
 * Share this file internally. Teammates install with:
 *   npx <path-to>/claude-notify-setup-1.0.0.tgz
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const DIR = __dirname;
const SERVICE_KEY_PATHS = [
  path.join(DIR, 'service-account-key.json'),
  path.join(DIR, '..', 'serviceAccountKey.json'),
  path.join(require('os').homedir(), '.claude', 'hooks', 'serviceAccountKey.json'),
];

const c = {
  reset: '\x1b[0m', bold: '\x1b[1m', green: '\x1b[32m',
  red: '\x1b[31m', yellow: '\x1b[33m', dim: '\x1b[2m',
};

console.log(`\n${c.bold}  Building Claude Notify installer...${c.reset}\n`);

// Find service account key
let keyPath = null;
for (const p of SERVICE_KEY_PATHS) {
  if (fs.existsSync(p)) { keyPath = p; break; }
}

if (!keyPath) {
  console.log(`${c.red}✗${c.reset} Service account key not found. Looked in:`);
  SERVICE_KEY_PATHS.forEach(p => console.log(`  - ${p}`));
  console.log(`\nPlace your serviceAccountKey.json in: ${DIR}/service-account-key.json`);
  process.exit(1);
}

// Copy key into installer dir
const dest = path.join(DIR, 'service-account-key.json');
if (keyPath !== dest) {
  fs.copyFileSync(keyPath, dest);
}
console.log(`${c.green}✓${c.reset} Service account key bundled`);

// Verify all hook files exist
const hookFiles = ['bridge.js', 'stop.js', 'pre-tool-use.js', 'post-tool-use.js', 'notification.js'];
for (const f of hookFiles) {
  const p = path.join(DIR, 'hooks', f);
  if (!fs.existsSync(p)) {
    console.log(`${c.red}✗${c.reset} Missing hook: hooks/${f}`);
    process.exit(1);
  }
}
console.log(`${c.green}✓${c.reset} All hook files present`);

// Run npm pack
try {
  const out = execSync('npm pack', { cwd: DIR, encoding: 'utf8' }).trim();
  const tgzPath = path.join(DIR, out);
  const size = (fs.statSync(tgzPath).size / 1024).toFixed(0);

  // Clean up copied key if it wasn't originally there
  if (keyPath !== dest) {
    fs.unlinkSync(dest);
  }

  console.log(`${c.green}✓${c.reset} Package built: ${out} (${size} KB)`);
  console.log(`\n${c.bold}  Share this file with your team.${c.reset}`);
  console.log(`${c.dim}  They install with:${c.reset}`);
  console.log(`\n    npx ${out}\n`);
} catch (e) {
  console.log(`${c.red}✗${c.reset} npm pack failed: ${e.message}`);
  process.exit(1);
}
