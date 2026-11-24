#!/usr/bin/env bash
# synth.sh — canonical T1 synthesizability gate for a design-track DV repo.
#
# Part of the tapeout-readiness program (workspace DESIGN_READINESS.md). Adopt by
# copying into a repo's syn/ and setting the vars below (or a repo syn/signoff.env).
# Yosys generic synthesis of each top, asserting latch-free and gating cell count +
# longest-topological logic depth (a liberty-free critical-path proxy) against ceilings.
# Emits a flat gate netlist per top. No PDK needed; liberty-mapped synth is needs-pdk.
#
# Config (env or edit):
#   TOPS       space-separated top module names
#   RTL        space-separated source files (Verilog/SV)
#   FRONTEND   "verilog" (read_verilog -sv) | "slang" (read_slang; package-based SV)
#   SYNTH_MAX_CELLS / SYNTH_MAX_DEPTH  per-run ceilings (calibrate to the design)
set -euo pipefail
: "${TOPS:?set TOPS}"; : "${RTL:?set RTL}"
FRONTEND="${FRONTEND:-verilog}"
SYNTH_MAX_CELLS="${SYNTH_MAX_CELLS:-20000}"; SYNTH_MAX_DEPTH="${SYNTH_MAX_DEPTH:-80}"
OUT="${OUT:-sim}"; mkdir -p "$OUT"
command -v yosys >/dev/null || { echo "[SYNTH] yosys not on PATH; SKIP"; exit 0; }
# Normalize RTL to one space-separated line: a newline-separated list (e.g. from
# $(ls …)) is split by the yosys -p parser (newlines separate commands), leaving the
# reader with only the first file — which presents as a spurious "not a valid top".
RTL="$(printf '%s ' $RTL)"
if [ "$FRONTEND" = slang ]; then
  # slang (sv-elab) is integrated in Yosys >= 0.67 (native read_slang) or loadable as a
  # plugin in older Yosys. Prefer integrated; fall back to the plugin; else SKIP honestly.
  if yosys -q -p "read_slang" 2>&1 | grep -q "No such command"; then
    if yosys -q -p "plugin -i slang; read_slang" 2>&1 | grep -qE "No such command|Can't load module|cannot open"; then
      echo "[SYNTH] slang/sv-elab absent — SKIP (needs Yosys>=0.67 integrated, or the slang plugin)"; exit 0
    fi
    READ="plugin -i slang; read_slang"
  else
    READ="read_slang"
  fi
else
  READ="read_verilog -sv"
fi
rc=0
for TOP in $TOPS; do
  # select -assert-none makes the latch check authoritative (errors out, failing the run,
  # if any $dlatch / $_DLATCH_* survives) — the netlist is only written if it holds.
  if ! yosys -p "$READ $RTL; synth -top $TOP -flatten; stat; ltp -noff; \
        select -assert-none t:\$dlatch t:\$_DLATCH_*; write_verilog $OUT/synth_$TOP.v" \
        > "$OUT/synth_$TOP.log" 2>&1; then
    echo "[SYNTH] $TOP FAIL: elaboration/synth/latch-check — see $OUT/synth_$TOP.log"; rc=1; continue
  fi
  c=$(grep -oE '[0-9]+ cells$' "$OUT/synth_$TOP.log" | tail -1 | grep -oE '[0-9]+' || true)
  d=$(grep -oE 'length=[0-9]+' "$OUT/synth_$TOP.log" | tail -1 | grep -oE '[0-9]+' || true)
  st=PASS
  { [ -n "$c" ] && [ "$c" -gt "$SYNTH_MAX_CELLS" ]; } && { st="FAIL(cells>$SYNTH_MAX_CELLS)"; rc=1; }
  { [ -n "$d" ] && [ "$d" -gt "$SYNTH_MAX_DEPTH" ]; } && { st="FAIL(depth>$SYNTH_MAX_DEPTH)"; rc=1; }
  echo "[SYNTH] $TOP: latch-free, cells=${c:-?} depth=${d:-?} -> $st"
done
[ "$rc" -eq 0 ] && echo "[SYNTH] T1 gate PASSED."
exit $rc
