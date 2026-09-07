# line

An `ed`-style scriptable line editor for PaideiaOS. Category C tier-1 per
`design/tooling/plan.md` in the paideia-os monorepo. Roadmap wave R63,
milestone M1 per `design/roadmap/post-r60-daily-use-roadmap.md` §R63.

## Status (v1.1-A)

`v1.1-A` is the syscall-wire landing: `M1-001`'s STUB body is retired and
`_start` now drives a real `sys_open` / `sys_read` / `sys_close` /
`sys_open(O_CREAT|O_WRONLY|O_TRUNC)` / `sys_write` / `sys_close`
round-trip over a single positional argument. The tool at this landing
reads the argument file into a 4 KiB in-memory buffer, echoes the bytes
to `stdout` so the caller can see the read succeeded, then writes the
same bytes back to the argument path (touch-write) to prove the write
half of the wire. No command grammar, no address parser, no
buffer-edit ops -- those land at `M1-002` / `M1-003` per the roadmap.

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
* Happy path -> `line syscall-wire ok\n` to fd 1, `sys_exit(0)`.

The `line syscall-wire ok` fingerprint is a v1.1-A-specific witness
that both syscall halves executed. The R63.M1-006 fingerprint
`line ok -- lines=<N>` and the four canonical error markers
(`LINE READ FAIL`, `LINE WRITE FAIL`, `LINE PARSE FAIL`) land in their
final shape when the interactive command loop wires up at M1-005.

## Non-goals (deferred)

* Command grammar `a i d c p w q Q . , $` -- M1-002.
* Line-array buffer with 1-based addresses and edit ops -- M1-003.
* Distinct `w <path>` / `e <path>` paths -- M1-004.
* Interactive `:` prompt + line reader -- M1-005.
* Full `line ok -- lines=<N>` fingerprint on `q` -- M1-006.

## Layout

* `src/main.pdx` -- `Main::_start`, the single-file v1.1-A entry point.
  Grows into per-concern modules (`Argv`, `Buffer`, `Dispatch`, ...) as
  later milestones land.
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
