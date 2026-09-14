#!/usr/bin/env bash
# line -- per-repo build script.
#
# Wave III (R63.M1-001 / #1) hygiene closer: line shipped README.md,
# LICENSE, CHANGELOG.md, and manifest.pdxproj from its first commit,
# but never a self-contained tools/build.sh of its own -- every
# sibling R100/R102 satellite in this org (ping, pdxwatch,
# svc-compositor, ...) ships one. line's actual ELF is produced by a
# DIFFERENT mechanism than the SAT_APPS_R102 build-user.sh loop those
# siblings rely on: paideia-os#1868 (R63.M1-007, closed 2026-08-25)
# embeds a prebuilt line.elf directly into src/kernel/bin_seeds.pdx
# via the R61 tmpfs-seed symbol-pair, and line does not appear in
# paideia-os's tools/build.sh SAT_APPS or SAT_APPS_R102 arrays. This
# script therefore exists for the same reason every sibling's does --
# local, in-repo build verification -- not because build-user.sh
# invokes it.
#
# manifest.pdxproj's own `sources:` list and single-output framing
# (`output = build-out/line`) describes a project-file build mode
# paideia-as's CLI does not actually implement (no `pdxproj`/manifest
# handling exists in tools/paideia-as's source at this floor) --
# manifest.pdxproj is descriptive documentation of intent, not a
# runnable build input. This script instead compiles every src/*.pdx
# individually via `paideia-as build --emit elf64`, mirroring
# pdxwatch's tools/build.sh (loose objects only; no final `ld` step,
# since line has no link.ld and its real linkage happens downstream
# in the bin_seeds.pdx embed, not in this repo).
#
# Resolves paideia-as via (in order):
#   1. $PAIDEIA_AS env var
#   2. sibling paideia-os checkout:
#      ../paideia-os/tools/paideia-as/target/release/paideia-as
#   3. $HOME/Development/PaideiaOS/tools/paideia-as/target/release/paideia-as
#   4. paideia-as on $PATH
#
# Requires paideia-as >= 0.36+ per manifest.pdxproj's own documented
# floor (mov_b narrow-load + @align attribute on .bss slots + cmp
# reg,imm32 staging via r11 above 0x7FFFFFFF).

set -euo pipefail
cd "$(dirname "$0")/.."

MIN_VERSION="0.36.0"

for arg in "$@"; do
    case "$arg" in
        --help|-h)
            cat <<'EOF'
usage: tools/build.sh

  Compiles every src/*.pdx into loose build-out/*.o ELF64 object
  files via `paideia-as build --emit elf64`. No final link step --
  line.elf is produced downstream by paideia-os#1868's bin_seeds.pdx
  embed, not by this script. No arguments accepted at this landing.
EOF
            exit 0
            ;;
        *)
            echo "[build] FAIL: unknown argument '$arg' (try --help)" >&2
            exit 2
            ;;
    esac
done

resolve_paideia_as() {
    if [ -n "${PAIDEIA_AS:-}" ] && [ -x "$PAIDEIA_AS" ]; then
        echo "$PAIDEIA_AS"; return
    fi
    for cand in \
        "../paideia-os/tools/paideia-as/target/release/paideia-as" \
        "$HOME/Development/PaideiaOS/tools/paideia-as/target/release/paideia-as"
    do
        if [ -x "$cand" ]; then
            echo "$cand"; return
        fi
    done
    if command -v paideia-as >/dev/null 2>&1; then
        command -v paideia-as; return
    fi
    return 1
}

version_ge() {
    # $1 = have, $2 = want ; returns 0 if have >= want
    printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

PA="$(resolve_paideia_as || true)"
if [ -z "$PA" ]; then
    echo "[build] FAIL: paideia-as not found. Set PAIDEIA_AS or clone paideia-os as a sibling." >&2
    exit 2
fi
VER="$("$PA" --version | awk '{print $2}')"
if ! version_ge "$VER" "$MIN_VERSION"; then
    echo "[build] FAIL: paideia-as $VER is too old, need >= $MIN_VERSION (found $PA)" >&2
    exit 2
fi
echo "[build] paideia-as $VER at $PA"

BUILD_DIR="build-out"
mkdir -p "$BUILD_DIR"

FAIL=0
COUNT=0

for pdx in src/*.pdx; do
    [ -f "$pdx" ] || continue
    COUNT=$((COUNT + 1))
    base="$(basename "$pdx")"
    obj="$BUILD_DIR/${base%.pdx}.o"
    if ! "$PA" build --emit elf64 "$pdx" -o "$obj" 2>&1; then
        FAIL=$((FAIL + 1))
    fi
done

if [ -d tests ]; then
    for pdx in tests/*.pdx; do
        [ -f "$pdx" ] || continue
        COUNT=$((COUNT + 1))
        obj="$BUILD_DIR/tests-$(basename "$pdx" .pdx).o"
        if ! "$PA" build --emit elf64 "$pdx" -o "$obj" 2>&1; then
            FAIL=$((FAIL + 1))
        fi
    done
fi

echo "[build] $COUNT source(s), $FAIL failure(s)"
[ "$FAIL" -eq 0 ] || exit 1
echo "[build] OK"
