# T6 — GLS + PPA plan (template)

T6 is the post-synthesis sign-off: prove the **gate netlist** (not just the RTL) is
functionally correct and characterise its **PPA** (power / performance / area). Copy this
into a repo's `syn/gls/` and replace `<top>` / block-specific text.

## What runs here (OSS, no PDK) — real artifacts

| Step | Command | Artifact | Proves |
|------|---------|----------|--------|
| **Zero-delay GLS** | `make gls` (`syn/gls/gls.sh`) | `syn/gls/reports/<top>.gls.rpt` | The synthesized generic-gate netlist **simulates correctly**: the block's own self-checking directed testbench passes when driven against the netlist (Yosys `simcells.v`/`simlib.v` model the generic cells), not the RTL. Catches synth/sim mismatch, lost initialization, and X-propagation. |
| **PPA proxy** | `make ppa` (`syn/ppa/ppa.sh`) | `syn/ppa/reports/<top>.ppa.rpt` | Technology-independent PPA baseline: generic cell count + flop count (area proxy), longest topological logic path / `ltp` (timing proxy). Moves monotonically with real numbers; tracked across revisions. |

GLS mechanics: `synth` constant-folds the top's parameters away, but a directed TB may
instantiate the DUT with named parameter overrides (at the RTL defaults). `gls.sh`
re-inserts the RTL top's parameter defaults as a no-op shim (read from the RTL header, so
it self-maintains) to keep the override legal. Netlists and sim binaries land in
`syn/gls/build/` (gitignored); only the `.rpt` summaries are the tracked artifact, and CI
uploads the full `reports/` tree.

**Applicability of the OSS GLS path.** `gls.sh` (Yosys netlist + iverilog + a Verilog/SV
*directed self-checking* TB) fits any block with such a TB. A block whose only
self-checking TB is a **cocotb / UVM / C++-Verilator** harness (e.g. a Chisel-generated
design) cannot use this path as-is: Verilate the Yosys netlist + `simcells`/`simlib`
against the existing harness instead, and until that is wired, tag T6-GLS honestly as
"recipe authored, OSS run deferred" — never a pass. The PPA proxy (pure Yosys synth) runs
on any synthesizable RTL regardless of TB style.

## What is deferred — `needs-pdk`

Real T6 sign-off needs a standard-cell library + a place-and-route flow. Authored as the
recipe and run where a PDK exists (open: sky130 + OpenROAD/OpenSTA; or a foundry PDK +
PrimeTime/PrimePower/Fusion Compiler):

1. **Liberty-mapped synthesis** — `yosys ... abc -liberty <pdk>.lib` → a real standard-cell
   netlist (vs the generic-cell netlist used here).
2. **SDF-annotated (timing) GLS** — re-run the TBs on the mapped netlist with
   `$sdf_annotate` back-annotation from STA; proves functional correctness *at timing*,
   including setup/hold and glitch behaviour the zero-delay GLS here cannot see.
3. **STA sign-off** — OpenSTA/PrimeTime with the Liberty + the `syn/constraints/*.sdc`
   already authored at T2: setup+hold clean at PVT corners, Fmax per clock.
4. **Area + power** — post-P&R area (µm²) and power (mW) from OpenROAD/PrimePower using
   switching activity (VCD/SAIF) captured from the GLS run.
5. **RTL↔netlist LEC** — formal equivalence of the mapped netlist vs RTL
   (Cadence Conformal / Synopsys Formality). The OSS `yosys equiv` flow does **not** close
   on the generic netlist because generic `synth` re-encodes state (bounded-equivalence BMC
   is a possible OSS follow-up, but LEC sign-off is a licensed-tool step).
