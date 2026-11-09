# Changelog

All notable changes to Cost Alert. Versions follow `MAJOR.MINOR.PATCH`.

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
