# Changelog

All notable changes to Cost Alert. Versions follow `MAJOR.MINOR.PATCH`.

## v1.6.0 — 2026-11-12
### Changed
- **New alarm sound.** The siren sounded like a missile alarm, so it's replaced by a friendly bell chime ("ding-ding-ding"), like a shop announcement.
  - Rising G5 → C6 → E6 (a major chord), played twice, about 3 s. Repeats every 10 s until **SEEN**, same as before.
  - Bell tone made from sine partials that fade at different speeds. Gentle compression keeps every note clear.
  - As loud as possible without distortion (peak ≈ 0.9, no clipping). Volume is `CHIME_VOLUME` in `index.html`.
  - Preview: `docs/alarm-chime.wav`.
- Phone vibration pattern shortened to match.

## v1.5.0 — 2026-11-10
### Added
- **Sound on/off switch** on the staff board. Tap to turn the siren off, tap again to turn it on (plays a short test alarm).
  - A muted screen **turns its sound back on by itself after 30 minutes** (`MUTE_MINUTES` in `index.html`), so a forgotten mute can't hide a change.
  - The button shows when sound comes back ("Sound off · back on 9:07 PM"), and the alert says "Alarm sound is off until …".
  - While muted, Windows notifications are silent too. The mute stays through a reload.
  - Keyboard and screen-reader friendly (`role="switch"`).

### Changed
- **Simpler, louder alert.** One red pulsing screen with just four things: "COST CHANGED" tag, product name, giant new price (old price struck through beside it) with the up/down chip, and one big **SEEN** button.
  - Removed the hazard stripes, the white card, the header bar, the price box and its labels, and the "changed by" line. The time moved next to the code.
  - Every colour pair still passes WCAG AA across the whole pulse.

## v1.4.0 — 2026-11-10
### Added
- **Windows notifications** for every cost change. They pop up over every app (the sales software too), even with Chrome minimised, and stay on screen until someone answers.
  - **Seen** button inside the notification confirms the change and stops the siren, without opening the board.
  - **Open board** (or clicking the notification) brings the board to the front.
  - Pressing SEEN on the board removes the notification too.
  - Notifications still arrive after a reload, even before START is tapped.
- START screen asks for notification permission. It only gets skipped once that question has been answered.
- Board status buttons: **Sound on / Sound off — tap to turn on** (tap plays a test alarm) and **Notifications on / Turn on notifications / blocked** (tap sends a test notification or shows how to unblock).
- Checks keep running every 3 s when Chrome is minimised (timers run in a Web Worker).
- Starts without the START tap when Chrome already allows sound (kiosk shortcut with the autoplay flag, see README).
- Any tap on the board switches sound back on if Chrome paused it.
- New files: `sw.js` (handles notification buttons), `icon.png`, `icon-alert.png`.

## v1.3.0 — 2026-11-10
### Changed — full UI/UX redesign (see `DESIGN.md`)
- New dark "signal board" design system: colour tokens, Inter type scale, 8-pt spacing, every colour pair measured to WCAG AA.
- **Alert:** full-screen pulsing red with hazard stripes, white card, new price up to 120 px, "Up 50.00 QAR +8.3%" chip, who changed it and when, "1 of 3" queue counter, large green **Seen — I understand** button.
- Alert scales up on 1080p TVs so it reads from across the shop.
- Board rows stay calm (dark, with a red/green side bar) so the alert is the loudest thing on screen. Unconfirmed rows get an amber **NEW** tag.
- Live / Recent tabs as a segmented control with today's count, plus "today / up / down" summary chips.
- Taskbar favicon turns red during an alert, together with the flashing title.
- SVG icons (Lucide) instead of emoji. Arrows and words show up/down, not colour alone.
- Admin: labelled form with barcode icon, required markers, live "Down 10.00 QAR" preview, loading spinners, status chips for "Seen by" / "Waiting".
- Login: show/hide password, clearer errors.

### Accessibility
- Every control ≥ 48 px. Visible focus rings. Alert is an `alertdialog`: focus goes to **Seen**, Enter confirms, Tab stays inside.
- Respects *reduced motion*. Alert pulse stays below the 3-flashes-per-second seizure limit.
- Phone layout: no horizontal scroll at 375 px, tables become cards, landscape can reach **Seen**.

## v1.2.0 — 2026-11-09
### Added
- **Recent** tab on the staff board: scan a barcode or type a name/code/supplier to see that product's cost history (newest first, latest marked **CURRENT**). Empty search shows all changes from the last 30 days.
- Alerts still pop up over the Recent tab.
- Database: new `ca_search` function (any logged-in user).

### Fixed
- Login screen no longer jumps the cursor back to the Name box if you start typing quickly.

## v1.1.0 — 2026-11-09
### Changed
- Alert sound is now a loud siren (3 × "wee-woo" sweeps, ~2 s) instead of a short beep.
- Alarm repeats every 10 s (was 20 s) until the staff member presses **SEEN**.

### Added
- Sound check: the alarm plays once when staff tap **START BOARD**.
- Tab title flashes "⚠ COST CHANGED ⚠" so the alert shows on the taskbar even behind other windows.
- Phones that support it vibrate with the alarm.
- Version number shown on the login, admin and board screens.
- "New version available — tap to update" notice when a newer version is published.

## v1.0.0 — 2026-11-09
### Added
- Online cost-change board, works from any Wi-Fi, any office and phones.
- Admin login: update cost by barcode/code/name, old cost auto-filled, recent changes with who pressed **SEEN**, delete mistakes.
- Logins page: admin adds/removes staff and admin logins, changes passwords.
- Staff login: full-screen board (today highlighted, yesterday faded), alarm + pop-up for every change until **SEEN**.
- Per-person **SEEN** tracking: each staff screen keeps alerting until that person confirms.
- Security: database tables locked, access only through checked functions, 5 wrong passwords = 15 min lock.
