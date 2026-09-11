# Changelog — line

All notable changes to `paideia-os/line` (ed-clone editor) documented per Keep-a-Changelog convention. Semantic versioning per SemVer 2.0.

## [Unreleased]

### Added

- **v1.4-A** (issue #5) — R63.M1-005 interactive REPL loop (`src/main.pdx`,
  module `Main`). Retires the M1-001 batch open+read+write+close round-trip
  and lands an ed-style interactive session: `[emit ':' prompt] -> [read one
  line from fd 0 via per-byte sys_read] -> [tokenize address + command +
  arg] -> [dispatch] -> [loop]`. Supported grammar at v1.4-A: addresses
  `.` (buffer_cursor_get), `$` (buffer_last_addr), decimal literal `<N>`,
  range `<A1>,<A2>` (`,` shorthand expands to `1,$`); commands `q` (soft
  quit -- emits R63.M1-006 fingerprint `line ok -- lines=<N>\n` and
  LineEditRecord@0.1 via sys_semantic_send SC+ ID 115, then sys_exit(0)),
  `Q` (hard quit -- sys_exit(0) with no emit; matches POSIX ed's discard-
  unsaved-changes convention), `w <path>` (fileio_write_buffer),
  `e <path>` (fileio_read_file), `p` (print addr1..addr2), `d` (delete
  addr1..addr2), `a` / `i` / `c` (append/insert/change input-mode --
  reads lines from fd 0 until a lone `.` and inserts each via
  buffer_insert_line, incrementing main_edit_count per success), bare
  address (moves cursor and prints). EOF on fd 0 with no bytes accumulated
  is treated as an implicit `q`. Line reader is per-byte `sys_read(0,
  &line_buf[i], 1)` (SC+ ID 0) rather than libc getline -- paideia-os has
  no libc at R63; correct and simple for the interactive shell (one
  syscall per keystroke on a tty is what bash does at the read-a-command
  layer). Error-shape: every buffer_* / fileio_* sentinel return
  (`cmp rax, 512; ja` for buffer's `[1,512]` band and
  `cmp rax, 0; jne` for fileio's `{0=OK}`) triggers a single
  `sys_write(1, "?\n", 2)` and jumps back to the prompt -- never
  sys_exit'd mid-session. Unknown-command byte, malformed address, and
  missing `w`/`e` path use the SAME `?\n` wire. The fingerprint and
  LineEditRecord emit sites MOVE from the retired batch-mode tail to
  the `q` handler; wire format is unchanged (v1.1-B/D verbatim);
  `<N>` now reads `buffer_last_addr()` at exit-time instead of counting
  `'\n'` bytes in a scratch buffer, so a session `e foo -> q` reports
  the count of lines that landed in the buffer. `edit_count` in the
  record tracks successful `a` / `i` / `c` / `d` operations
  (incremented at each buffer_insert_line / buffer_delete_line success
  site). `files_read` / `files_written` remain 0 at v1.4-A pending a
  per-command counter wire that lands with M2-002 audit integration.
  Four new local helpers: `main_read_line` (per-byte fd-0 line reader,
  returns len or MAIN_ERR_EOF=`0xFFFFFFFFFFFFFF20`), `main_parse_line`
  (address + command tokenizer, writes to `main_addr1_set/main_addr1/
  main_addr2_set/main_addr2/main_cmd/main_arg_ofs/main_arg_len` .bss
  slots), `main_input_mode(after)` (reads lines until lone `.` and
  inserts each; returns MAIN_ERR_PARSE=`0xFFFFFFFFFFFFFF21` on buffer
  sentinel), `main_print_addr(addr)` (single-line print with trailing
  `'\n'`). Sentinel band `0xFFFFFFFFFFFFFF20..0x2F` is disjoint from
  buffer.pdx's `0x01..0x03` and fileio.pdx's `0x11..0x13` sub-bands.
  Encoder pitfall discipline v0.36+: `capabilities: {...}` on every
  `pub let :sig = fn ...` (matches P0154 tracked in line#12); reserved-
  label prefixes (`mrl_`, `mpl_`, `mim_`, `mpa_`, `repl_`, `line_pud_`);
  no `test reg,reg`; no `and reg,imm64`; no 2-op `imul r,imm` (decimal
  parse uses `<<3 + <<1` = 10x fold); no scaled-index; byte-load
  `xor rax,rax; mov_b rax,[rN]`; byte-store `mov [rN], al`; movabs for
  the three imm64 constants (`0xFFFFFFFFFFFFFF20`,
  `0xFFFFFFFFFFFFFF21`, `0x656E694C69644500`) with every other
  immediate fitting imm32. SysV alignment: `_start` is @no_frame with
  zero pushes (PVH loader contract: entry rsp %16 == 0); helpers that
  make nested calls push an ODD number of callee-save regs (1 push in
  `main_parse_line` / `main_input_mode` / `main_print_addr` = +16 bytes
  incl. return addr, rsp %16 == 0 at every nested call site).

  **Known blocker (NOT introduced here; tracked separately):** line#12
  P0154 hotfix -- `src/buffer.pdx`'s 8 public function declarations
  are missing `capabilities: {},` between `effects:` and
  `justification:` and `@{}` on the outer signature. Until #12 lands
  the field-insertion patch, this REPL will NOT link even though
  main.pdx itself parses cleanly (main.pdx declares `capabilities:`
  on every fn per the requirement -- the blocker sits entirely in
  buffer.pdx). Build failure is EXPECTED at this landing; fixing #12
  unblocks the smoke round-trip.

  Closes #5.
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
