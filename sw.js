/* Cost Alert — service worker
   Handles clicks on Windows / desktop notifications:
   - "Seen" button        -> confirms the change (same as pressing SEEN on the board), which stops the alarm
   - "Open board" / body  -> brings the board window to the front
   The board page shows the notifications; this file only reacts to clicks on them. */
const SW_VERSION = "1.4.0";

self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (e) => e.waitUntil(self.clients.claim()));

function boardWindows() {
  return self.clients.matchAll({ type: "window", includeUncontrolled: true });
}

async function openBoard(url) {
  try {
    const list = await boardWindows();
    const win = list.find((w) => w.url.startsWith(self.registration.scope));
    if (win) {
      win.postMessage({ type: "ca-open" });
      return await win.focus();
    }
    return await self.clients.openWindow(url || self.registration.scope);
  } catch (e) { /* focus/open is only allowed straight after a click */ }
}

async function confirmSeen(d) {
  const headers = { "Content-Type": "application/json", apikey: d.key };
  if (String(d.key).startsWith("eyJ")) headers.Authorization = "Bearer " + d.key;
  try {
    const r = await fetch(`${d.api}/rest/v1/rpc/ca_seen`, {
      method: "POST", headers, body: JSON.stringify({ p_token: d.token, p_id: d.id }),
    });
    return r.ok;
  } catch (e) {
    return false;
  }
}

async function handle(notification, action) {
  const d = notification.data || {};
  notification.close();
  if (action === "seen" && d.id) {
    const ok = await confirmSeen(d);
    (await boardWindows()).forEach((w) => w.postMessage({ type: "ca-seen", id: d.id, ok }));
    if (ok) return;               // confirmed: the board closes its alert and the siren stops
    return openBoard(d.url);      // offline or logged out: open the board so staff can press SEEN there
  }
  return openBoard(d.url);
}

self.addEventListener("notificationclick", (e) => e.waitUntil(handle(e.notification, e.action)));

// Used by the automated tests only: simulate a click on a notification by its tag.
self.addEventListener("message", (e) => {
  const m = e.data || {};
  if (m.type !== "ca-test-click") return;
  e.waitUntil(self.registration.getNotifications({ tag: m.tag }).then((ns) => ns[0] && handle(ns[0], m.action)));
});
