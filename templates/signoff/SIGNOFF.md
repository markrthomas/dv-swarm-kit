# SIGNOFF.md — <repo> tapeout sign-off checklist (TEMPLATE)

Tracks the eight T-gates from the workspace program (DESIGN_READINESS.md). A gate passes
only with a cited **artifact** (*no artifact = not verified*); authored-not-run items
(`needs-license` / `needs-pdk` / `needs-tool`) are run where the tool/PDK exists.

| Gate | Status | Artifact / where | Notes |
|------|--------|------------------|-------|
| **T0** spec freeze | ☐ | doc/PLAN | Wire-accurate, frozen interface + CSR map; cite spec clauses; provenance/visibility. |
| **T1** synthesizable | ☐ | `make synth` → sim/synth_*.v | Latch-free + cell/depth ceilings. Liberty map = needs-pdk. |
| **T1-CDC** | ☐/n-a | `make cdc` → sim/cdc.log | Multi-clock only: no crossing bypasses a sanctioned synchronizer. |
| **T2** STA | ☐ | syn/constraints/*.sdc, syn/sta/opensta.tcl | Clocks/groups, exceptions, I/O budgets. Run = needs-pdk. |
| **T3** low-power | ☐ | lp/ | UPF iso/level-shift/retention + power states; validate on a licensed sim; LEC. |
| **T4** DFT | ☐ | dft/ | Scan + ATPG target; MBIST per RAM. needs-license. |
| **T5** verif sign-off | ☐ | coverage + formal + UVM | Documented coverage model; UVM on a licensed sim; closure. |
| **T6** GLS + PPA | ☐ | — | SDF GLS; power; RTL↔netlist LEC; PPA vs target. needs-pdk. |
| **T7** integration/pkg | ☐ | pkg/ | IP-XACT; register map + RAL; integration guide; tagged release. |

Legend: ✅ passed · ◑ authored-not-run · ◐ partial/pathfind · ☐ not started.
