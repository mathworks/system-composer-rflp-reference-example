# 02 — Functional Architecture

Model: [`../architecture/functional/GalacticSoupFunctional.slx`](../architecture/functional/GalacticSoupFunctional.slx)
Interface dictionary: [`../architecture/functional/FunctionalInterfaces.sldd`](../architecture/functional/FunctionalInterfaces.sldd)

## 1. Decomposition rationale

The functional architecture answers *what* the factory must do, deliberately free of any statement of *how* (no equipment, staffing, or vendor choices). It decomposes the system into 12 verb-phrase functions chosen so that:

- Each function maps to a cohesive cluster of system requirements (see trace table below) — no function is required to satisfy requirements from unrelated stakeholder needs, and no requirement is left untraced.
- The functions mirror the physical value chain a soup batch and its ingredients actually travel through — inbound receiving, storage, prep, cooking, QA, packaging, dispatch — plus three cross-cutting functions that do not sit on the material path: inventory tracking, fleet operation, internal transport, and production coordination.
- Two requirements (gravity range/structural tolerance, and system coordination) were considered candidates to fold into neighboring functions but were instead promoted to their own functions — `CompensateGravity` and `CoordinateProduction` — because they are architecturally significant enough to warrant independent allocation, traceability, and (later) independent physical realization. See [`07_decision_log.md`](07_decision_log.md) ADR-005 and the coordination rationale below.
- Functional decomposition is kept flat (no sub-function hierarchy) at this abstraction level, since 12 functions is small enough to remain readable as a single diagram and each has a clear, non-overlapping SR allocation.

## 2. Function-to-system-requirement trace

| Function | Traced SRs | Purpose |
|---|---|---|
| ReceiveInboundDeliveries | SR-GS-017, SR-GS-018 | Accept inbound ingredient deliveries from the rocket fleet, in parallel across multiple rockets, within the turnaround window. |
| StoreIngredients | SR-GS-020, SR-GS-021 | Hold received ingredients in appropriate (cold/ambient) conditions with at least 72 hours of buffer capacity. |
| TrackInventory | SR-GS-010 | Monitor stock levels against consumption and emit reorder requests within the 1% accuracy bound. |
| PrepareIngredients | SR-GS-028 | Chop and weigh ingredients in a zone isolated from storage and cooking, sized to 200 bowls/hour equivalent. |
| CookSoup | SR-GS-001, SR-GS-002, SR-GS-022 | Cook at least 8 selectable recipes at a sustained rate that supports 200 bowls/hour overall throughput. |
| AssureQuality | SR-GS-007, SR-GS-008 | Detect contamination (≥99% sensitivity) and verify serving temperature (70-95 °C) before sealing/sign-off. |
| PackageSoup | SR-GS-009 | Seal soup into containers rated for 30-day interstellar transit. |
| DispatchShipments | SR-GS-005, SR-GS-006 | Generate a per-batch shipping manifest and load packaged goods onto transport within 10 minutes. |
| OperateDeliveryFleet | SR-GS-017, SR-GS-018, SR-GS-019 | Operate the rocket fleet itself: concurrent handling of ≥3 rockets, 20-minute turnaround, on-site refueling. |
| TransportMaterialsInternally | SR-GS-023, SR-GS-024 | Move materials between receiving, storage, prep, cooking, packaging, and dispatch at ≥90% automation. |
| CoordinateProduction | SR-GS-003, SR-GS-004, SR-GS-025, SR-GS-026, SR-GS-027 | Direct and sequence all other functions to meet throughput/automation/crew/startup/fault-tolerance and multi-objective coordination requirements. |
| CompensateGravity | SR-GS-015, SR-GS-016 | Sense and compensate for ambient gravity (0.1 g-12 g) so downstream functions operate nominally and structure survives sustained 12 g loading. |

Every one of the 28 system requirements traces to at least one function; requirements that constrain the whole system rather than one process step (SR-GS-003 automation, SR-GS-004 operator count, SR-GS-025 startup, SR-GS-026 fault tolerance, SR-GS-027 coordination) are allocated to `CoordinateProduction`, which is the only function with system-wide scope. The pure budget requirements (SR-GS-011..014: mass, power, cost, volume) are not allocated to any function — they are physical-layer constraints with no functional behavior of their own (see [`07_decision_log.md`](07_decision_log.md) ADR-006) and will be verified by roll-up analysis across the physical variants.

## 3. Interface definitions

Interfaces are defined abstractly in `FunctionalInterfaces.sldd` — they describe *what kind of information* flows between functions without committing to data types, units, or encoding (that typing is added at the logical layer; see [`03_logical_architecture.md`](03_logical_architecture.md)).

| Interface | Carries |
|---|---|
| MaterialFlow | Generic physical material moving along the primary chain (raw ingredients, in-process goods) between adjacent processing functions. |
| SoupBatch | A cooked batch of soup, identified by recipe, moving from `CookSoup` to `AssureQuality` to `PackageSoup`. |
| PackagedGoods | Sealed, packaged soup containers moving from `PackageSoup` to `DispatchShipments`. |
| ShipmentManifest | Per-batch manifest data (destination, contents) generated by `DispatchShipments` and consumed by `OperateDeliveryFleet`. |
| InventoryStatus | Ingredient stock-level information reported by `StoreIngredients` to `TrackInventory`. |
| OrderRequest | Root-level customer order intake and the reorder requests `TrackInventory` emits when stock runs low. |
| ControlDirective | The production directive `CoordinateProduction` fans out to every other function to direct their operation. |
| OperationalStatus | Status feedback that every function reports back to `CoordinateProduction`. |
| EnvironmentState | Ambient environment sensing/compensation state exchanged between `CompensateGravity` and the rest of the system. |

## 4. Flow description

**Primary material flow chain.** Ingredients and product move in a single directed chain:

```
OperateDeliveryFleet -> ReceiveInboundDeliveries -> StoreIngredients -> PrepareIngredients
   -> CookSoup -> AssureQuality -> PackageSoup -> DispatchShipments -> OperateDeliveryFleet
```

The chain closes on itself at the fleet: `OperateDeliveryFleet` both delivers inbound supplies to `ReceiveInboundDeliveries` and accepts outbound shipments from `DispatchShipments` for delivery to customers. Each link in the chain is a point-to-point `MaterialFlow`-family connection (typed more specifically as `SoupBatch` or `PackagedGoods` where the material has become soup or a sealed container).

**Control flow.** `CoordinateProduction` is the single system-wide controller: it fans a `ControlDirective` out to all 11 other functions and fans in an `OperationalStatus` from each of them (see [`07_decision_log.md`](07_decision_log.md) ADR-003 for why this is modeled as named ports rather than a merge block). This star topology keeps sequencing, throughput allocation, and fault response logic centralized and independently traceable to SR-GS-003, SR-GS-004, SR-GS-025, SR-GS-026, and SR-GS-027, without embedding coordination logic inside the process-step functions themselves.

**Inventory flow.** `StoreIngredients` reports `stockLevel` (an `InventoryStatus`) to `TrackInventory`, which evaluates it against the 1% accuracy requirement (SR-GS-010) and emits `reorderRequest` (an `OrderRequest`) as a root-level output (`ReorderRequests`), external to the fan-in/fan-out coordination star — reordering is a boundary interaction with an external supplier, not an internal control action.

**Internal transport.** `TransportMaterialsInternally` does not sit on the material chain itself; it is modeled as a coordination-style service that receives a `ControlDirective` and reports `OperationalStatus`, representing the automated movement capability (SR-GS-023, SR-GS-024) that physically underlies the point-to-point material links drawn between the processing functions. See [`07_decision_log.md`](07_decision_log.md) ADR-004.

**Environment/gravity flow.** The root input `AmbientGravity` feeds `CompensateGravity`, which reports `envStatus` (an `EnvironmentState`) into the `CoordinateProduction` status fan-in, allowing production coordination to account for gravity-driven operating constraints (SR-GS-015, SR-GS-016) alongside throughput and fault status.

**Root-level interface.**

| Port | Direction | Interface |
|---|---|---|
| CustomerOrders | in | OrderRequest |
| InboundSupplies | in | MaterialFlow |
| AmbientGravity | in | EnvironmentState |
| OutboundShipments | out | PackagedGoods / ShipmentManifest |
| ReorderRequests | out | OrderRequest |
