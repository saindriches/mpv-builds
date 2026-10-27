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
- Code: the series is branch `bt1869-tlv` (worktree `~/ffmpeg-tlv-series`), four commits on
  upstream master `86444dd3`: the demuxer (MMTP core, ARIB part, TLV layer, docs, Changelog,
  minor bump), seeking, metadata, FATE test. **Local only, not pushed.** The working commits it
  was cut from are on `bt1869-tlv-dev` (worktree `~/ffmpeg-tlv`); both trees are equal. Why the
  core, ARIB part and demuxer share one commit, and why the fork's extradata commit is dropped:
  design section 5.
- Credit and identity (settled 2026-10-28): commits authored as Rainbaby <r@bgr.jp>, with
  "Based on a patch by SuperFashi <admin@superfashi.com>" (the seek commit: "Based on patches by
  SuperFashi <admin@superfashi.com> and msg7086"). Each commit also carries a
  `Co-Authored-By: Claude` trailer; drop it before posting if the user prefers. SuperFashi is assumed not to reply: open the PR directly, then a short
  note on #21037 linking it (draft in design section 8).
- Checks: regression harness `/Volumes/Nearline/mmt_tlv/ffmpeg_regress/` (outside any repo;
  `README.txt` there explains `run.sh`, `compare.py`, `trash.sh` and every intended difference
  against the fork head `f7480a7c`). Run `series-1` (the cut series): video packets equal to the
  fork on all 22 samples. Damaged input: `trash.sh` with a UBSan build under Guard Malloc
  (ASAN binaries hang on this Mac) found one out-of-bounds read in the MPT walk, now fixed;
  1400 trashed inputs then ran clean. FATE test `fate-bt1869-tlv-demux` uses a 400 kB cut kept at
  `/Volumes/Nearline/mmt_tlv/fate/samples/mmt/b111-1s.mmts`; uploading it to fate-suite is the
  user's call.
- Same layer boundaries as the MediaInfoLib refactor (PR 2647, `File_Tlv` / `File_Mmt` /
  `File_Mmt_Arib.cpp`, local branch `mmt-tlv-refactor` in `~/PycharmProjects/MediaInfoLib`).
- CI impact: cherry-pick the finished series to a new branch on the fork base for CI, rebuild
  the AVS+ branch on top under a new name, and bump the pins only after the harness gate
  passes. `mmt-tlv` and `mmt-tlv-avsplus` stay untouched as rollback points.

## Next step

A pre-submission audit (2026-10-28) ran Forgejo Fairy's own review prompt, from
`code.ffmpeg.org/michaelni/Fairies` `llm_prompt.py`, through Codex gpt-6-astra. It classified
the series major_issues. The reason is that packets queued before a seek survive it, which can
trip an assertion in the binary search. All thirteen findings hold against the code and the
ARIB specs (the user's copies: `/Volumes/Nearline/ARIB/Broadcast/Standard/`, STD-B60 v1.5
and others). One (the subtitle descriptor) needs a different fix than Codex proposed. The rendered prompt, the review and the verification table are in the shared
session notes folder, `bt1869-tlv-audit/README.md` (outside any repo, on the user's Mac).
Fix the confirmed findings on `bt1869-tlv-dev` first, if the user agrees, then autosquash and
rerun the harness, `trash.sh` and FATE.

Then the user reviews the four commits on `bt1869-tlv` (`git log -p 86444dd3..bt1869-tlv` in
`~/ffmpeg-tlv-series`). Then, each only on their explicit go: push the branch to a fork on
code.ffmpeg.org, open the PR with the FATE sample in the PR's `fate-samples` block, post the
#21037 note (design section 8), and later cherry-pick to a CI branch and move the pins.

## Known stale text

`README.md` still says the pin is on `mmt-tlv`, lists `macos-13` and calls the Windows job a
scaffold. Per the memory notes, all jobs run on `macos-14`, the Windows job builds a real
`mpv.exe`, and the pin is on `mmt-tlv-avsplus`. Not fixed here.
