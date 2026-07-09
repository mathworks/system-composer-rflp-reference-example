# 03 — Logical Architecture

Model: [`../architecture/logical/GalacticSoupLogical.slx`](../architecture/logical/GalacticSoupLogical.slx)
Interface dictionary: [`../architecture/logical/LogicalInterfaces.sldd`](../architecture/logical/LogicalInterfaces.sldd)

## 1. Logical components

The logical architecture assigns each functional role to a solution-level logical component — a named unit of the eventual solution ("a storage unit," "a quality control unit") without yet committing to specific hardware, vendor, or implementation technology. Components communicate over the same topology as the functional layer, but interfaces are now typed (see §3) rather than abstract.

| Logical component |
|---|
| ReceivingDock |
| IngredientStorageUnit |
| InventoryManagementSystem |
| PrepStation |
| CookingUnit |
| QualityControlUnit |
| PackagingUnit |
| ShippingBay |
| RocketFleetSystem |
| MaterialTransportSystem |
| ProductionControlSystem |
| GravityCompensationSystem |

## 2. Function → logical realization

| Function (functional layer) | Logical component | Realization notes |
|---|---|---|
| ReceiveInboundDeliveries | ReceivingDock | 1:1 — dock accepts inbound material handling. |
| StoreIngredients | IngredientStorageUnit | 1:1 — storage with cold/ambient zoning. |
| TrackInventory | InventoryManagementSystem | 1:1 — stock accounting and reorder logic. |
| PrepareIngredients | PrepStation | 1:1 — isolated prep zone. |
| CookSoup | CookingUnit | 1:1 — recipe execution at throughput. |
| AssureQuality | QualityControlUnit | 1:1 — contamination/temperature verification. |
| PackageSoup | PackagingUnit | 1:1 — sealing into transit containers. |
| DispatchShipments | ShippingBay | 1:1 — manifesting and load-out. |
| OperateDeliveryFleet | RocketFleetSystem | 1:1 — fleet operations, turnaround, refueling. |
| TransportMaterialsInternally | MaterialTransportSystem | 1:1 — internal automated movement. |
| CoordinateProduction | ProductionControlSystem | 1:1 — system-wide command/status hub. |
| CompensateGravity | GravityCompensationSystem | 1:1 — gravity sensing/compensation. |

**Why 1:1 realization is acceptable at this level.** Each function in the functional architecture already represents a cohesive unit of behavior with a clean, non-overlapping SR allocation (see [`02_functional_architecture.md`](02_functional_architecture.md) §2). At the system level of this factory, no function is so fine-grained that multiple functions should merge into one logical component, and no function is so broad that it needs to split across multiple logical components. A 1:1 mapping therefore preserves full traceability from SR through function to logical component with no loss of fidelity, and defers all real architectural choice — how many parallel lines, what automation level, what redundancy — to the physical layer, where it belongs given that those choices are the axis of the physical variant trade study (see [`04_physical_variants.md`](04_physical_variants.md)). This is recorded as [`07_decision_log.md`](07_decision_log.md) ADR-002. A 1:1 mapping is a deliberate choice appropriate to this abstraction level, not a default; if the logical layer needed to introduce solution concepts that don't correspond to a single function (e.g., splitting one function across two logical units, or merging several functions behind one shared logical component), the mapping would depart from 1:1 at that point.

## 3. Logical interface definitions

`LogicalInterfaces.sldd` gives concrete, typed structure to the abstract functional interfaces. Functional interfaces that represented a single generic concept over the whole material chain are specialized into stage-appropriate logical types:

| Logical interface | Realizes / specializes | Used between |
|---|---|---|
| IngredientLot | MaterialFlow (raw/stored stage) | RocketFleetSystem → ReceivingDock → IngredientStorageUnit → PrepStation |
| PreppedBatch | MaterialFlow (prepped stage) | PrepStation → CookingUnit |
| SoupLot | SoupBatch | CookingUnit → QualityControlUnit → PackagingUnit |
| ContainerSet | PackagedGoods | PackagingUnit → ShippingBay |
| Manifest | ShipmentManifest | ShippingBay → RocketFleetSystem |
| StockReport | InventoryStatus | IngredientStorageUnit → InventoryManagementSystem |
| OrderMsg | OrderRequest | Root customer order intake and InventoryManagementSystem → root reorder output |
| CommandMsg | ControlDirective | ProductionControlSystem → all logical components (fan-out) |
| UnitStatus | OperationalStatus | All logical components → ProductionControlSystem (fan-in) |
| GravityState | EnvironmentState | Root ambient gravity input ↔ GravityCompensationSystem ↔ ProductionControlSystem |

**What typing adds.** The functional layer's `MaterialFlow` is a single abstract concept covering all material in transit; the logical layer replaces it with three distinct types — `IngredientLot`, `PreppedBatch`, `SoupLot` — that reflect the material's actual state transformation as it crosses ReceivingDock → IngredientStorageUnit → PrepStation → CookingUnit. This lets later physical-layer and simulation work distinguish, type-check, and (eventually) attribute (e.g., mass, temperature, batch ID) each stage's material distinctly, rather than treating a raw delivery and a cooked batch as interchangeable "material." The remaining functional interfaces (control, status, orders, environment) map one-to-one onto typed logical counterparts (`CommandMsg`, `UnitStatus`, `OrderMsg`, `GravityState`) since those concepts do not change shape across the chain — only their field-level structure becomes concrete at the logical layer.

The logical layer preserves the same topology established at the functional layer, including the coordination fan-out/fan-in star (ADR-003), the point-to-point primary material chain, the inventory reorder path exiting at the root boundary, and gravity compensation as an independent component reporting into production control (ADR-005). See [`07_decision_log.md`](07_decision_log.md) for full rationale.
