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
- **`make lp`** — T3 low-power UPF **consistency** lint (`lp/upf_lint.tcl` on the repo's
  `*.upf`): no OSS tool models UPF semantics, so this catches a malformed/inconsistent UPF
  (dangling domains/supplies/strategies/PST) before `VCS -upf` (needs-license). Template
  UPF (`lp/example.upf`) + `lp/LP_PLAN.md` here.
- **`make dft`** — T4 DFT **scan-readiness** audit (`dft/scan_readiness.sh`) on the
  synthesized netlist: HARD latch-free + no combinational loops, plus a scan-planning
  inventory (flop/scan-chain count, reset controllability, async set/reset, RAM/MBIST).
  Set `TOPS`/`RTL`/`FRONTEND`. Scan insertion + ATPG = needs-license (`dft/DFT_PLAN.md`).
- **`make gls`** — T6 **zero-delay gate-level sim** (`gls/gls.sh`): each top synthesizes to
  a generic-gate netlist that the block's own **self-checking directed TB** drives clean
  (Yosys `simcells`/`simlib` models + iverilog) — catches synth/sim mismatch + X-prop the
  RTL sim can't. Set `TOPS`/`RTL`/`FRONTEND`/`TB_<top>`. Needs a Verilog/SV directed TB; a
  cocotb/UVM/C++-Verilator-only block uses the Verilator-netlist recipe instead (tag
  honestly, never a pass). SDF-timing GLS + Liberty map = needs-pdk (`gls/T6_PLAN.md`).
- **`make ppa`** — T6 **PPA proxy** (`ppa/ppa.sh`): technology-independent area proxy (cells
  + flops) and timing proxy (`ltp` logic depth) per top; a tracked baseline that moves with
  the real post-PDK numbers. Real area/power/timing = needs-pdk (`ppa/PPA_PLAN.md`).
- **`make pkg`** — T7 **packaging** gate (`pkg/check_ipxact.sh`): per top, xmllint
  well-formed + required-element structure + a **hard IP-XACT↔RTL model-port match** (fails
  on drift). IP-XACT (1685-2014) components live in `pkg/ip-xact/<top>.xml`; the integration
  guide + config matrix + address/register map in `pkg/INTEGRATION.md`. Full XSD validation:
  `IPXACT_XSD=… make pkg`. Set `TOPS`/`RTL`/`XML_DIR`.
- **`syn/SIGNOFF.md`** — the per-repo T0–T7 checklist (`SIGNOFF.md` template here).

## Tooling reality
Yosys/sby/verilator pathfind T1 (and T2/T6 on an open PDK). Liberty-mapped synth, real
STA, DFT/ATPG, power-aware UPF, GLS/PPA need commercial tools + a foundry PDK (and, for
some blocks, controlled interface specs) — authored here, run where that access exists.

## Adoption status (2026-11-25)
| repo | make synth | make cdc | SDC | make lp (T3) | make dft (T4) | SIGNOFF |
|------|:--:|:--:|:--:|:--:|:--:|:--:|
| cxl_lpddr5x_bridge | ✅ (origin) | ✅ | ✅ | ☐ | ☐ | ✅ |
| axi4_to_dfi_ddr | ✅ | ✅ (AXI↔DFI) | ✅ | ☐ | ☐ | ✅ |
| IP-axi-to-2apbs | ✅ (`make syn`) | n/a (single clk) | ✅ | ✅ (template) | ✅ (template) | ✅ |
| tilelink_to_AXI4 | ✅ (`make syn`, gen SV) | n/a (single clk) | ✅ | ☐ | ☐ | ✅ |
| ucie_rdi_to_pcie6_pipe7 | ✅ (slang) | formal (cdc_mc) | ✅ | ◑ (test/upf) | ☐ | ✅ |

### T6 / T7 adoption
| repo | make gls (T6) | make ppa (T6) | make pkg (T7) |
|------|:--:|:--:|:--:|
| IP-axi-to-2apbs (pathfinder) | ✅ (2 tops) | ✅ | ✅ (53/53 ×2) |
| axi4_to_dfi_ddr | ✅ (chparam override) | ✅ | ✅ (71/71) |
| cxl_lpddr5x_bridge | ◐ authored, needs-pdk¹ | ✅ | ✅ (22/22) |
| tilelink_to_AXI4 | ◐ recipe (Verilator)² | ✅ (3 tops) | ✅ (53/36/68) |
| ucie_rdi_to_pcie6_pipe7 | ☐ (slang; Actions-quota) | ☐ | ☐ |

> T3/T4 pathfound on **IP-axi-to-2apbs** (`syn/lp/`, `syn/dft/`) and promoted here; #5 has
> authored UPF (`test/upf/`). **T6/T7 pathfound on IP-axi-to-2apbs and rolled to #1/#4/#2**
> (PRs 2026-11-25). The pathfinding on #1 hardened the GLS template: it now auto-extracts the
> TB's **behavioural** integer param overrides and synthesizes the netlist at them (`chparam`)
> and emits each RTL param as its own `parameter …;` shim (preserving type keyword + ordered
> dependent defaults), plus a `TB_EXTRA` hook for non-synth checkers the TB instantiates.
> `make lp`/`make dft`/`make gls`/`make ppa`/`make pkg` are OSS-runnable; `-upf` sim, scan/ATPG,
> SDF GLS, real PPA/STA and RTL↔netlist LEC are needs-license/needs-pdk. #5 (private) waits on
> the GitHub Actions quota reset.
>
> ¹ **cxl_lpddr5x_bridge T6-GLS:** OSS zero-delay GLS does not close — the unreset dual-clock
> async-FIFO RAM (lowered to registers by generic synth) reads X in the smoke test
> (X-pessimism, **not** a design bug: RTL sim + formal pass; the sibling CDC block
> axi4_to_dfi_ddr passes GLS). Authored + documented (`syn/gls/T6_PLAN.md`), **not** forced
> green, **not** in CI; clean run (SDF GLS + compiled RAM) is needs-pdk.
> ² **tilelink_to_AXI4 T6-GLS:** the iverilog gate needs a Verilog directed self-checking TB;
> this Chisel block's TBs are C++ Verilator harnesses, so the Verilator-netlist recipe is
> authored instead (`syn/gls/T6_PLAN.md`) — no hollow `make gls` wired.

> Note: the `synth.sh` here passes the source list to `read_slang` as **one
> space-joined token** — a newline-separated list (`$(ls …)`) is split by the yosys
> `-p` parser (newlines separate commands), leaving `read_slang` with only the first
> file and a spurious "`<top>` is not a valid top-level module". The template also
> auto-detects slang whether **integrated** (Yosys ≥ 0.67 native `read_slang`) or a
> **plugin**. Both behaviours are built into `templates/signoff/synth.sh`.

> Not yet wired into `sync.sh` automated vendoring — a deliberate later rollout, after the
> five pilot repos' sign-off PRs land.
