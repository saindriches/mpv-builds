#!/usr/bin/env bash
# Build FFmpeg from our MMT/TLV fork branch ($FFMPEG_REPO @ $FFMPEG_REF), installed to $PREFIX.
# Shared by the macOS and Linux jobs (both POSIX: configure + make). Windows uses the mingw job.
#
# The MMT/TLV demuxer (ARIB STD-B32) is already in the fork branch (saindriches/FFmpeg @ mmt-tlv),
# so there is no patch step. The config is "full enough for mpv playback": FFmpeg enables its
# decoders/demuxers/parsers by default, so we only turn OFF what a player never needs (programs,
# docs) and turn ON the platform hwaccel and the mmttlv demuxer.
#
# Idempotent: if $PREFIX already has libavformat.pc (restored from cache) it does nothing, so the
# cache hit path is free.
set -euxo pipefail
: "${FFMPEG_REPO:?set FFMPEG_REPO}" "${FFMPEG_REF:?set FFMPEG_REF}" "${PREFIX:?set PREFIX}"

if [ -f "$PREFIX/lib/pkgconfig/libavformat.pc" ]; then
  echo "ffmpeg already present at $PREFIX (cache hit), skipping build"
  exit 0
fi

work="$(mktemp -d)"; cd "$work"
# blob:none keeps the clone light (blobs are fetched lazily on checkout); check out the exact
# pinned commit so the build is reproducible even as the branch advances.
git clone --filter=blob:none --no-checkout "https://github.com/${FFMPEG_REPO}.git" ffmpeg-src
cd ffmpeg-src
git checkout --detach "$FFMPEG_REF"

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
echo "mpv-builds: FFmpeg ${FFMPEG_REPO}@${FFMPEG_REF} (mmt-tlv) installed to $PREFIX"
