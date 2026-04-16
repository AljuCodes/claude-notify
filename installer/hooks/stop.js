#!/usr/bin/env node
/**
 * stop.js — Called by Claude Code on Stop event
 * Detects finish vs question, routes to bridge.js
 * Cross-platform (no bash/python dependencies)
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

const sessionId = data.session_id || 'unknown';
const transcriptPath = data.transcript_path || '';

// Derive project name
const project = process.env.CLAUDE_PROJECT_DIR
  ? path.basename(process.env.CLAUDE_PROJECT_DIR)
  : path.basename(process.cwd());

const sessionKey = `${project}_${sessionId}`;

// Extract last assistant message from transcript
let lastMsg = '';
if (transcriptPath && fs.existsSync(transcriptPath)) {
  try {
    const transcript = JSON.parse(fs.readFileSync(transcriptPath, 'utf8'));
    const messages = Array.isArray(transcript) ? transcript : (transcript.messages || []);
    for (let i = messages.length - 1; i >= 0; i--) {
      const msg = messages[i];
      if (msg.role !== 'assistant') continue;
      const content = msg.content;
      if (typeof content === 'string' && content.trim()) {
        lastMsg = content.trim();
        break;
      }
      if (Array.isArray(content)) {
        for (let j = content.length - 1; j >= 0; j--) {
          if (content[j].type === 'text' && content[j].text && content[j].text.trim()) {
            lastMsg = content[j].text.trim();
            break;
          }
        }
        if (lastMsg) break;
      }
    }
  } catch {}
}

// Detect question: last message ends with '?'
const trimmed = lastMsg.replace(/\s+$/, '');

if (trimmed.endsWith('?')) {
  // Question mode
  try {
    const escaped = lastMsg.replace(/"/g, '\\"').slice(0, 500);
    const eventId = execSync(
      `${BRIDGE} question "${sessionKey}" "${project}" "${escaped}"`,
      { encoding: 'utf8', timeout: 15000 }
    ).trim();

    if (eventId) {
      const result = execSync(
        `${BRIDGE} poll-question "${sessionKey}" "${eventId}"`,
        { encoding: 'utf8', timeout: 3600000 }
      ).trim();

      if (result && process.platform === 'darwin') {
        // macOS: inject reply via osascript
        try {
          const safeReply = result.replace(/"/g, '\\"');
          execSync(`osascript -e 'tell application "System Events" to keystroke "${safeReply}"' -e 'tell application "System Events" to keystroke return'`, { timeout: 5000 });
        } catch {}
      }
    }
  } catch {}
} else {
  // Finished
  const msg = lastMsg || 'Task finished';
  const escaped = msg.replace(/"/g, '\\"').slice(0, 500);
  try {
    execSync(
      `${BRIDGE} notify "${sessionKey}" "${project}" "${escaped}" finished`,
      { encoding: 'utf8', timeout: 15000 }
    );
  } catch {}
}

process.exit(0);
