# Claude Notify

Mobile notification system for Claude Code. Get push notifications on your phone when Claude finishes tasks, needs approval for destructive commands, or asks questions — all while you're away from your desk.

![Claude Notify](assets/app_icon.png)

## Features

- **Task finish notifications** — Know when Claude completes a task without watching the terminal
- **Destructive command approval** — Approve or deny `rm`, `git push --force`, etc. from your phone
- **Custom text responses** — Send instructions back to Claude when denying a command
- **Live activity feed** — See what Claude is doing in real-time (files edited, commands run, search results)
- **Question replies** — Answer Claude's questions from your phone
- **30-second live feed** — After approving/denying, watch Claude's next actions stream in
- **Smart notifications** — Only fires when you're "Away from desk"; silent when you're at your computer
- **Dark theme UI** — Catppuccin Mocha-inspired dark interface

## Architecture

```
┌─────────────┐     hooks      ┌─────────────┐     FCM      ┌─────────────┐
│ Claude Code │ ──────────────> │  bridge.js  │ ───────────> │ Mobile App  │
│  (terminal) │                │  (Node.js)  │              │  (Flutter)  │
└─────────────┘                └──────┬──────┘              └──────┬──────┘
                                      │                            │
                                      └────── Firestore <─────────┘
```

- **Claude Code hooks** capture tool usage events (Stop, PreToolUse, PostToolUse)
- **bridge.js** writes events to Firestore and sends FCM push notifications
- **Flutter app** listens to Firestore for real-time updates and displays activity
- Notifications only send when user is marked "Away from desk" in the app

## Quick Setup (Single Command)

### Prerequisites

- Node.js 18+
- Claude Code installed
- Android phone

### 1. Install the mobile app

Get the `app-release.apk` from your team lead and install it on your Android phone. Open the app and sign in with Google.

### 2. Run the installer

Your team lead will share a `claude-notify-setup-1.0.0.tgz` file. Download it and run:

```bash
npx ./claude-notify-setup-1.0.0.tgz
```

That's it. The installer will:
- Ask for your Firebase UID (shown in the app after sign-in)
- Copy hook scripts to `~/.claude/hooks/`
- Install dependencies (firebase-admin, dotenv)
- Bundle the Firebase service account key
- Configure Claude Code settings

### 3. You're done

- Open the app and toggle **"Away from desk"** when you leave your computer
- Claude Code will send push notifications for task completions and permission requests
- Open any session in the app to see the live activity feed

## For Team Leads — Building the Installer

If you're distributing Claude Notify to your team, you need to build the installer package and the APK.

### Build the installer `.tgz`

The installer bundles all hooks + Firebase credentials into a single file:

```bash
cd installer
npm install
node build.js
```

This produces `claude-notify-setup-1.0.0.tgz` (~9 KB). It automatically finds your `serviceAccountKey.json` from:
- `installer/service-account-key.json`
- Project root `serviceAccountKey.json`
- `~/.claude/hooks/serviceAccountKey.json`

### Build the APK

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk` (~51 MB)

### Distribute to your team

Share two files internally (Slack, Google Drive, etc.) — **never commit credentials to a public repo**:

1. `app-release.apk` — Android app
2. `claude-notify-setup-1.0.0.tgz` — One-command hook installer

Sample message for your team:

> **Claude Notify — Mobile Notifications for Claude Code**
>
> 1. Install the APK on your phone, sign in with Google
> 2. Copy your UID from the home screen
> 3. Run: `npx ./claude-notify-setup-1.0.0.tgz`
> 4. Paste your UID when prompted — done!
> 5. Toggle "Away from desk" in the app when you leave

## Manual Setup

If you prefer to set things up manually:

### 1. Install hook dependencies

```bash
mkdir -p ~/.claude/hooks
cd ~/.claude/hooks
npm init -y
npm install firebase-admin dotenv
```

### 2. Copy hook files

Copy these files from `installer/hooks/` to `~/.claude/hooks/`:
- `bridge.js` — Firebase Admin bridge (FCM + Firestore)
- `stop.js` — Task finish / question detection
- `pre-tool-use.js` — Destructive command gating
- `post-tool-use.js` — Activity tracking
- `notification.js` — Notification passthrough (disabled to prevent spam)

### 3. Configure environment

Create `~/.claude/hooks/.env`:

```env
FIREBASE_SERVICE_ACCOUNT_PATH=/path/to/serviceAccountKey.json
FIREBASE_PROJECT_ID=your-project-id
CLAUDE_USER_UID=<your-uid-from-the-app>
```

### 4. Update Claude Code settings

Add hooks to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "node ~/.claude/hooks/stop.js" }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "node ~/.claude/hooks/pre-tool-use.js" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "hooks": [
          { "type": "command", "command": "node ~/.claude/hooks/post-tool-use.js" }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          { "type": "command", "command": "node ~/.claude/hooks/notification.js" }
        ]
      }
    ]
  }
}
```

## How It Works

### Notification Flow

| Scenario | At Desk | Away |
|----------|---------|------|
| Task finishes | No notification | Push notification |
| Destructive command (`rm`, `git push --force`) | Auto-allow | Phone approval required |
| Non-destructive command | Auto-allow | Auto-allow |
| Claude asks a question | No notification | Push + reply from phone |
| Progress updates | No notification | Push notification |

### Hook Events

- **Stop** — Fires when Claude finishes responding. Detects if the last message is a question (routes to phone for reply) or a completion (sends finish notification).
- **PreToolUse** — Fires before each tool call. Gates destructive Bash commands through phone approval when away. Auto-allows everything else so Claude keeps working.
- **PostToolUse** — Fires after each tool call. Captures activity (commands run, files edited, search results) as markdown-formatted events in Firestore for the live feed.
- **Notification** — Disabled (just exits). Claude Code fires these too frequently; task notifications are handled by the Stop hook instead.

### Activity Feed

The PostToolUse hook captures tool usage and writes markdown-formatted events to Firestore:

- **Bash** — Shows the command and output
- **Edit** — Shows the file path and diff
- **Read** — Shows the file path
- **Write** — Shows the file path
- **Glob/Grep** — Shows the search pattern and matches

These appear in the session detail screen as a dark terminal-style timeline.

## Project Structure

```
claude_notify_app/
├── lib/                          # Flutter app source
│   ├── app.dart                  # App root, routing, FCM handling
│   ├── theme.dart                # Dark theme (Catppuccin Mocha)
│   ├── models/
│   │   ├── session.dart
│   │   └── event.dart
│   ├── screens/
│   │   ├── login_screen.dart
│   │   ├── home_screen.dart
│   │   ├── session_detail_screen.dart
│   │   ├── permission_request_screen.dart
│   │   └── question_reply_screen.dart
│   ├── services/
│   │   ├── auth_service.dart
│   │   ├── firestore_service.dart
│   │   └── fcm_service.dart
│   └── widgets/
│       ├── presence_toggle.dart
│       ├── session_card.dart
│       └── event_tile.dart
├── installer/                    # Installer & build tools
│   ├── setup.js                  # Interactive installer script
│   ├── build.js                  # Builds .tgz package for distribution
│   ├── package.json
│   └── hooks/                    # Cross-platform JS hooks
│       ├── bridge.js
│       ├── stop.js
│       ├── pre-tool-use.js
│       ├── post-tool-use.js
│       └── notification.js
├── android/
├── ios/
├── firebase/
│   ├── firestore.rules
│   └── firestore.indexes.json
└── assets/
    └── app_icon.png
```

## Firebase Setup (Admin Only)

If you're setting up a new Firebase project:

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Authentication** (Google sign-in provider)
3. Enable **Cloud Firestore**
4. Enable **Cloud Messaging**
5. Add an Android app and download `google-services.json` → place in `android/app/`
6. Run `flutterfire configure` to generate `lib/firebase_options.dart`
7. Generate a service account key (Project Settings > Service Accounts) → used by the installer
8. Deploy Firestore security rules from `firebase/firestore.rules`

> **Note:** `google-services.json`, `firebase_options.dart`, and `serviceAccountKey.json` are gitignored. Each developer/admin must configure these locally.

## Tech Stack

- **Mobile App**: Flutter + Firebase (Auth, Firestore, Cloud Messaging)
- **Hooks**: Node.js + Firebase Admin SDK (cross-platform, no bash/python dependencies)
- **Notifications**: FCM (notification+data messages) + flutter_local_notifications
- **UI**: Material 3, Catppuccin Mocha dark theme
- **State**: Firestore real-time listeners
- **Installer**: Single `.tgz` package via `npm pack`
