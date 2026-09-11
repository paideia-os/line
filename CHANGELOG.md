# Changelog — line

All notable changes to `paideia-os/line` (ed-clone editor) documented per Keep-a-Changelog convention. Semantic versioning per SemVer 2.0.

## [Unreleased]

### Added

- **v1.2-A** (issue #3) — R63.M1-003 line-array buffer state (`src/buffer.pdx`,
  module `Buffer`). Fixed pool of 512 lines * 256 bytes each (@align(8)
  .bss slabs `buffer_pool` + `buffer_len`; totals ~132 KiB per-process
  after main.pdx's existing scratch). Public entry points:
  `buffer_insert_line(after, text_ptr, text_len)`,
  `buffer_delete_line(addr)`,
  `buffer_replace_line(addr, text_ptr, text_len)`,
  `buffer_get_line_ptr(addr)`,
  `buffer_get_line_len(addr)`,
  `buffer_last_addr()`,
  `buffer_cursor_get()`,
  `buffer_cursor_set(addr)`.
  All 1-based addresses; 0 == pre-line-1 sentinel (empty buffer / `.` at
  boot). Cursor persists across ops per POSIX ed §Addressing: `insert`
  sets dot to `after+1`; `delete` sets dot to `min(addr, new_count)`;
  `replace` sets dot to `addr`; `get_*` / `last_addr` / `cursor_get` do
  not move it. Runtime error sentinels live in line/ own failure band
  `0xFFFFFFFFFFFFFF0N` (disjoint from all valid returns): `_OOB` (0x01),
  `_POOL_FULL` (0x02), `_LINE_TOO_LONG` (0x03). No syscall issued;
  `!{mem}` only. SysV callee-save preserved with @no_frame + caller-save-
  only scratch (no push/pop). Encoder pitfall discipline v0.36+: no
  `test`, no `and reg, imm64`, no 2-op `imul`, no scaled-index
  `[reg + N*idx]`, byte-store `mov [rN], al` + `xor rax, rax; mov_b rax,
  [rN]` narrow-load, reserved-label prefix `buffer_`. Not wired into
  `Main::_start` yet -- the dispatch layer at M1-005 will call these
  entries from within the `{fs, sched}` region; effect composition is
  additive so the caller's declaration remains sufficient. `lines_out` /
  `edit_count` in `LineEditRecord@0.1` (v1.1-B) will begin to diverge
  from `lines_in` / 0 respectively once the M1-005 dispatch drives edits
  through this module.
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
