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

## Current work: the BT.1869 TLV demuxer series

- Design and decisions: `~/ffmpeg-mmt/MMT-SPLIT-DESIGN.md`. **Untracked and local to the
  user's Mac**, because that repository's branches are bound for upstream. Section 9 lists the
  implementation decisions and their reasons. Copy of the Fairy review: the shared session
  notes folder, `ffmpeg-21037-fairy-review.md`.
- Shape: TLV is its own demuxer `bt1869_tlv` (`libavformat/bt1869_tlvdec.c`, extension
  `mmts`); MMT is a libavformat-internal parser (`mmtp.c` ISO core, `mmtp_arib.c` ARIB STD-B60,
  shared `mmtp_internal.h`, API in `mmtp.h`); the MMT flavor (ARIB, ATSC 3.0, unknown) is
  detected from the stream; no AVOptions. HEVC access units are assembled in the demuxer.
- Code: worktree `~/ffmpeg-tlv`, branch `bt1869-tlv-dev`, on upstream master `86444dd3`.
  **Local only, not pushed.** Its commits are working steps; the series still has to be cut
  from it (design section 5: MMTP core, ARIB part, demuxer, seeking, metadata, FATE). The fork's
  extradata commit is dropped (libavformat's generic path gives the same extradata).
- Credit and identity (settled 2026-10-28): commits authored as Rainbaby <r@bgr.jp>, with
  "Based on a patch by SuperFashi <admin@superfashi.com>" (and "Based on a patch by msg7086" on
  the seek commit). SuperFashi is assumed not to reply: open the PR directly, then a short
  note on #21037 linking it (draft in design section 8).
- Checks: regression harness `/Volumes/Nearline/mmt_tlv/ffmpeg_regress/` (outside any repo;
  `README.txt` there explains `run.sh`, `compare.py`, `trash.sh` and every intended difference
  against the fork head `f7480a7c`). Latest run `dev-4`: video packets and timestamps equal to
  the fork on all 22 samples. FATE test `fate-bt1869-tlv-demux` uses a 400 kB cut kept at
  `/Volumes/Nearline/mmt_tlv/fate/samples/mmt/b111-1s.mmts`; uploading it to fate-suite is the
  user's call.
- Same layer boundaries as the MediaInfoLib refactor (PR 2647, `File_Tlv` / `File_Mmt` /
  `File_Mmt_Arib.cpp`, local branch `mmt-tlv-refactor` in `~/PycharmProjects/MediaInfoLib`).
- CI impact: cherry-pick the finished series to a new branch on the fork base for CI, rebuild
  the AVS+ branch on top under a new name, and bump the pins only after the harness gate
  passes. `mmt-tlv` and `mmt-tlv-avsplus` stay untouched as rollback points.

## Next step

Finish the damaged input run (`trash.sh` with the ASAN build `~/ffmpeg-tlv-asan`), then recut
`bt1869-tlv-dev` into the final commits on the same base and check the recut tree equals the
dev tree. Pushing, opening the PR, the #21037 note, the FATE sample upload and CI pin changes
each need the user's explicit go.

## Known stale text

`README.md` still says the pin is on `mmt-tlv`, lists `macos-13` and calls the Windows job a
scaffold. Per the memory notes, all jobs run on `macos-14`, the Windows job builds a real
`mpv.exe`, and the pin is on `mmt-tlv-avsplus`. Not fixed here.
