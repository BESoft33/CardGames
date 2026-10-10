# Setting up the online services

Offline play needs none of this. Sync, sign-in and confirmed coins need all
of it. Steps 1 to 5 are done once, by the project owner, in web consoles
that only the owner can reach. Nothing on this page is a password, except
where it says so: keep those out of the repository and out of chat
(AGENTS.md §12).

The Supabase project is `https://ylvwsollcphtjvzvtpjq.supabase.co`. The
app's ID is `com.madhugames.cardgames` on Android and iOS.

Google sign-in needs only steps 1, 3 and 5; the game server (steps 2 and
4) can come later. Until then the app says that coins sync once the
server is set up, and a first sign-up's bonus is paid the first time the
server sees the account.

## 1. Supabase: sign-in settings

In the Supabase dashboard, open the project, then **Authentication**:

1. **Sign In / Providers**: turn on **Allow anonymous sign-ins**. Every
   guest gets an anonymous account the first time it goes online
   (AGENTS.md §10).
2. Same page: turn on **Allow manual linking**. Without it, a guest cannot
   add Google to its own account.
3. **Providers, Google**: turn it on. In **Client IDs**, enter the Web
   client ID from step 3, then a comma, then the iOS client ID. Enter the
   Web client's secret where it asks for one. Turn on **Skip nonce check**,
   which iOS sign-in needs.

Supabase recommends a CAPTCHA for anonymous sign-ins. It belongs to the
hardening milestone (10).

## 2. Supabase: the database

The tables, row-level security and grants are in
`supabase/migrations/`. Apply them once, and again whenever a new
migration is added:

```bash
npx supabase login
npx supabase link --project-ref ylvwsollcphtjvzvtpjq
npx supabase db push
```

`link` asks for the database password. Alternatively, paste each migration
file, oldest first, into the dashboard's **SQL Editor** and run it.

## 3. Google Cloud: sign-in clients

In the Google Cloud console, choose or create a project, then **APIs &
Services**:

1. **OAuth consent screen**: fill it in, with the app name card.games and a
   link to the privacy policy (milestone 10).
2. **Credentials, Create credentials, OAuth client ID**, three times:
   - **Web application**. No origins are needed. Its client ID and secret
     go to Supabase (step 1), and its client ID to the app
     (`GOOGLE_WEB_CLIENT_ID`).
   - **Android**: package name `com.madhugames.cardgames`, plus the SHA-1
     fingerprint of each key the app is signed with. Builds on a
     development PC use its debug key (`keytool -list -v -keystore
     ~/.android/debug.keystore`, password `android`). On the owner's PC
     (made 2026-10-09) it is
     `EA:5C:38:83:38:44:12:C4:79:4D:AF:E0:EC:48:80:62:42:78:26:BE`.
     Releases on Google Play use the Play app signing key, whose SHA-1 is
     in the Play Console; add it as another Android client then.
   - **iOS**: bundle ID `com.madhugames.cardgames`. Its client ID goes to
     Supabase (step 1) and to the app (`GOOGLE_IOS_CLIENT_ID`).
3. iOS also needs the reversed iOS client ID as a URL scheme in
   `apps/mobile/ios/Runner/Info.plist`, under `CFBundleURLTypes`, for
   example `com.googleusercontent.apps.1234-abcd`. Add it once the client
   exists; it needs a Mac to build and test.

## 4. The game server

The server (`server/`) checks every uploaded match by replaying it, and
keeps the coin ledger. It is a small container, and any host that runs
containers behind HTTPS will do. Build it from the repository root:

```bash
docker build -f server/Dockerfile -t cardgames-server .
```

It reads its settings from environment variables:

| Variable | Value |
|---|---|
| `DATABASE_URL` | Supabase dashboard, **Connect**, **Session pooler** connection string, with the database password filled in and `?sslmode=require` added. **This is a password: keep it in the host's secret settings.** |
| `SUPABASE_URL` | `https://ylvwsollcphtjvzvtpjq.supabase.co` |
| `SUPABASE_PUBLISHABLE_KEY` | The project's publishable (anon) key. |
| `PORT` | Set by most hosts; 8080 otherwise. |

The host must serve it over HTTPS; the app refuses plain HTTP. The server
never needs the Supabase service-role key. Where to host it is still open
(AGENTS.md §17; docs/decisions.md D-029).

## 5. The app

Copy `apps/mobile/env/dev.example.json` to `apps/mobile/env/dev.json`
(which stays out of the repository), fill in the values, and run. Leave
`SERVER_URL` empty until the game server runs:

```bash
cd apps/mobile
flutter run --dart-define-from-file=env/dev.json
```

Without the file the app still runs, offline only, and says so in
Settings.

## Checking the backend on a development PC

With Docker and Node.js installed:

```bash
tool/backend_check.sh
```

It starts a local Supabase stack, applies the migrations to a fresh local
database, and runs the server and sign-in tests against it, with real
Supabase tokens, the real database and its row-level security. It uses
only the local stack's development keys, never the real project's. Stop
the stack with `npx supabase stop`.
