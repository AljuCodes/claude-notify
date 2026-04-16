#!/usr/bin/env node
/**
 * Claude Notify — Firebase Admin bridge
 *
 * Modes (passed as first CLI argument):
 *   check-desk        → prints "true"/"false", exits 0
 *   notify            → writes finished/notification event, FCM if away, exits 0
 *   permission-request → writes pending event, FCM if away, prints eventId, exits 0
 *   poll-permission   → polls event every 2 s up to 10 min; exits 0=approved 2=denied 1=timeout
 *   question          → writes pending question event, FCM if away, prints eventId, exits 0
 *   poll-question     → polls event every 2 s up to 1 hr; prints reply; exits 0=reply 1=timeout
 *   activity          → writes activity event to Firestore, exits 0
 */

require('dotenv').config({ path: __dirname + '/.env' });
const admin = require('firebase-admin');
const fs = require('fs');

// ─── Init ───────────────────────────────────────────────────────────────────

const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
const projectId = process.env.FIREBASE_PROJECT_ID;
const userId = process.env.CLAUDE_USER_UID;

if (!serviceAccountPath || !projectId || !userId) {
  console.error('[bridge] Missing env vars. Check ~/.claude/hooks/.env');
  process.exit(1);
}

if (!fs.existsSync(serviceAccountPath)) {
  console.error(`[bridge] serviceAccountKey.json not found at: ${serviceAccountPath}`);
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccountPath),
  projectId,
});

const db = admin.firestore();
const messaging = admin.messaging();

// ─── Helpers ─────────────────────────────────────────────────────────────────

async function isAtDesk() {
  try {
    const doc = await db.doc(`users/${userId}/status/presence`).get();
    return doc.exists ? doc.data().isAtDesk === true : false;
  } catch {
    return false; // assume away (safe default)
  }
}

async function getFcmToken() {
  try {
    const doc = await db.doc(`users/${userId}`).get();
    return doc.exists ? doc.data().fcmToken || null : null;
  } catch {
    return null;
  }
}

async function sendFcm(token, title, body, data = {}) {
  if (!token) return;
  try {
    await messaging.send({
      token,
      notification: { title, body },
      data: { ...data, userId, title, body, sentAt: Date.now().toString() },
      android: {
        priority: 'high',
        ttl: 0,
        notification: {
          icon: 'ic_notification',
          color: '#3F51B5',
          defaultSound: true,
          channelId: 'claude_notify_foreground',
        },
      },
      apns: {
        headers: { 'apns-priority': '10' },
        payload: { aps: { alert: { title, body }, sound: 'default' } },
      },
    });
  } catch (e) {
    console.error('[bridge] FCM send error:', e.message);
  }
}

function newEventId() {
  return Date.now().toString(36) + Math.random().toString(36).slice(2, 7);
}

function argv(n) {
  return process.argv[n + 3] || '';
}

// ─── Modes ───────────────────────────────────────────────────────────────────

async function checkDesk() {
  const atDesk = await isAtDesk();
  process.stdout.write(atDesk ? 'true' : 'false');
  process.exit(0);
}

async function notify() {
  const sessionId = argv(0);
  const project   = argv(1);
  const message   = argv(2);
  const type      = argv(3) || 'finished';

  const eventId = newEventId();

  await db.doc(`sessions/${sessionId}`).set({
    project, userId,
    status: type === 'finished' ? 'finished' : 'running',
    lastActivity: admin.firestore.FieldValue.serverTimestamp(),
    workingDir: process.env.PWD || '',
  }, { merge: true });

  await db.doc(`sessions/${sessionId}/events/${eventId}`).set({
    type, message, status: 'resolved',
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  const atDesk = await isAtDesk();
  if (!atDesk) {
    const token = await getFcmToken();
    const title = type === 'finished' ? `✅ ${project} — Task finished` : `📢 ${project}`;
    await sendFcm(token, title, message.slice(0, 200), { screen: 'session', sessionId });
  }

  process.exit(0);
}

async function permissionRequest() {
  const sessionId    = argv(0);
  const project      = argv(1);
  const toolName     = argv(2);
  const toolInputB64 = argv(3);
  const message      = argv(4) || `Tool: ${toolName}`;

  let toolInput = {};
  try { toolInput = JSON.parse(Buffer.from(toolInputB64, 'base64').toString()); } catch {}

  const eventId = newEventId();

  await db.doc(`sessions/${sessionId}`).set({
    project, userId,
    status: 'waiting_permission',
    lastActivity: admin.firestore.FieldValue.serverTimestamp(),
    workingDir: process.env.PWD || '',
  }, { merge: true });

  await db.doc(`sessions/${sessionId}/events/${eventId}`).set({
    type: 'permission_request', message,
    tool: toolName, toolInput,
    decision: null, status: 'pending',
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  const atDesk = await isAtDesk();
  if (!atDesk) {
    const token = await getFcmToken();
    await sendFcm(token, `🔐 ${project} — Permission required`, `Allow ${toolName}?`, {
      screen: 'permission', sessionId, eventId,
    });
  }

  process.stdout.write(eventId);
  process.exit(0);
}

async function pollPermission() {
  const sessionId  = argv(0);
  const eventId    = argv(1);
  const TIMEOUT_MS = 10 * 60 * 1000;
  const POLL_MS    = 2000;

  const eventRef = db.doc(`sessions/${sessionId}/events/${eventId}`);
  const deadline = Date.now() + TIMEOUT_MS;

  while (Date.now() < deadline) {
    await new Promise(r => setTimeout(r, POLL_MS));
    const snap = await eventRef.get();
    if (!snap.exists) { process.exit(2); }
    const data = snap.data();
    if (data.status === 'resolved') {
      await db.doc(`sessions/${sessionId}`).set({ status: 'running' }, { merge: true });
      if (data.decision !== 'approved' && data.response) {
        process.stdout.write(data.response);
      }
      process.exit(data.decision === 'approved' ? 0 : 2);
    }
  }

  await eventRef.set({ decision: 'denied', status: 'resolved' }, { merge: true });
  await db.doc(`sessions/${sessionId}`).set({ status: 'running' }, { merge: true });
  const token = await getFcmToken();
  await sendFcm(token, '⏱ Permission timed out', 'Auto-denied after 10 minutes', {
    screen: 'session', sessionId,
  });
  process.exit(2);
}

async function question() {
  const sessionId = argv(0);
  const project   = argv(1);
  const message   = argv(2);

  const eventId = newEventId();

  await db.doc(`sessions/${sessionId}`).set({
    project, userId,
    status: 'waiting_input',
    lastActivity: admin.firestore.FieldValue.serverTimestamp(),
    workingDir: process.env.PWD || '',
  }, { merge: true });

  await db.doc(`sessions/${sessionId}/events/${eventId}`).set({
    type: 'question', message,
    response: null, status: 'pending',
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  const atDesk = await isAtDesk();
  if (!atDesk) {
    const token = await getFcmToken();
    await sendFcm(token, `❓ ${project} — Question`, message.slice(0, 200), {
      screen: 'question', sessionId, eventId,
    });
  }

  process.stdout.write(eventId);
  process.exit(0);
}

async function pollQuestion() {
  const sessionId  = argv(0);
  const eventId    = argv(1);
  const TIMEOUT_MS = 60 * 60 * 1000;
  const POLL_MS    = 2000;

  const eventRef = db.doc(`sessions/${sessionId}/events/${eventId}`);
  const deadline = Date.now() + TIMEOUT_MS;

  while (Date.now() < deadline) {
    await new Promise(r => setTimeout(r, POLL_MS));
    const snap = await eventRef.get();
    if (!snap.exists) { process.exit(1); }
    const data = snap.data();
    if (data.status === 'resolved' && data.response) {
      process.stdout.write(data.response);
      await db.doc(`sessions/${sessionId}`).set({ status: 'running' }, { merge: true });
      process.exit(0);
    }
  }

  process.exit(1);
}

async function activity() {
  const sessionId = argv(0);
  const project   = argv(1);
  const markdown  = argv(2);

  const eventId = newEventId();

  await db.doc(`sessions/${sessionId}`).set({
    project, userId,
    status: 'running',
    lastActivity: admin.firestore.FieldValue.serverTimestamp(),
    workingDir: process.env.PWD || '',
  }, { merge: true });

  await db.doc(`sessions/${sessionId}/events/${eventId}`).set({
    type: 'activity', message: markdown, status: 'resolved',
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  process.exit(0);
}

// ─── Dispatch ────────────────────────────────────────────────────────────────

const mode = process.argv[2];
switch (mode) {
  case 'check-desk':         checkDesk();         break;
  case 'notify':             notify();            break;
  case 'permission-request': permissionRequest(); break;
  case 'poll-permission':    pollPermission();    break;
  case 'question':           question();          break;
  case 'poll-question':      pollQuestion();      break;
  case 'activity':           activity();          break;
  default:
    console.error(`[bridge] Unknown mode: ${mode}`);
    console.error('Usage: node bridge.js <mode> [args...]');
    process.exit(1);
}
