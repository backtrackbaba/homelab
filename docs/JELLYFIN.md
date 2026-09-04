# Jellyfin (native macOS)

Installed natively (not containerized) so it can use Apple VideoToolbox
hardware transcoding, which is not available to a containerized server on
macOS. See `docs/MEDIA-PHOTOS-STORAGE.md` for why Immich, by contrast,
runs containerized with CPU-only ML.

## Install

```bash
brew install --cask jellyfin
```

Installs `/Applications/Jellyfin.app`. Data lives at
`~/Library/Application Support/jellyfin` (config, database, cache,
transcode scratch space — all on the internal SSD).

## Running it: bypass the menu-bar app

`Jellyfin.app`'s menu-bar wrapper requires a manual "Launch" click and did
not reliably survive automation or restarts during setup. The actual
server is a separate binary inside the bundle that runs headless fine on
its own:

```bash
/Applications/Jellyfin.app/Contents/MacOS/jellyfin \
  --webdir /Applications/Jellyfin.app/Contents/Resources/jellyfin-web \
  --ffmpeg /Applications/Jellyfin.app/Contents/MacOS/ffmpeg \
  --datadir "/Users/sai-mini/Library/Application Support/jellyfin"
```

This is what the LaunchAgent below actually runs — the `.app`'s tray icon
is not used at all in normal operation.

## Startup: LaunchAgent

`~/Library/LaunchAgents/io.jellyfin.server.plist` runs the command above
via `launchd`, with `RunAtLoad` and `KeepAlive` (restarts on crash, not on
a clean exit). Combined with this Mac's existing auto-login
(`autoLoginUser` already set to `sai-mini` before this setup), Jellyfin
comes up automatically after a reboot without anyone present at the
machine. Verified: killing the process with `kill -9` gets it relaunched
by launchd within ~3 seconds, with the same server identity and data
intact. An actual full-machine reboot has **not** been tested — that
would restart every other container on this Mac, not just Jellyfin, so
it needs a deliberate decision, not an incidental one.

```bash
# status
launchctl list | grep jellyfin

# stop and disable
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/io.jellyfin.server.plist

# fully remove
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/io.jellyfin.server.plist
rm ~/Library/LaunchAgents/io.jellyfin.server.plist

# re-enable after editing the plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/io.jellyfin.server.plist
```

## Setup wizard

Completed via Jellyfin's `/Startup/*` REST API rather than the browser
wizard. One gotcha: `/Startup/User` returns a bare 404 with
`Content-Type: application/json` on this version (10.11.11) — it only
works with `Content-Type: text/json`. First attempt at automating this
silently completed the wizard (`/Startup/Complete` succeeded) without
actually creating an admin user, locking the instance out of its own
wizard with zero users; fixed by wiping the (still-empty) data directory
and redoing it correctly. If scripting this again on a future reinstall,
verify a user actually exists (`Users/AuthenticateByName`, not just a
204 from `/Startup/Complete`) before trusting it.

Admin credential: username `sai`, password stored as
`JELLYFIN_ADMIN_PASSWORD` in the repo root's `secrets.enc.env`.

## Hardware acceleration: verified, not assumed

`System/Configuration/encoding` set to `HardwareAccelerationType:
videotoolbox`, with `h264`/`hevc`/`mpeg2video`/`vc1`/`vp8`/`vp9` hardware
decode and VideoToolbox tone-mapping enabled.

Verified with a real forced transcode (720p source, scaled to 640x360),
inspecting the actual `ffmpeg` invocation and CPU usage:

```
ffmpeg ... -hwaccel videotoolbox -hwaccel_output_format videotoolbox_vld
       ... -codec:v:0 h264_videotoolbox ... -vf scale_vt=w=640:h=360 ...
```

ffmpeg CPU usage during this transcode: ~79%. A software x264 transcode
of the same source would typically run several hundred percent across
cores — this confirms VideoToolbox is actually doing the decode, scale,
and encode work, not falling back to CPU.

**No HDMI dummy plug was needed.** The official docs' warning about GPU
throttling on headless Macs is an artifact of older Intel Macs; this is
an Apple Silicon M4 Pro, and hardware transcoding worked correctly with
no display attached beyond the auto-login console session already
present. Do not add a dummy plug unless a future test shows throttling —
none has been observed.

## Library

`Movies` library added pointing at `${DATA_ROOT}/media/movies` (the same
`MEDIA_ROOT` the media automation stack will eventually populate). Seeded
with one openly-licensed test file (Big Buck Bunny, CC-BY, Blender
Foundation) purely to exercise the pipeline — replace/supplement with
real, lawfully-owned media before relying on this for anything.

## Ports

See `docs/PORTS.md`. `8096` (HTTP), `8920` (HTTPS, unconfigured so far),
`7359/udp` (LAN discovery), `1900/udp` (DLNA) — all native, no Docker
networking involved.
