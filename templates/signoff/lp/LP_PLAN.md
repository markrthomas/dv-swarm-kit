# LP_PLAN.md — template (T3)

Low-power plan template for the tapeout-readiness program. Copy into the repo's
`syn/lp/`, beside `example.upf` (renamed) and `upf_lint.tcl`.

Two layers (*no artifact = not verified*):

1. **UPF consistency lint — OSS, runs here** (`make lp` → `upf_lint.tcl <design>.upf`): no
   OSS tool models UPF *semantics*; this catches a malformed/inconsistent UPF (dangling
   domains, supplies, iso/retention strategies, PST) before the licensed flow.
2. **Power-aware sim + LEC — `needs-license`** (VCS `-upf`; RTL↔UPF LEC). The
   `ucie_rdi_to_pcie6_pipe7` repo has a runnable Verilator *skeleton* (control/PMU only,
   no power intent) worth adopting as an intermediate OSS step.

## Power architecture (fill in)
- Always-on domain (PD_AON): the control/interface that must stay up to wake the rest.
- Switchable domain(s) (PD_SW): the datapath power-gated when idle; rail, header switch,
  isolation (clamp cross-domain outputs), retention (state kept across a cycle).
- Map UPF `-elements` and control signals (`pmu_pwr_en`/`pmu_iso_en`/`pmu_save`/
  `pmu_restore`) to the real hierarchy.

## Power states & sequence
P0 run / P1 iso / P2 shutoff (see `example.upf` PST). Sign-off sequence: **P0→P1→P2→P1→P0**,
asserting isolation-before-off, retention save/restore, no AON corruption, functional resume.

## Exit criteria (T3)
- UPF consistency lint PASS (here now).
- VCS `-upf` P0→P2→P0 clean; RTL↔UPF LEC clean; iso/retention vs. PMU sequence verified
  (needs-license). `-elements` confirmed against the synthesized hierarchy.
