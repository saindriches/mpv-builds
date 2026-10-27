# Status: the FFmpeg MMT/TLV work behind mpv-builds and iina-builds

Cold-readable entry point for the FFmpeg side of this project. Updated 2026-10-28.
The README describes the CI; this file says where the FFmpeg code stands and what is next.

## What it is

mpv-builds and iina-builds build players against our FFmpeg fork (`saindriches/FFmpeg`),
which adds a demuxer for Japanese ISDB-S3 4K/8K recordings (`.mmts`): MMT (ISO/IEC 23008-1 with
ARIB STD-B60 signaling) carried in TLV packets (ITU-R BT.1869, first standardized as ARIB
STD-B32). The demuxer started as SuperFashi's upstream PR and carries our fixes on top.

## Where the code lives

- Local checkout `~/ffmpeg-mmt`, remote `fork` = `github.com/saindriches/FFmpeg`.
- Files: `libavformat/mmtp.{c,h}` (MMTP parser), `libavformat/mmttlv.c` (TLV demuxer).
- `fork/mmt-tlv` (`f7480a7c`): SuperFashi's base `5313ffc0` + 8 of our commits, on FFmpeg master
  of 2025-12-02 (merge-base `413346bd`). Not FFmpeg 8.0; verify with `git merge-base`.
- `mmt-tlv-avsplus` (`059cd851`, worktree `~/ffmpeg-mmt-avsplus`): `mmt-tlv` + 29 commits adding
  AVS+ (AVS1-P16 GuangDian) decoding. Touches no MMT/TLV file. Owned by the `cavs` work.
- `series-final`, `mmttlv-fixes`: older submission shapes on `superfashi/tlvmmt` `3dcc0f02`.

## Pins (settled)

- mpv-builds `manifest.env`: `FFMPEG_REF=059cd851` (avsplus head).
- iina-builds `.github/workflows/build.yml`: `FFMPEG_REF=c180246b`, one commit behind on purpose
  (that commit is x86 SSE2 only; the IINA app is arm64).
- Neither workflow sets `restore-keys` for the FFmpeg prefix, so a pin bump is a full rebuild.

## Upstream

- SuperFashi's PR [#21037](https://code.ffmpeg.org/FFmpeg/FFmpeg/pulls/21037) is **open, not
  merged**. Author silent since 2025-12-02. On 2026-10-09 Forgejo Fairy reviewed it as
  `major_issues` (aggregated MFU assert, missing parser padding, unchecked allocations,
  unsupported content failing the open, no FATE test, among others). Our fork fixes only some
  of these.
- Nothing of ours has been posted upstream. Pushing, commenting or opening a PR needs the user's
  explicit go.

## Current work: TLV/MMT layer split (design only, no code yet)

- Design: `~/ffmpeg-mmt/MMT-SPLIT-DESIGN.md`. **Untracked and local to the user's Mac**, because
  that repository's branches are bound for upstream. Copy of the Fairy review: the shared
  session notes folder, `ffmpeg-21037-fairy-review.md`.
- Recommendation in short: TLV becomes its own demuxer `tlv` (`tlvdec.c`), not a URLProtocol
  and not a nested demuxer; MMT stays a libavformat-internal parser library (`mmtp.c`, ISO core)
  with the ARIB STD-B60 parts in `mmtp_arib.c`; the MMT flavor (ARIB, ATSC 3.0, unknown) is
  detected from the stream, never hinted by TLV; no new AVOptions.
- Upstream path (revised 2026-10-28): take #21037 over as a review-driven v2. Commit 1 stays
  SuperFashi's (their `Author:`, our `Signed-off-by:`) with only the review fixes folded in,
  because FFmpeg rejects resubmissions that add unrequested changes; the layer split, the
  rename and our features follow as separate commits. Ask on #21037 first: Forgejo lets us open
  a PR from `Rainbaby/FFmpeg` into SuperFashi's `tlvmmt` branch, which updates #21037 in place
  if they merge it; otherwise a new PR after about a week. Evidence is in section 5 of the
  design.
- Same layer boundaries as the MediaInfoLib refactor (PR 2647, `File_Tlv` / `File_Mmt` /
  `File_Mmt_Arib.cpp`, local branch `mmt-tlv-refactor` in `~/PycharmProjects/MediaInfoLib`).
- CI impact: develop on current upstream master, cherry-pick to a new branch on the fork base
  for CI, rebuild the AVS+ branch on top under a new name, and bump the pins only after a
  before/after framemd5 and seek gate passes. `mmt-tlv` and `mmt-tlv-avsplus` stay untouched as
  rollback points.

## Next step

Waiting on the user's answers to the open questions in section 6 of the design (comment on
#21037, demuxer name, credit form, one or two MMT files, fork base, ATSC scope).
Then: the user reviews the #21037 comment drafted in section 8 of the design and posts it; branch from current upstream master, rebuild
SuperFashi's commit with the Fairy fixes,
and build the framemd5 harness over the reference `.mmts` files.

## Known stale text

`README.md` still says the pin is on `mmt-tlv`, lists `macos-13` and calls the Windows job a
scaffold. Per the memory notes, all jobs run on `macos-14`, the Windows job builds a real
`mpv.exe`, and the pin is on `mmt-tlv-avsplus`. Not fixed here.
