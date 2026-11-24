#!/usr/bin/env bash
# scan_readiness.sh — canonical T4 DFT scan-readiness audit (OSS pathfinder, Yosys).
#
# Part of the tapeout-readiness program (workspace DESIGN_READINESS.md). Adopt by copying
# into a repo's syn/dft/ and setting the vars below. Real scan insertion + ATPG need
# commercial tools (DFT Compiler / TestMAX / Tessent) + a PDK (needs-license — see the
# repo's DFT_PLAN.md). What runs HERE, no PDK, is the structural scan-readiness audit:
# the conditions that must hold BEFORE scan insertion, on the synthesized netlist.
#
# HARD gates (fail => NOT scan-ready):
#   - latch-free (a D-latch is not scannable); no combinational loops (ATPG can't justify).
# REPORTED (scan-planning inputs): flop/scan-chain count, reset controllability,
#   async set/reset count, memory/RAM (MBIST) count.
#
# Config (env or edit):
#   TOPS      space-separated top module names
#   RTL       space-separated source files
#   FRONTEND  "verilog" (read_verilog -sv) | "slang" (read_slang; package-based SV)
#   OUT       report dir (default syn/dft/reports)
set -euo pipefail
: "${TOPS:?set TOPS}"; : "${RTL:?set RTL}"
FRONTEND="${FRONTEND:-verilog}"; OUT="${OUT:-syn/dft/reports}"; mkdir -p "$OUT"
command -v yosys >/dev/null || { echo "[DFT] yosys not on PATH; SKIP"; exit 0; }
# Space-join: a newline-separated list (e.g. $(ls …)) is split by the yosys -p parser.
RTL="$(printf '%s ' $RTL)"

# Frontend / slang detection (integrated in Yosys>=0.67, else plugin).
if [ "$FRONTEND" = slang ]; then
  if yosys -q -p "read_slang" 2>&1 | grep -q "No such command"; then
    if yosys -q -p "plugin -i slang; read_slang" 2>&1 | grep -qE "No such command|Can't load module|cannot open"; then
      echo "[DFT] slang/sv-elab absent — SKIP (needs Yosys>=0.67 integrated, or the slang plugin)"; exit 0
    fi
    PRE="plugin -i slang; "; READTOP="read_slang --top"
  else
    PRE=""; READTOP="read_slang --top"
  fi
else
  PRE=""; READTOP=""
fi

rc=0
for TOP in $TOPS; do
  echo "[DFT] === $TOP ==="
  log="$OUT/$TOP.dft.log"; stat="$OUT/$TOP.stat.txt"; rpt="$OUT/$TOP.scan.rpt"
  if [ "$FRONTEND" = slang ]; then READ="${PRE}$READTOP $TOP $RTL"
  else READ="read_verilog -sv $RTL; hierarchy -check -top $TOP"; fi
  if ! yosys -q -l "$log" -p "
      $READ
      proc; opt -full
      synth -top $TOP -flatten
      select -assert-none t:\$dlatch t:\$_DLATCH_*
      check -assert
      tee -o $stat stat
  "; then
    echo "[DFT] $TOP: FAIL — latch inferred or combinational loop (see $log)"; rc=1; continue
  fi
  read -r tot nores async lat mem < <(awk '
    $2 ~ /^\$_DLATCH/ {lat+=$1}
    $2 ~ /^\$_S?DFF/   {tot+=$1;
        if ($2 ~ /^\$_DFF_[NP]_$/ || $2 ~ /^\$_DFFE_[NP][NP]_$/) nores+=$1;
        if ($2 ~ /^\$_DFFSR/ || $2 ~ /^\$_DFF_[NP][NP][01]_$/ || $2 ~ /^\$_DFFE_[NP][NP][01][NP]_$/) async+=$1 }
    $2 ~ /^\$mem/      {mem+=$1}
    END{printf "%d %d %d %d %d\n", tot+0, nores+0, async+0, lat+0, mem+0}' "$stat") || true
  res=$(( tot - nores )); pct=0; [ "$tot" -gt 0 ] && pct=$(( res * 100 / tot ))
  {
    echo "# $TOP — scan-readiness report (T4, OSS structural audit)"
    echo "# generated $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo
    echo "HARD GATES"
    echo "  latch-free ................. PASS (0 D-latches)"
    echo "  no combinational loops ..... PASS (yosys check -assert)"
    echo
    echo "SCAN-PLANNING INVENTORY"
    echo "  flip-flops (scan length) ... $tot"
    echo "    reset-controllable ....... $res (${pct}%)"
    echo "    no set/reset ............. $nores"
    echo "    async set/reset .......... $async"
    echo "  latches (must be 0) ........ $lat"
    echo "  memory arrays (MBIST) ...... $mem"
  } > "$rpt"
  echo "[DFT] $TOP: scan-ready — flops=$tot reset-controllable=${pct}% async_sr=$async mem=$mem (report: $rpt)"
done
[ $rc -eq 0 ] && echo "[DFT] T4 scan-readiness audit PASSED (OSS; scan insertion + ATPG = needs-license)."
exit $rc
