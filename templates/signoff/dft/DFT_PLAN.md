# DFT_PLAN.md — template (T4)

Design-for-test plan template for the tapeout-readiness program. Copy into the repo's
`syn/dft/`, fill in the design facts, and keep it beside `scan_readiness.sh`.

Two layers (*no artifact = not verified*):

1. **Scan-readiness audit — OSS, runs here** (`make dft` → `scan_readiness.sh`): on the
   synthesized netlist, HARD-gate latch-free + no combinational loops, and report the
   flop/scan-chain inventory, reset controllability, async set/reset, and RAM/MBIST count.
2. **Scan insertion + ATPG — `needs-license`** (DFT Compiler / TestMAX or Tessent + PDK).

## Design facts (fill in)
- Clock domain(s) and reset(s): ___ (single clock ⇒ one scan clock; multi-clock ⇒ clock
  grouping + lockup latches between chains in different domains).
- Tops: ___ . Memories/RAMs: ___ (each needs MBIST).

## Scan insertion + ATPG recipe (`needs-license`)
1. Full-scan muxed-D; N balanced chains + compression if the pin budget needs it.
2. One scan clock per clock domain; lockup latches on cross-domain chain hops.
3. Async set/reset gated by scan-enable (held inactive during shift/capture).
4. Coverage: stuck-at ≥ 99%, transition ≥ 90%; untestable faults accounted.
5. Flow: `insert_dft` → pre/post-scan LEC → ATPG (stuck-at, transition) → pattern GLS (SDF).

## Exit criteria (T4)
- Scan-readiness audit PASS on every top (here now).
- Post-scan LEC clean; ATPG coverage met; pattern GLS clean (needs-license).
