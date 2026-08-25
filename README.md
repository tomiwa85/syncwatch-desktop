# SyncWatch Desktop — Flutter prototype

Two things are being proven here, in order:

1. **Playback** — Flutter + `media_kit` (libmpv) plays what Electron couldn't
   (MKV, HEVC/H.265, AC3/DTS, 10-bit) with real controls and fullscreen. ✅ done.
2. **Sync** — the desktop speaks your existing backend's Socket.IO protocol
   *exactly*, so a desktop user and a phone user can share a room and stay in
   lockstep (play/pause/seek, chat, file-verify). ← this build.

It talks to your live server (`syncwatch-server-szu2.onrender.com`) — the same
one the mobile app uses. **No backend changes.**

## Build it (through GitHub Actions — no local Flutter needed)

Same as before: push the source, the **Build Windows (Flutter)** workflow
compiles it, you download the `SyncWatch-Desktop-Windows` zip artifact.

If you're updating the existing repo, replace/add the files under `lib/` and the
new `pubspec.yaml`. Use **Add file → Create new file** and type the paths (e.g.
`lib/screens/room_screen.dart`) so folders are created and nothing is dropped.

Files in this build:
```
pubspec.yaml
lib/main.dart
lib/config.dart
lib/protocol.dart        # Dart mirror of @syncwatch/shared (events + models)
lib/sync_engine.dart     # port of the web client's drift-reconciliation engine
lib/api.dart             # auth + rooms REST (Bearer + 401→refresh)
lib/room_sync.dart       # socket wiring + media_kit player handle
lib/app_services.dart
lib/theme.dart
lib/screens/login_screen.dart
lib/screens/home_screen.dart
lib/screens/room_screen.dart
.github/workflows/build-windows.yml
```

## Run it

Unzip (keep all files together) and run `syncwatch_desktop.exe`.

1. **Sign up a fresh test account** on the desktop (tap "Create an account").
   Use your *normal* account on your phone. (Two clients logged in as the *same*
   user can confuse the member list — use two different accounts.)
2. First login may take **~40s** the first time (the free server is waking up).

## How to test sync

### Quick check (no matching files needed)
1. On the desktop: **Create a room** → note the 6-char code.
2. On your phone (the existing app): **join that code**.
3. On the desktop, open any video and press **play / pause** and drag the seek
   bar. Watch the phone follow — and vice-versa. The desktop's side panel shows a
   live `server: ▶ 12.3s` readout and a `last:` event breadcrumb so you can see
   the sync messages landing.

### Full check (real product flow)
1. Put the **same movie file** on both the desktop and the phone.
2. Desktop (host): open the file → **Set as room video**.
3. Both sides: open their copy → **Verify my file** (should show ✓; a different
   file shows the mismatch reason).
4. Play/pause/seek — both stay locked together. Try the **chat** too.

## What success looks like
- Play/pause/seek on one device moves the other within ~1s.
- File-verify passes for matching files, fails (with a reason) for different ones.
- Chat messages appear on both.
- A reconnect (toggle Wi-Fi briefly) re-converges playback.

If sync holds across desktop ↔ mobile, the two hardest risks (codecs + protocol)
are both retired, and everything left is porting the UI you've already designed.

### If it won't launch
Install the **Visual C++ Redistributable (2015–2022, x64)** on that PC. The real
installer will bundle this later so end-users never hit it.
