# Changelog — line

All notable changes to `paideia-os/line` (ed-clone editor) documented per Keep-a-Changelog convention. Semantic versioning per SemVer 2.0.

## [Unreleased]

_No unreleased changes — v1.1.0 is the current tag._

## [1.1.0] - 2026-09-08

### Added

- **v1.1-A** (issue #8) — Real syscall body: bootstrapped from zero-scaffold
  state. Direct sys_open/read/write/close/exit substrate replaces the
  M1-001 pre-scaffold placeholder. Landed 3edfa6f.
- **v1.1-B** (issue #9) — Semantic-pipe emit wire: emit LineEditRecord@0.1
  (56 bytes) at happy-path tail via sys_semantic_send (sysno 115). Fields:
  {lines_in, lines_out, files_read, files_written, edit_count,
  session_start_ns, session_end_ns}. Schema tag 0x656E694C69644500
  ('LineEdit\0' LE). Error paths emit no record. Landed c810b96.
- **v1.1-C** (issue #10) — Release closer: this CHANGELOG + manifest
  bump 1.1.0-B → 1.1.0. Landed 2026-09-08.

### Notes

- Timestamps are raw TSC ticks (rdtsc) until `sys_clock_now` lands.
- Dual-signed release deferred to a future v1.2.0 pending libpdx-audit
  integration.

## [0.1.0] - 2026-08 (implicit)

- Initial R63.M1 bootstrap; ed-clone editor scaffold.
