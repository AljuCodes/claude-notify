#!/usr/bin/env node
/**
 * pre-tool-use.js — Called by Claude Code on PreToolUse event
 * Cross-platform (no bash/python dependencies)
 *
 * Behavior:
 *   At desk     → auto-allow everything
 *   Away + destructive → phone approval required
 *   Away + non-destructive → auto-allow
 *
 * Exit codes:  0 = allow   2 = block
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const HOOKS_DIR = __dirname;
const BRIDGE = `node "${path.join(HOOKS_DIR, 'bridge.js')}"`;

// Read stdin
let input = '';
try {
  input = fs.readFileSync(0, 'utf8');
} catch { process.exit(0); }

let data = {};
try { data = JSON.parse(input); } catch { process.exit(0); }

const toolName = data.tool_name || '';

// Non-Bash tools: always allow
if (toolName !== 'Bash') {
  process.exit(0);
}

const toolInput = typeof data.tool_input === 'object' ? data.tool_input : {};
const command = toolInput.command || '';

// Detect destructive patterns
function isDestructive(cmd) {
  if (/(?:^|[;&|\s])(?:rm|rmdir|unlink|shred)\s/.test(cmd)) return true;
  if (/(?:DROP\s+(?:TABLE|DATABASE|SCHEMA|INDEX)|TRUNCATE\s+TABLE)/i.test(cmd)) return true;
  if (/git\s+(?:branch\s+-[Dd]|push\s+.*--force|reset\s+--hard)|git\s+clean\s+-[a-z]*f/.test(cmd)) return true;
  return false;
}

// Check at desk
let atDesk = false;
try {
  const result = execSync(`${BRIDGE} check-desk`, { encoding: 'utf8', timeout: 10000 }).trim();
  atDesk = result === 'true';
} catch {
  atDesk = false;
}

// At desk → allow everything
if (atDesk) {
  process.exit(0);
}

// Away + not destructive → auto-allow
if (!isDestructive(command)) {
  process.exit(0);
}

// ── Away + destructive → phone approval ──

const sessionId = data.session_id || 'unknown';
const project = process.env.CLAUDE_PROJECT_DIR
  ? path.basename(process.env.CLAUDE_PROJECT_DIR)
  : path.basename(process.cwd());
const sessionKey = `${project}_${sessionId}`;

const toolInputB64 = Buffer.from(JSON.stringify(toolInput)).toString('base64');
const shortCmd = command.slice(0, 120);
const msg = `Allow: ${shortCmd}`;

let eventId = '';
try {
  eventId = execSync(
    `${BRIDGE} permission-request "${sessionKey}" "${project}" "Bash" "${toolInputB64}" "${msg.replace(/"/g, '\\"')}"`,
    { encoding: 'utf8', timeout: 15000 }
  ).trim();
} catch {}

if (!eventId) {
  console.error('Could not reach notification bridge. Blocked for safety.');
  process.exit(2);
}

// Poll for phone response
try {
  const response = execSync(
    `${BRIDGE} poll-permission "${sessionKey}" "${eventId}"`,
    { encoding: 'utf8', timeout: 610000 }
  ).trim();
  // If we get here, it was approved (exit 0 from bridge)
  process.exit(0);
} catch (e) {
  // Bridge exited with code 2 (denied)
  const output = (e.stdout || '').toString().trim();
  if (output) {
    console.error(`Denied — user instruction: ${output}`);
  } else {
    console.error('Denied via mobile app.');
  }
  process.exit(2);
}
