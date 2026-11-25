# Integration guide — <block> (template)

Tapeout-readiness program **T7** (integration / packaging) deliverable. This guide + the
IP-XACT in `ip-xact/` are what an SoC integrator needs to instance the IP. All interface
facts here must match the frozen contract (`../doc/design_contract.md` or equivalent); the
IP-XACT port list is kept in sync with the RTL by `make pkg`. Replace every `<...>` below.

## IP variants

| Top (module / IP-XACT name) | Use when |
|---|---|
| `<top-a>` | <when to use variant A> |
| `<top-b>` | <when to use variant B> |

## Interfaces

| Interface | Role | Notes |
|---|---|---|
| `<IF0>` | <master/slave of which protocol> | <notes> |
| `<CLK>` | clock | <domains> |
| `<RSTn>`| reset | <polarity / sync-ness> |

## Clock / reset / power

- **Clock:** <domains>; constrain with `../syn/constraints/<name>.sdc` (T2). For a
  multi-clock block, cite the T1-CDC audit (`make cdc`) and name each domain.
- **Reset:** <polarity, async/sync assert/release>; false-path in the SDC; driven from the
  SoC reset controller.
- **Power:** the T3 power intent (`../syn/lp/<name>.upf`) models <domains/supplies>. If the
  SoC does not power-gate this IP, tie it into a single always-on domain.

## Address / register map

<For a memory-mapped target: the address decode and windows. For a pure protocol bridge
with no CSRs: state that there is no CSR RAL and the "register map" is the address decode.
For a block with real control/status registers: generate a RAL / register map and cite it.>

## Parameters / configuration matrix

| Parameter | Default | Contract | Meaning |
|---|---|---|---|
| `<PARAM>` | <default> | <fixed / may vary> | <meaning> |

State which configurations are supported vs out-of-contract.

## Consuming the package

- **IP-XACT** (`ip-xact/<top>.xml`): IEEE 1685-2014 components — bus interfaces (by VLNV,
  resolved from your AMBA/protocol library), the full model port list, the memory map, and
  the parameter set. Import into an IP-XACT-aware tool (e.g. Kactus2 or a vendor packager).
- **RTL** source is referenced from each component's `fileSet`.
- **Validate** with `make pkg` (`pkg/check_ipxact.sh`): XML well-formedness +
  required-element structure + a hard IP-XACT↔RTL model-port match (fails on drift).
  Optional full XSD validation: `IPXACT_XSD=/path/to/index.xsd make pkg`.

## Sign-off cross-reference

See `../syn/SIGNOFF.md` for the T0–T7 status. Items needing a PDK or a licensed tool (real
STA, SDF-timing GLS, real PPA, scan insertion + ATPG, power-aware sim) are tagged there and
are out of scope for this OSS package.
