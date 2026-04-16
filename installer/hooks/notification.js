#!/usr/bin/env node
/**
 * notification.js — Called by Claude Code on Notification event
 * We do NOT forward these to the phone — they fire too frequently and cause spam.
 * Task-finish notifications are handled by stop.js.
 * Permission requests are handled by pre-tool-use.js.
 */

process.exit(0);
