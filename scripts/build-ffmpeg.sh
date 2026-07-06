#!/usr/bin/env bash
# Build FFmpeg $FFMPEG_VERSION from source with patches/ffmpeg/*.patch applied, installed to $PREFIX.
# Shared by the macOS and Linux jobs (both POSIX: configure + make). Windows uses the mingw job.
#
# The config is "full enough for mpv playback": FFmpeg enables its decoders/demuxers/parsers by
# default, so we only turn OFF what a player never needs (programs, docs) and turn ON the platform
# hwaccel and our mmttlv demuxer. No encoders/external codec libs are needed for playback, which
# keeps the build fast and dependency-light.
#
# Idempotent: if $PREFIX already has libavformat.pc (restored from cache) it does nothing, so the
# cache hit path is free.
set -euxo pipefail
: "${FFMPEG_VERSION:?set FFMPEG_VERSION}" "${PREFIX:?set PREFIX}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -f "$PREFIX/lib/pkgconfig/libavformat.pc" ]; then
  echo "ffmpeg already present at $PREFIX (cache hit) — skipping build"
  exit 0
fi

work="$(mktemp -d)"; cd "$work"
curl -fsSL "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz" -o ffmpeg.tar.xz
tar xf ffmpeg.tar.xz
cd "ffmpeg-${FFMPEG_VERSION}"

shopt -s nullglob
for p in "$ROOT"/patches/ffmpeg/*.patch; do
  echo "mpv-builds: applying $(basename "$p")"
  patch -p1 < "$p"
done

extra=()
case "$(uname -s)" in
  Darwin) extra+=(--enable-videotoolbox --enable-audiotoolbox) ;;
esac

./configure \
  --prefix="$PREFIX" \
  --enable-gpl --enable-version3 \
  --enable-shared --disable-static \
  --disable-programs --disable-doc \
  --enable-network \
  --enable-demuxer=mmttlv \
  "${extra[@]}"

make -j"$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"
make install
echo "mpv-builds: FFmpeg ${FFMPEG_VERSION} (patched) installed to $PREFIX"
