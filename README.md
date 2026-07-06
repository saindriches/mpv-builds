# mpv-builds

Builds [mpv](https://github.com/mpv-player/mpv) (the player app) against an FFmpeg compiled from
source with the patches under `patches/ffmpeg/` applied. Today that patch set is the **MMT/TLV
demuxer** (ARIB STD-B32), so the resulting mpv plays Japanese ISDB-S3 4K/8K `.mmts` files
natively — including on scrambled streams, where the clear signaling still yields timing, service,
and track metadata.

Same idea as the sibling [iina-builds](https://github.com/saindriches/iina-builds): a standalone
repo (not a fork) that keeps the patches and CI in one clean place. The framework is general —
drop more `.patch` files into `patches/<dep>/` and they apply in order.

## What it produces

CI (`.github/workflows/build.yml`) builds per platform and uploads an artifact:

| platform | runner | output |
|---|---|---|
| macOS arm64 | `macos-14` | `mpv.app` (via mpv's `macos-bundle` meson target) |
| macOS x86_64 | `macos-13` | `mpv.app` |
| Linux x86_64 | `ubuntu-latest` | `mpv` binary + libmpv |
| Windows x86_64 | `ubuntu-latest` (mingw) | scaffold — the patched FFmpeg cross-builds; the mpv step still needs wiring |

The patched `libav*` are embedded in `mpv.app/Contents/Frameworks` and ad-hoc signed so it runs on
a personal machine without a developer certificate.

## Caching (fast iteration)

Two layers, so re-runs are cheap:

1. **Patched-FFmpeg prefix** — the built `ffprefix/` is cached, keyed on the FFmpeg version and a
   hash of `patches/ffmpeg/*.patch`. It rebuilds only when a patch or the version changes; an
   mpv-only change restores it in seconds. `build-ffmpeg.sh` is idempotent, so a cache hit is free.
2. **ccache** — accelerates recompiles of mpv (and FFmpeg when it does rebuild), keyed per platform
   with a rolling `restore-keys`, the same pattern mpv's own CI uses.

Force a full FFmpeg rebuild with the `force_rebuild_ffmpeg` dispatch input, or bump `CACHE_EPOCH`
in the workflow.

## Pinned inputs

See `manifest.env`: `FFMPEG_VERSION` (the release the patches target), `MPV_REF` (git ref, `master`
for nightly), `CACHE_EPOCH`.

## Triggers

- push to `main` touching `patches/**`, `scripts/**`, the workflow, or `manifest.env`
- nightly `schedule` (mpv master moves; FFmpeg stays cached unless the patches change)
- manual `workflow_dispatch` (`mpv_ref`, `force_rebuild_ffmpeg`)

## Status

macOS and Linux are the intended paths; the Windows/mingw job builds the patched FFmpeg but its mpv
step is a scaffold to iterate on in CI. First runs may need fixups — GitHub Actions can't be
validated locally.
