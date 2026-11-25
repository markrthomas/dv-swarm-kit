# ip-xact/ — IP-XACT (IEEE 1685-2014) components (template notes)

One `<top>.xml` per top module, each an IEEE 1685-2014 `ipxact:component`. These are
repo-specific (the port list is the design's), so the kit does **not** vendor a full XML —
author one per top and let `make pkg` (`../check_ipxact.sh`) keep it honest.

## Worked reference
`IP-axi-to-2apbs/pkg/ip-xact/axi4_to_apb4_2x_{simple,burst}.xml` (the flow pathfinder) are
complete 53-port AMBA examples: AXI4 slave + 2× APB4 master + clock + reset bus interfaces,
parametric port vectors, a memory map, address spaces, a fileSet, and the parameter set.
Copy one and adapt.

## Required shape (what `check_ipxact.sh` enforces)
- Namespace `http://www.accellera.org/XMLSchema/IPXACT/1685-2014`, prefix `ipxact:`.
- Top-level: `ipxact:vendor`, `ipxact:library`, `ipxact:name`, `ipxact:version` (the VLNV),
  `ipxact:busInterfaces`, `ipxact:model`.
- `ipxact:model/ipxact:ports` must list **exactly** the RTL module's ports — one
  `<ipxact:port><ipxact:name>NAME</ipxact:name>…` each. This set is diffed against the RTL
  (fails on any drift). Port **widths** are parametric `ipxact:vector` expressions (e.g.
  `DATA_WIDTH-1 : 0`) reviewed against the design contract, not re-derived by the gate.
- `ipxact:busInterfaces` reference AMBA (or your protocol's) bus/abstraction definitions by
  VLNV, resolved from the integrator's library — they are not redistributed here.

## Skeleton
```xml
<?xml version="1.0" encoding="UTF-8"?>
<ipxact:component xmlns:ipxact="http://www.accellera.org/XMLSchema/IPXACT/1685-2014">
  <ipxact:vendor>markrthomas</ipxact:vendor>
  <ipxact:library>LIB</ipxact:library>
  <ipxact:name>TOP</ipxact:name>
  <ipxact:version>1.0</ipxact:version>
  <ipxact:busInterfaces> … </ipxact:busInterfaces>
  <ipxact:model>
    <ipxact:ports>
      <ipxact:port><ipxact:name>CLK</ipxact:name>
        <ipxact:wire><ipxact:direction>in</ipxact:direction></ipxact:wire></ipxact:port>
      <!-- one per RTL port -->
    </ipxact:ports>
  </ipxact:model>
  <ipxact:fileSets> … <ipxact:file><ipxact:name>../../src/TOP.v</ipxact:name> … </ipxact:fileSets>
  <ipxact:parameters> … </ipxact:parameters>
</ipxact:component>
```
