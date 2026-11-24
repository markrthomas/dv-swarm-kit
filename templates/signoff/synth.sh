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
if [ "$FRONTEND" = slang ]; then
  yosys -q -p "plugin -i slang" >/dev/null 2>&1 || { echo "[SYNTH] yosys-slang absent — SKIP (needs-tool)"; exit 0; }
  READ="plugin -i slang; read_slang"
else
  READ="read_verilog -sv"
fi
rc=0
for TOP in $TOPS; do
  yosys -p "$READ $RTL; synth -top $TOP -flatten; stat; ltp -noff; write_verilog $OUT/synth_$TOP.v" > "$OUT/synth_$TOP.log" 2>&1
  if grep -qE '\$_DLATCH' "$OUT/synth_$TOP.log"; then echo "[SYNTH] $TOP FAIL: inferred latch!"; rc=1; continue; fi
  c=$(grep -oE '[0-9]+ cells$' "$OUT/synth_$TOP.log" | tail -1 | grep -oE '[0-9]+' || true)
  d=$(grep -oE 'length=[0-9]+' "$OUT/synth_$TOP.log" | tail -1 | grep -oE '[0-9]+' || true)
  st=PASS
  { [ -n "$c" ] && [ "$c" -gt "$SYNTH_MAX_CELLS" ]; } && { st="FAIL(cells>$SYNTH_MAX_CELLS)"; rc=1; }
  { [ -n "$d" ] && [ "$d" -gt "$SYNTH_MAX_DEPTH" ]; } && { st="FAIL(depth>$SYNTH_MAX_DEPTH)"; rc=1; }
  echo "[SYNTH] $TOP: latch-free, cells=${c:-?} depth=${d:-?} -> $st"
done
[ "$rc" -eq 0 ] && echo "[SYNTH] T1 gate PASSED."
exit $rc
