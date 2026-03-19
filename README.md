# Household Chore Tracker

A household chore tracker web app and iOS app for Maggie and Yuch. Tracks chores with a reward-based balance system, calendar events, and a shared multi-currency ledger (USD/CAD).

## Web App (Flask)

### Setup

```bash
cp .env.example .env  # Add your secrets
docker compose up -d --build
```

Runs on port 7990. Uses Google OAuth for authentication.

### Features

- Log chores with configurable tasks, rewards, and frequency limits
- Calendar with drag-and-drop chore rescheduling
- Shared USD/CAD ledger
- Google OAuth with email whitelist

## iOS App (SwiftUI)

Located in `ios/ChoreTracker/`. Connects to the Flask backend via JSON API (`/api/v1/`).

### Building in Xcode

1. Open `ios/ChoreTracker/ChoreTracker.xcodeproj` in Xcode
2. Select your device as the build target
3. Set your signing team in **Signing & Capabilities**
4. Enable **Developer Mode** on your device: Settings > Privacy & Security > Developer Mode
5. Build and run (Cmd+R)

### App Transport Security (required for HTTP)

The app connects to the server over HTTP. iOS blocks HTTP by default, so you must add an App Transport Security exception:

1. Select the **ChoreTracker** project in the Xcode sidebar
2. Select the **ChoreTracker** target
3. Go to the **Info** tab
4. In **Custom iOS Target Properties**, hover over any row and click the **+** button
5. Add **App Transport Security Settings** (type: Dictionary)
6. Expand it, click **+** again
7. Add **Allow Arbitrary Loads** and set the value to **YES**

Without this, all API calls to the Flask server will fail with a "resource could not be loaded because the App Transport Security policy requires the use of a secure connection" error.

### Authentication

The app uses Google Sign-In via a web-based OAuth flow:

1. Tapping "Sign in with Google" opens a Safari sheet
2. Google OAuth is handled by the Flask server
3. On success, the server redirects to `choretracker://auth?token=...&email=...`
4. The app captures the token and stores it in Keychain

### Features

- **Home**: Balance display, weekly calendar with events/chores, log chores, add events
- **Ledger**: USD/CAD transaction tracking
- **Settings**: Server URL configuration, task management, sign out

## API

The iOS app communicates via `/api/v1/` endpoints. All endpoints (except auth) require `Authorization: Bearer <token>` header.

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/auth/login` | Start Google OAuth flow |
| GET | `/api/v1/balance` | Get chore balance |
| GET | `/api/v1/tasks` | List tasks |
| POST | `/api/v1/tasks` | Create task |
| DELETE | `/api/v1/tasks/<id>` | Delete task |
| POST | `/api/v1/chores` | Log chore |
| POST | `/api/v1/chores/custom` | Log custom chore |
| DELETE | `/api/v1/chores/<id>` | Delete chore |
| POST | `/api/v1/chores/<id>/move` | Move chore to new date |
| GET | `/api/v1/history` | Paginated chore history |
| GET | `/api/v1/events` | List events |
| POST | `/api/v1/events` | Create event |
| PUT | `/api/v1/events/<id>` | Update event |
| DELETE | `/api/v1/events/<id>` | Delete event |
| GET | `/api/v1/ledger/<currency>` | Get transactions + total |
| POST | `/api/v1/ledger/<currency>` | Add transaction |
| DELETE | `/api/v1/ledger/<currency>/<id>` | Delete transaction |
