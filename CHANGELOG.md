# Changelog — line

All notable changes to `paideia-os/line` (ed-clone editor) documented per Keep-a-Changelog convention. Semantic versioning per SemVer 2.0.

## [Unreleased]

### Added

- **v1.3-A** (issue #4) — R63.M1-004 file I/O (`src/fileio.pdx`, module
  `Fileio`). Two public entry points backing the ed-style `w <path>`
  (write buffer to file) and `e <path>` (read file into buffer) commands
  that the M1-005 dispatch layer will wire to the interactive `:` prompt:
  `fileio_write_buffer(path_ptr)` opens the target with
  `O_CREAT|O_WRONLY|O_TRUNC` (flag word `0x241` = `0x40 | 0x01 | 0x200`,
  mode `0644` = `0x1A4`) and emits every line via
  `sys_write(fd, buffer_get_line_ptr(addr), buffer_get_line_len(addr))`
  followed by `sys_write(fd, "\n", 1)` -- including the last line;
  `fileio_read_file(path_ptr)` opens with `O_RDONLY` (`0`, mode `0`),
  streams the file into a 4 KiB `fileio_stream_buf` (@align(8) .bss),
  splits on `'\n'` (`0x0A`), and appends each complete line to the
  Buffer module via `buffer_insert_line(buffer_last_addr(), ptr, len)`.
  Residual bytes at the end of a chunk (no trailing `'\n'`) memmove to
  the front and combine with the next `sys_read`; on EOF the trailing
  residual (if any) is inserted as one final unterminated line -- so a
  file ending in `'\n'` yields exactly N lines and a file without
  trailing `'\n'` still preserves its final line. `fd`-gate `cmp rax,
  32; jae` per the `ls.pdx` precedent (valid user fd in `[3, 32)`; any
  bit-63-set negative-errno as unsigned dwarfs 32). Error sentinels in
  the same `0xFFFFFFFFFFFFFF0N` band as `buffer.pdx`, in a disjoint
  `0x11..0x13` sub-band so the M1-005 dispatch layer can pattern-match
  the low byte back to the module of origin: `LINE_ERR_OPEN_FAIL`
  (`0xFFFFFFFFFFFFFF11`), `LINE_ERR_WRITE_FAIL` (`0xFFFFFFFFFFFFFF12`),
  `LINE_ERR_READ_FAIL` (`0xFFFFFFFFFFFFFF13`). On write failure the fd
  is best-effort closed before returning the sentinel (matches
  `main.pdx line_write_err` posture). Read failure additionally fires
  when a single line spans a full 4 KiB chunk with no `'\n'`
  (progress guard against infinite loop on adversarial input). SysV
  callee-save discipline: `fileio_write_buffer` pushes `rbx/r12/r13`
  (24 B, rsp %16 aligned at every nested `call`); `fileio_read_file`
  pushes `rbx/r12/r13/r14/r15` (40 B, aligned). Both @no_frame with
  manual push/pop matching `shell.pdx §shell_read_line` posture.
  `buffer_*` cross-module calls resolved by name (no `use` header
  required, per `dispatch.pdx` precedent). Not yet wired into
  `Main::_start` -- M1-005 dispatch will call these from the `:`
  prompt handlers. Encoder pitfall discipline v0.36+: no `test`, no
  `and reg, imm64`, no 2-op `imul`, no scaled-index, byte-load
  `xor rax, rax; mov_b rax, [rN]`, byte-store `mov [rN], dl`,
  reserved-label prefix `fileio_`, module basename `Fileio` matches
  filename `fileio.pdx`.
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
