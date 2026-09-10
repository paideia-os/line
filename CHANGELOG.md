# Changelog — line

All notable changes to `paideia-os/line` (ed-clone editor) documented per Keep-a-Changelog convention. Semantic versioning per SemVer 2.0.

## [Unreleased]

### Added

- **v1.1-D** (issue #6) — R63.M1-006 fingerprint `line ok -- lines=<N>\n`
  on the happy-path tail (three sys_writes to fd 1: prefix +
  `line_print_u64_dec` decimal + newline). Retires the v1.1-A witness
  phrase `line syscall-wire ok\n`. Newline count is computed once
  (byte-scan of `line_buf[0..n]` into r13, SysV callee-save) and
  carried through the fingerprint AND the v1.1-B semantic-pipe
  marshalling — the pre-v1.1-D duplicate count loop inside the emit
  block is retired. `LINE PARSE FAIL\n` rodata declared (unwired;
  parser lands at M1-002/M1-005). Exit-status inventory frozen at
  {0=OK, 2=usage, 3=READ FAIL, 4=WRITE FAIL, 5=PARSE FAIL reserved}.

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
