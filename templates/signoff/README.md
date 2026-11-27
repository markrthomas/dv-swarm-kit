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
  a generic-gate netlist that the block's own **self-checking TB(s)** drive clean. `TB_<top>`
  takes a space-separated list and all must pass — **include the protocol-compliance bench**
  (on IP-axi-to-2apbs only it caught a pre-fix AW/AR deadlock at gate level). The same script
  has an **external-netlist mode** (`GLS_NETLIST_DIR`/`GLS_CELL_MODELS`) for post-route GLS of
  an open-PDK netlist (see `pnr/`); there a missing tool FAILs instead of skipping.
  Generic mode uses Yosys `simcells`/`simlib` + iverilog; catches synth/sim mismatch + X-prop the
  RTL sim can't. Set `TOPS`/`RTL`/`FRONTEND`/`TB_<top>`. Needs a Verilog/SV directed TB; a
  cocotb/UVM/C++-Verilator-only block uses the Verilator-netlist recipe instead (tag
  honestly, never a pass). SDF-timing GLS = separate step (`gls/T6_PLAN.md`).
- **`make ppa`** — T6 **PPA proxy** (`ppa/ppa.sh`): technology-independent area proxy (cells
  + flops) and timing proxy (`ltp` logic depth) per top; a tracked baseline that moves with
  the real post-PDK numbers. Real area/power/timing = needs-pdk (`ppa/PPA_PLAN.md`).
- **`make pkg`** — T7 **packaging** gate (`pkg/check_ipxact.sh`): per top, xmllint
  well-formed + required-element structure + a **hard IP-XACT↔RTL model-port match** (fails
  on drift). IP-XACT (1685-2014) components live in `pkg/ip-xact/<top>.xml`; the integration
  guide + config matrix + address/register map in `pkg/INTEGRATION.md`. Full XSD validation:
  `IPXACT_XSD=… make pkg`. Set `TOPS`/`RTL`/`XML_DIR`.
- **`make pkg-xsd`** — T7 **full XSD validation** (`pkg/pkg-xsd.mk` + `pkg/fetch_ipxact_xsd.py`
  + `pkg/ip-xact/schema/ieee-1685-2014.sha256`): fetches the IEEE 1685-2014 schema from
  Accellera → eda.org → a pinned GitHub copy (`edaa-org/IPXACT-Schema` @ `3c68329`), checks
  every file against the pinned SHA-256s (a real schema with a wrong hash is a hard FAIL,
  never a silent fallback), stores the files unmodified (the Accellera notice allows copying
  "WITHOUT modifications"), and validates each `<top>.xml`. Strict by default; PR CI may set
  `XSD_HOST_OPTIONAL=1` to report "XSD NOT RUN" during a host outage. Release runs are strict.
- **`make release`** — T7 **versioned release bundle** (`release/make_release.py`, per-repo
  `pkg/release.json` from `release/release.json.template`): deterministic tarball of the
  deliverables + every gate report present, with `MANIFEST.json` (SHA-256 per file, commit,
  contract tag/version, T0–T7 status from `syn/SIGNOFF.md`, tool versions); `--verify`
  re-checks a bundle. **`release/release.yml`**: push a `vX.Y.Z` tag on a green `main`
  commit → CI pre-flights (on main, CI green, notes match), requires every gate tool
  (a skip is not a pass), re-runs `RELEASE_GATES`, builds + verifies, publishes the GitHub
  release. Procedure: `release/RELEASE.md`.
- **`make pnr` / `make gls-sky130`** — T2/T6 **open-PDK silicon run** (`pnr/`): LibreLane
  (the OpenLane successor, 3.x) Classic flow on sky130A / sky130_fd_sc_hd per top
  (`pnr/config.json.template` → `syn/pnr/<top>/config.json`): synth, floorplan, PDN, place,
  CTS, route, extraction, 9-corner STA against the repo SDC, DRC (router/Magic/KLayout), LVS,
  antenna; `pnr/summarize.py` → `syn/pnr/reports/<top>.pnr.rpt` (area, power, setup/hold
  WNS/TNS + Fmax per corner). **FAIL** on an incomplete flow, missing GDS, any DRC/LVS error
  or any hold violation; setup is reported (Fmax) and gated only with `PNR_SETUP_GATE=1`
  (LibreLane's own setup checker is pointed at no corner with `SETUP_VIOLATION_CORNERS: [""]`
  — an empty list falls back to the PDK default). `pnr/gls_sky130.sh` then runs the GLS TBs on
  the routed netlist with the sky130 cell models (functional, unit delay). CI:
  `pnr/silicon.yml` (Docker; `--dockerized` needs a TTY, so `run_pnr.sh` wraps it in
  `script`). **SDC portability:** OpenSTA has no `remove_from_collection` (PrimeTime does) —
  branch on `[info commands remove_from_collection]` and fall back to `delete_from_list`.
  **Hold vs placeholder clocks:** when setup is badly violated against a placeholder clock,
  LibreLane's hold repair refuses buffers that worsen setup and can stop short of its margin,
  and routing then erodes what is left. Seen on cxl_lpddr5x_bridge: +0.045 ns post-CTS became
  −0.078 ns at ss. The remedy keeps the hold checker on all corners:
  `PL_RESIZER_ALLOW_SETUP_VIOS`, `RUN_POST_GRT_RESIZER_TIMING` and
  `GRT_RESIZER_ALLOW_SETUP_VIOS` = true. Hold is frequency-independent; setup is the owner's
  budget. **Multi-clock:** the report gives worst WNS per corner and no single Fmax.
  **Multi-TB / params:** post-route GLS FAILs a TB whose parameter override differs from what
  was routed (`SYNTH_PARAMETERS` → `GLS_NETLIST_PARAMS`).
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

### T6-sky130 / T7-release adoption (2026-11-27)
| repo | `make pkg-xsd` | `make release` + `release.yml` | `make pnr` (sky130) | post-route GLS |
|------|:--:|:--:|:--:|:--:|
| IP-axi-to-2apbs (pathfinder) | ✅ | ✅ **v1.0.0** released by CI | ✅ 2 tops, DRC/LVS clean, hold met, setup NOT MET @200 MHz (Fmax tt 189/181) | ✅ directed + compliance |
| axi4_to_dfi_ddr | ☐ | ☐ | ☐ | ☐ |
| cxl_lpddr5x_bridge | ☐ | ☐ | ☐ | ☐ |
| tilelink_to_AXI4 | ☐ | ☐ | ☐ | ☐ |
| ucie_rdi_to_pcie6_pipe7 (private) | ☐ | ☐ | ☐ (billed minutes: dispatch-only) | ☐ |

> Not yet wired into `sync.sh` automated vendoring — a deliberate later rollout, after the
> five pilot repos' sign-off PRs land.
