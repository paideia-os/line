# line -- status

**Wave:** R63 (user-space `ed`-style scriptable line editor -- paideia-os
`design/roadmap/post-r60-daily-use-roadmap.md` §R63; Category C tier-1
per `design/tooling/plan.md`).
**Current milestone:** v1.1-D (R63.M1-006 fingerprint `line ok --
lines=<N>\n` + LINE PARSE FAIL rodata marker) -- **landed**.
Previous: v1.1-B (semantic-pipe emission wire: `LineEditRecord@0.1`
via `sys_semantic_send` SC+ ID 115) -- landed. v1.1-A (syscall-wire;
retired the M1-001 STUB body) -- landed.
**Version:** 1.1.0-D (pre-tag; a signed 1.0.0 release closes at M5).

## Milestone checklist

### M1 -- syscall wire + real body + semantic-pipe

- [x] **M1-001** (v1.1-A) -- retired the STUB body; wired
      `sys_open` / `sys_read` / `sys_close` (read side) plus
      `sys_open(O_CREAT|O_WRONLY|O_TRUNC)` / `sys_write` / `sys_close`
      (write side); happy path emitted the fd-1 witness
      `line syscall-wire ok\n` before `sys_exit(0)` (retired at
      v1.1-D). Landed at 3edfa6f.
- [x] **v1.1-B** -- semantic-pipe emission wire:
      `LineEditRecord@0.1` (56 bytes, schema tag
      `0x656E694C69644500` -- 8-byte ASCII `LineEdit` marker) emitted
      via `sys_semantic_send` (SC+ ID 115, R107-M0-001 paideia-os
      #2350) on the happy-path tail, carrying
      `{lines_in, lines_out, files_read, files_written, edit_count,
      session_start_ns, session_end_ns}`. Session timestamps are raw
      `rdtsc` TSC ticks (see honest-scope §). Lines are counted as
      byte-`\n` scans over `line_buf[0..n]`; both `lines_in` and
      `lines_out` equal that count at v1.1-B because the round-trip
      is byte-for-byte. `edit_count` is always 0 (no command grammar
      yet; M1-002 lands `a i d c p w q Q . , $`). Error paths emit
      NO record (no session to describe; matches pdxsock v1.1-B
      posture).
- [ ] **M1-002** -- command grammar `a i d c p w q Q . , $`.
- [ ] **M1-003** -- line-array buffer with 1-based addresses + edit
      ops. When this lands, `lines_out` starts diverging from
      `lines_in` and `edit_count` starts reporting real counts.
- [ ] **M1-004** -- distinct `w <path>` / `e <path>` command paths.
      `files_read` / `files_written` start reporting real counts here
      once multiple files can be opened in one session.
- [ ] **M1-005** -- interactive `:` prompt + line reader. Wires the
      `LINE PARSE FAIL` marker declared at v1.1-D.
- [x] **M1-006** (v1.1-D) -- `line ok -- lines=<N>\n` fingerprint on
      the happy-path tail (three sys_writes to fd 1: prefix
      `line ok -- lines=` + variable decimal via `line_print_u64_dec`
      + newline). Newline count computed once (byte-scan of
      `line_buf[0..n]`) and held in r13 (SysV callee-save; repurposed
      after Step 2 argc-check), carried through the fingerprint AND
      the v1.1-B semantic-pipe marshalling -- the pre-v1.1-D
      duplicate count loop inside the emit block is retired.
      Retires the v1.1-A witness phrase `line syscall-wire ok\n`.
      `LINE PARSE FAIL\n` rodata declared here so the M1-005 body-
      edit wave is pure body-edit (no rodata churn). Empty input
      emits `line ok -- lines=0\n` via the helper's single-'0' fast-
      path. Error paths emit NO fingerprint. Exit-status inventory
      frozen: 0=OK, 2=usage, 3=READ FAIL, 4=WRITE FAIL, 5=PARSE FAIL
      (reserved). `q` command not yet in play (the fingerprint fires
      at the round-trip tail today; will move to the `q` handler at
      M1-005 without a wire-format change).

### M2 -- (deferred) module split + libpdx-audit

- [ ] **M2-001** -- Split `src/main.pdx` into `Argv` / `Buffer` /
      `Dispatch` / `Emit` per the file-header seams.
- [ ] **M2-002** -- libpdx-audit integration; add `audit_id` field to
      the `LineEditRecord` (schema bump to `@0.2`).

### M5 -- release

- [ ] **M5-001** -- dual-signed `manifest.pdxsig` + `CHANGELOG-1.0` +
      `.pdxdoc`.
- [ ] **M5-002** -- mirror push.

## v1.1-B honest-scope statement

v1.1-B emits `LineEditRecord@0.1` on the successful round-trip tail
only. The record shape (56 bytes, schema tag `0x656E694C69644500`) is
stable and matches `caps.decl.declares_output_schemas`, but four
fields carry honest-scope semantics at this landing:

1. **`session_start_ns` / `session_end_ns` are raw TSC ticks, not
   nanoseconds.** There is no user-facing `sys_clock_now` yet; the
   schema-shape name is preserved so a re-land is field-additive
   rather than field-renaming. Consumers can compute a per-run
   monotonic duration = `end - start` in TSC ticks; converting to
   wall-time ns needs a per-host TSC frequency the kernel does not
   publish. Same precedent as pdxsock v1.1-B and
   `src/kernel/core/fs/pdxfs_lite/write.pdx` (R25-M2-005 #919).
2. **`edit_count == 0` always.** No command grammar wired at v1.1-B
   (M1-002 lands `a i d c p w q Q . , $`); the round-trip performs
   zero edits by construction. Field will start reporting real
   counts at M1-003 close.
3. **`lines_out == lines_in` always.** v1.1-B writes the read
   buffer back byte-for-byte (M1-001 round-trip contract). The
   `lines_out` count will diverge from `lines_in` at M1-003 when the
   line-array buffer begins to apply edit ops.
4. **`files_read == 1`, `files_written == 1` always on the happy
   path.** v1.1-A/B opens exactly one input path and writes exactly
   one output path (touch-write to the same argument). Multi-file
   accounting lands at M1-004 when distinct `w <path>` / `e <path>`
   paths grow.

Error paths (`line_usage_err`, `line_open_read_err`, `line_read_err`,
`line_open_write_err`, `line_write_err`) emit NO record: there is no
session to describe, matching the pdxsock v1.1-B posture where a
failed connect / bind / listen / accept also emits nothing.

The `sys_semantic_send` return value (0 / `-EFAULT` / `-EINVAL`) is
intentionally discarded at the callsite: the round-trip is already
over, and any failure at this layer is a marshalling bug in
`src/main.pdx` (the 56-byte record is well within the [1, 240] byte
cap, and `line_record_buf` is a static rip-relative address that
never fails `user_ptr_ok`) rather than a per-run condition the caller
can act on. The sysno-115 handler's overwrite-oldest ring policy
means a downstream backup does not surface as `PIPE_FULL` at v1 --
an older record is silently displaced (documented explicitly at
`src/kernel/core/syscall/handlers/sys_semantic_send.pdx`).

## Encoder posture (paideia-as v0.36+)

Every constraint from v1.1-A holds unchanged (see `manifest.pdxproj`
`compliance` block). v1.1-B adds no new pitfall exposure:

- Emit block uses `cmp r11, 0` / `je` / `jne` for every zero-check
  (never `test r11, r11`).
- Byte load in the newline-count loop uses the
  `xor rax, rax; mov_b rax, [r9]` narrow-load idiom (mov_b does not
  zero-extend on its own; precedent
  `src/kernel/core/syscall/sys_umount.pdx` path-hash loop).
- All record-buffer stores use displacement form `[r10 + N]`, never
  scaled-index `[r10 + N*8]` (the encoder rejects the scaled-index
  form in some positions per the v0.36+ pitfall note).
- Schema tag `0x656E694C69644500` loaded as `mov rdi, imm64` (movabs;
  matches `pdxsock_schema_sock_session` at
  `pdxsock/src/main.pdx` line 820).
- Every new label prefixed `line_emit_` (reserved-label discipline;
  grep audit confirms no `line_emit_` hits elsewhere in `src/`).
