# line

An `ed`-style scriptable line editor for PaideiaOS. Category C tier-1 per
`design/tooling/plan.md` in the paideia-os monorepo. Roadmap wave R63,
milestone M1 per `design/roadmap/post-r60-daily-use-roadmap.md` §R63.

## Status (v1.1-D)

`v1.1-D` lands the R63.M1-006 success fingerprint in its final shape
(`line ok -- lines=<N>\n`, three sys_writes to fd 1) and declares the
`LINE PARSE FAIL\n` rodata marker for M1-002/M1-005 to wire when the
parser arrives. The v1.1-A witness phrase `line syscall-wire ok\n` is
retired. Newline count is computed once (line_buf[0..n], byte-scan
into r13 -- SysV callee-save, repurposed after argc-check) and carried
through the fingerprint sys_writes AND the v1.1-B semantic-pipe
marshalling; the pre-v1.1-D duplicate count loop inside the emit block
is retired.

`v1.1-B` (previous) is the semantic-pipe emission wire: on the
successful round-trip tail, `_start` emits a 56-byte
`LineEditRecord@0.1` (schema tag `0x656E694C69644500`) via
`sys_semantic_send` (SC+ ID 115, R107-M0-001) carrying `{lines_in,
lines_out, files_read, files_written, edit_count, session_start_ns,
session_end_ns}` before `sys_exit(0)`. Timestamps are raw `rdtsc` TSC
ticks until `sys_clock_now` lands; `edit_count == 0` always at v1.1-B
(no command grammar yet); `lines_out == lines_in` because the
round-trip is byte-for-byte. Error paths emit no record. See
`STATUS.md` §"v1.1-B honest-scope" for the full field-level caveat
table.

`v1.1-A` (previous) is the syscall-wire landing: `M1-001`'s STUB body
was retired and `_start` drove the `sys_open` / `sys_read` /
`sys_close` / `sys_open(O_CREAT|O_WRONLY|O_TRUNC)` / `sys_write` /
`sys_close` round-trip over a single positional argument. The tool
reads the argument file into a 4 KiB in-memory buffer, echoes the
bytes to `stdout`, then writes the same bytes back to the argument
path (touch-write) to prove the write half of the wire. No command
grammar, no address parser, no buffer-edit ops -- those land at
`M1-002` / `M1-003` per the roadmap.

## Behavior

    line <path>

* argc < 2 -> print `line: usage: line <path>\n` to fd 2, exit 2.
* `sys_open(path, O_RDONLY, 0)` fails -> `LINE READ FAIL: open\n` to
  fd 2, exit 3.
* `sys_read(fd, buf, 4096)` fails (rax < 0) -> `LINE READ FAIL: read\n`
  to fd 2, exit 3. A zero-length read is treated as an empty file (not
  an error).
* `sys_open(path, O_CREAT|O_WRONLY|O_TRUNC, 0644)` fails on the
  write-open -> `LINE WRITE FAIL: open\n` to fd 2, exit 4.
* `sys_write(fd, buf, n)` fails -> `LINE WRITE FAIL: write\n` to fd 2,
  exit 4.
* Happy path -> `line ok -- lines=<N>\n` to fd 1 (v1.1-D fingerprint,
  three sys_writes: prefix + `line_print_u64_dec` decimal + newline),
  then (v1.1-B) `sys_semantic_send(0x656E694C69644500, &record, 56)`
  emits a `LineEditRecord@0.1` into the kernel's semantic-pipe ring,
  then `sys_exit(0)`. `<N>` is the count of ASCII-`\n` bytes in the
  read buffer; empty input yields `lines=0` via the helper's single-
  '0' fast-path.

The R63.M1-006 fingerprint `line ok -- lines=<N>` is landed at v1.1-D.
The three canonical error markers `LINE READ FAIL` (READ FAIL: open,
READ FAIL: read), `LINE WRITE FAIL` (WRITE FAIL: open, WRITE FAIL:
write) are wired at v1.1-A. `LINE PARSE FAIL\n` rodata is declared at
v1.1-D and wires at M1-002/M1-005 when the parser body lands (exit
status 5 reserved for parse failures). The v1.1-B `LineEditRecord@0.1`
publication is independent of both the plain-ASCII fingerprint and the
error markers: it is a schema-bound sidecar for downstream
`postui-*`-shape tools rather than a human-readable line.

## Non-goals (deferred)

* Command grammar `a i d c p w q Q . , $` -- M1-002.
* Line-array buffer with 1-based addresses and edit ops -- M1-003.
* Distinct `w <path>` / `e <path>` paths -- M1-004.
* Interactive `:` prompt + line reader -- M1-005.
* Full `line ok -- lines=<N>` fingerprint on `q` -- M1-006.

## Layout

* `src/main.pdx` -- `Main::_start`, the single-file v1.1-A/B entry
  point. Grows into per-concern modules (`Argv`, `Buffer`, `Dispatch`,
  `Emit`, ...) as later milestones land.
* `manifest.pdxproj` -- `paideia-as build` manifest; the M1 build
  produces a single ELF at `build-out/line`.
* `caps.decl` -- capability manifest consumed by the shell's
  exec-time `cap_manifest_verify`.

## Toolchain floor

`paideia-as` v0.36+ (encoder-pitfalls v0.36+ standard: `mov_b` narrow
load mnemonic, `@align` on `.bss` slots, no `test reg,reg`, `cmp reg,
imm32` staged via `r11` above 0x7FFFFFFF, module-basename PascalCase).

## License

MIT. See `LICENSE`.
