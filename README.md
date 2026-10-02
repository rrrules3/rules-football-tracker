# Rules' Football Tracker

A macOS menu bar app for live football scores, standings, and stats — powered by [API-Football](https://www.api-football.com).

## What it does

- **Menu bar overlay** — live scores at a glance without leaving whatever you're doing
- **Today view** — full schedule for your favourite leagues and teams
- **Live Now** — all currently live matches with live score updates
- **Standings** — league tables and World Cup group stages with flag support
- **Season Stats** — top scorers, assists, and ratings
- **Knockout** — bracket view for cup competitions
- **Settings** — manage favourite leagues and teams, appearance

---

## Prerequisites

- macOS 13 or later
- Xcode 15 or later
- Node.js 18+ and npm
- An [API-Football](https://www.api-football.com) account (free tier works for testing)

---

## Setup

### 1. Clone the repo

```bash
git clone https://github.com/rrrules3/rules-football-tracker.git
cd rules-football-tracker
```

### 2. Set up the server

The app talks to a local Node.js proxy server that holds your API key and caches responses.

```bash
cd Server
npm install
cp .env.example .env
```

Open `.env` and fill in your values:

```
API_FOOTBALL_KEY=your_key_from_api-football.com
APP_SECRET=any_random_string_you_choose
PORT=3000
```

> **Tip:** generate a secure `APP_SECRET` with:
> ```bash
> node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
> ```

Start the server:

```bash
npm start
```

You should see:
```
⚽ Football proxy server running on http://localhost:3000
   API key: ✓ set
   App secret: ✓ set
```

### 3. Set up the Xcode project

Open `Rules' Football Tracker.xcodeproj` in Xcode.

**Create your local secrets file:**

```bash
cp "Testing overlay football/Config/Secrets.xcconfig" \
   "Testing overlay football/Config/Secrets.local.xcconfig"
```

Open `Secrets.local.xcconfig` and set `APP_SECRET` to the same value you used in `Server/.env`:

```
APP_SECRET = your_app_secret_here
```

**Wire up the xcconfig in Xcode:**

1. Click the project (blue icon) in the navigator → select the **project** under PROJECT → **Info** tab
2. Under **Configurations**, set both Debug and Release to `Secrets.local.xcconfig`

**Add `APP_SECRET` to Info.plist:**

1. Select the target → **Info** tab → **Custom macOS Application Target Properties**
2. Add a new row: Key = `APP_SECRET`, Type = `String`, Value = `$(APP_SECRET)`

### 4. Run the app

Make sure the server is running (`npm start` in the Server folder), then hit **Run** in Xcode (⌘R).

The app appears as a football icon in your menu bar.

---

## Project structure

```
Rules' Football Tracker/
├── Server/                  # Node.js proxy server
│   ├── index.js             # Express app with caching + auth
│   ├── .env.example         # Template — copy to .env and fill in
│   └── package.json
└── Testing overlay football/
    ├── AppDelegate.swift    # Menu bar setup, window management
    ├── MenuBarView.swift    # Popover overlay UI
    ├── Models/              # Codable API response models
    ├── Networking/          # APIClient, APIEndpoints
    ├── Services/            # MatchMonitor, OverlayManager, etc.
    ├── Views/               # Main app views (SwiftUI)
    └── Config/
        └── Secrets.xcconfig # Template for local secrets
```

---

## Notes

- `Secrets.local.xcconfig` and `Server/.env` are git-ignored — never commit them
- The server must be running locally for the app to fetch data
- For production use, deploy the server to a host like [Railway](https://railway.app) and update `APIEndpoints.baseURL` in `APIEndpoints.swift`
