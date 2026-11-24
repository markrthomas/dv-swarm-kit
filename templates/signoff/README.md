# templates/signoff — canonical tapeout sign-off flow

Single source of truth for the **T1/T2 sign-off flow** adopted by the design-track DV
repos in the tapeout-readiness program (the workspace `DESIGN_READINESS.md`). This is
**adopt-once reference material** (like `swarm.env.example`) — it is **not** verbatim
vendored into every repo by `sync.sh` (that is what `kit/` is for). Copy what a repo
needs into its own `syn/` and tune it there.

Canonical pattern origin: `cxl_lpddr5x_bridge` (richest `make synth` + `make cdc`).

## The T-gate bar
`DESIGN_READINESS.md` defines gates **T0–T7** (spec-freeze, synth, STA, low-power, DFT,
verification sign-off, GLS/PPA, integration/packaging). DV_STANDARDS is the entry
criterion to T5, not the finish line. A gate passes only with a real **artifact**.

## What a design-track repo exposes
- **`make synth`** — T1 synthesizability gate (`synth.sh`): Yosys generic synth of each
  top, latch-free assert + cell/logic-depth ceilings, netlist artifact. OSS, no PDK.
  Set `TOPS`, `RTL`, `FRONTEND` (`verilog` | `slang` for package-based SV), ceilings.
- **`make cdc`** — structural CDC audit (`cdc_audit.ys.template`) for **multi-clock**
  designs: no crossing bypasses a sanctioned synchronizer. Single-clock → T1-CDC = n/a.
- **`syn/constraints/*.sdc`** — clocks/groups, exceptions, I/O budgets (T2 collateral).
- **`syn/sta/opensta.tcl`** — STA driver (OpenSTA pathfind / PrimeTime sign-off; needs-pdk).
- **`syn/SIGNOFF.md`** — the per-repo T0–T7 checklist (`SIGNOFF.md` template here).

## Tooling reality
Yosys/sby/verilator pathfind T1 (and T2/T6 on an open PDK). Liberty-mapped synth, real
STA, DFT/ATPG, power-aware UPF, GLS/PPA need commercial tools + a foundry PDK (and, for
some blocks, controlled interface specs) — authored here, run where that access exists.

## Adoption status (2026-11-23)
| repo | make synth | make cdc | SDC | SIGNOFF |
|------|:--:|:--:|:--:|:--:|
| cxl_lpddr5x_bridge | ✅ (origin) | ✅ | ✅ | ✅ |
| axi4_to_dfi_ddr | ✅ | ✅ (AXI↔DFI) | ✅ | ✅ |
| IP-axi-to-2apbs | ✅ (`make syn`) | n/a (single clk) | ✅ | ✅ |
| tilelink_to_AXI4 | ✅ (`make syn`, gen SV) | n/a (single clk) | ✅ | ✅ |
| ucie_rdi_to_pcie6_pipe7 | ✅ (slang) | formal (cdc_mc) | ✅ | ✅ |

> Not yet wired into `sync.sh` automated vendoring — a deliberate later rollout, after the
> five pilot repos' sign-off PRs land.
