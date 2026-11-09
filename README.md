# Cost Alert

Cost-change alert board for **Muhammed Bu Matar Trading**.

**Live:** https://fayisc.github.io/cost-alert/

- **Admin** (office): scan or type a product, enter the new cost, save.
- **Staff** (counter, other office, phone): full-screen board that sounds an alarm and shows a pop-up — old cost → new cost — until they press **SEEN**.
- Works on any Wi-Fi or network; only internet is needed.

## How it's built
| Part | Where |
|---|---|
| Website | `index.html` — one file, hosted on GitHub Pages |
| Database | Supabase (project `nr-warehouse`, tables starting with `ca_`) |
| Database setup | `supabase/cost_alert_setup.sql` (run once in Supabase SQL Editor) |

The Supabase key in `index.html` is the public *publishable* key. It is safe to publish: the tables are locked and every action goes through functions that check the login.

## First use
1. Open the live link in Chrome or Safari (not inside an app preview).
2. First-time setup: create the admin login (6+ character password).
3. Admin page → **Logins** → add staff.
4. On each staff screen: log in → **START BOARD** (plays a sound check) → keep the volume up.

## Releasing a new version
1. Make the change in `index.html`.
2. Bump `APP_VERSION` in `index.html` **and** `version` in `version.json` (same number).
3. Add an entry at the top of `CHANGELOG.md`.
4. Commit, tag (`git tag v1.2.0`) and push with tags.

Open boards check `version.json` every 5 minutes and show **"New version available — tap to update"**.
