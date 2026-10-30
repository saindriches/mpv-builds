# mpv-builds

Builds [mpv](https://github.com/mpv-player/mpv) (the player app) against an FFmpeg compiled from our
fork branch ([`saindriches/FFmpeg` @ `bt1869-tlv-ci`](https://github.com/saindriches/FFmpeg/tree/bt1869-tlv-ci)),
which carries the **`bt1869_tlv` demuxer** (MMT/TLV, ITU-R BT.1869, ARIB STD-B32 and STD-B60) and
an AVS+ decoder in-tree. The resulting mpv plays Japanese
ISDB-S3 4K/8K `.mmts` files natively, including on scrambled streams, where the clear signaling
still yields timing, service, and track metadata.

Same idea as the sibling [iina-builds](https://github.com/saindriches/iina-builds): a standalone
repo (not a fork) that keeps the CI in one clean place. FFmpeg now comes from the fork branch (no
in-repo ffmpeg patches); mpv's own source tweaks still live in `patches/mpv/` and apply in order.

## What it produces

CI (`.github/workflows/build.yml`) builds per platform and uploads an artifact:

| platform | runner | output |
|---|---|---|
| macOS arm64 | `macos-26` | `mpv.app` (via mpv's `macos-bundle` meson target) |
| Linux x86_64 | `ubuntu-latest` | `mpv` binary + libmpv |
| Windows x86_64 | `windows-latest` (MSYS2 UCRT64) | `mpv.exe` plus its DLLs |

Our `libav*` are embedded in `mpv.app/Contents/MacOS/lib` and the bundle is ad-hoc signed, so it
runs on a personal machine without a developer certificate. There is no Intel macOS build since
2026-10: Homebrew no longer installs on Intel Macs, which left the old universal build's x86_64
half without dependencies.

## Caching (fast iteration)

Two layers, so re-runs are cheap:

1. **FFmpeg prefix**: the built `ffprefix/` is cached, keyed on the pinned fork commit
   (`FFMPEG_REF`). It rebuilds only when that ref changes; an mpv-only change restores it in
   seconds. `build-ffmpeg.sh` is idempotent, so a cache hit is free.
2. **ccache**: accelerates recompiles of mpv (and FFmpeg when it does rebuild), keyed per platform
   with a rolling `restore-keys`, the same pattern mpv's own CI uses.

Force a full FFmpeg rebuild with the `force_rebuild_ffmpeg` dispatch input, or bump `CACHE_EPOCH`
in the workflow.

## Pinned inputs

See `manifest.env`: `FFMPEG_REPO` + `FFMPEG_REF` (the fork and its pinned `bt1869-tlv-ci` commit;
the file says what the branch holds and how to roll back),
`MPV_REF` (git ref, `master` for nightly), `CACHE_EPOCH`.

## Triggers

- push to `main` touching `patches/**`, `scripts/**`, the workflow, or `manifest.env`
- nightly `schedule` (mpv master moves; FFmpeg stays cached unless `FFMPEG_REF` changes)
- manual `workflow_dispatch` (`mpv_ref`, `force_rebuild_ffmpeg`)

## Status

All three platforms build a player. The nightly run failed from 2026-08-29 (Homebrew dropped bottles for
macos-14 and Intel installs, MSYS2 dropped MINGW64 packages) and GitHub then disabled the
schedule; it was fixed and re-enabled on 2026-10-30. GitHub Actions can't be validated locally.
