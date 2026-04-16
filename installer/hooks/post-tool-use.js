#!/usr/bin/env node
/**
 * post-tool-use.js — Captures tool activity and writes to Firestore
 * Creates markdown-formatted activity events for the mobile app timeline
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

const toolName = data.tool_name || '';
if (!toolName) process.exit(0);

const sessionId = data.session_id || 'unknown';
const project = process.env.CLAUDE_PROJECT_DIR
  ? path.basename(process.env.CLAUDE_PROJECT_DIR)
  : path.basename(process.cwd());
const sessionKey = `${project}_${sessionId}`;

const inp = typeof data.tool_input === 'object' ? data.tool_input : {};
let outputText = '';
if (typeof data.tool_output === 'string') {
  outputText = data.tool_output;
} else if (typeof data.tool_output === 'object' && data.tool_output) {
  outputText = data.tool_output.output || data.tool_output.content || JSON.stringify(data.tool_output);
}
if (outputText.length > 500) outputText = outputText.slice(0, 500) + '...';

// Build markdown based on tool type
let lines = [];

switch (toolName) {
  case 'Bash': {
    const cmd = (inp.command || '').slice(0, 200);
    lines.push(`**$ ${cmd}**`);
    if (outputText.trim()) {
      lines.push('```', outputText.trim(), '```');
    }
    break;
  }
  case 'Read': {
    lines.push(`**Read** \`${inp.file_path || ''}\``);
    break;
  }
  case 'Write': {
    lines.push(`**Created** \`${inp.file_path || ''}\``);
    break;
  }
  case 'Edit': {
    const filePath = inp.file_path || '';
    const old = (inp.old_string || '').slice(0, 100);
    const newStr = (inp.new_string || '').slice(0, 100);
    lines.push(`**Edited** \`${filePath}\``);
    if (old) {
      lines.push('```diff', `- ${old}`, `+ ${newStr}`, '```');
    }
    break;
  }
  case 'Glob': {
    lines.push(`**Search files** \`${inp.pattern || ''}\``);
    if (outputText.trim()) {
      const matches = outputText.trim().split('\n').slice(0, 5);
      lines.push('```', ...matches);
      const total = outputText.trim().split('\n').length;
      if (total > 5) lines.push(`... +${total - 5} more`);
      lines.push('```');
    }
    break;
  }
  case 'Grep': {
    lines.push(`**Grep** \`${inp.pattern || ''}\``);
    if (outputText.trim()) {
      const matches = outputText.trim().split('\n').slice(0, 5);
      lines.push('```', ...matches);
      const total = outputText.trim().split('\n').length;
      if (total > 5) lines.push(`... +${total - 5} more`);
      lines.push('```');
    }
    break;
  }
  case 'Agent': {
    const desc = (inp.description || inp.prompt || '').slice(0, 200);
    lines.push(`**Agent** ${desc}`);
    break;
  }
  default: {
    lines.push(`**${toolName}**`);
    if (outputText.trim()) {
      lines.push('```', outputText.trim().slice(0, 200), '```');
    }
  }
}

const markdown = lines.join('\n');

// Write activity event to Firestore
try {
  const escaped = Buffer.from(markdown).toString('base64');
  // Pass markdown via env var to avoid shell escaping issues
  execSync(
    `${BRIDGE} activity "${sessionKey}" "${project}" "${markdown.replace(/"/g, '\\"').replace(/`/g, '\\`').replace(/\$/g, '\\$')}"`,
    { encoding: 'utf8', timeout: 10000, env: { ...process.env } }
  );
} catch {}

process.exit(0);
