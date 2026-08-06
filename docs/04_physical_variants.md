# 04 — Physical Architecture Variants

Models (in progress): `../architecture/physical/HyperCook/PhysicalHyperCook.slx`, `../architecture/physical/LeanBroth/PhysicalLeanBroth.slx`, `../architecture/physical/EverSimmer/PhysicalEverSimmer.slx`

The physical layer realizes each logical component (see [`03_logical_architecture.md`](03_logical_architecture.md)) as concrete hardware. Rather than model the physical layer as a single System Composer model with variant components, the project uses **three independent physical models**, one per architecture concept, so each can be rolled up and allocated independently before comparison (see [`07_decision_log.md`](07_decision_log.md) ADR-001). All physical components carry quantitative properties via the `PhysicalProperties` stereotype (`Mass_kg`, `Power_kW`, `Cost_kCredits`, `Volume_m3`, `Throughput_bph`, `AutomationLevel`, `OperatorsRequired`, `MTBF_hr`, `GravityRating_g`, `UseParallelThroughput`) defined in the `GalacticSoupProfile` profile, enabling a uniform roll-up analysis across variants (ADR-007).

**Quantitative values (mass, power, cost, volume, throughput, MTBF, automation level, etc.) are not repeated in this document — see the rolled-up metrics table in [`06_trade_study_results.md`](06_trade_study_results.md) §1.** This document describes each variant's design philosophy and component concept only.

## 1. Variant A — "HyperCook" (throughput/logistics-optimized)

**Philosophy.** Maximize production rate and rocket turnaround above all else. Accepts tight margins against the mass/power/cost/volume budgets (SR-GS-011..014) and single-string (non-redundant) infrastructure, i.e., moderate fault tolerance, in exchange for maximum throughput and fleet utilization.

**Component concept list.**

| Logical component | HyperCook physical concept |
|---|---|
| PrepStation | 2 robotic prep lines |
| CookingUnit | 4 parallel continuous cook lines |
| MaterialTransportSystem | High-speed conveyor network |
| ReceivingDock / ShippingBay / RocketFleetSystem | 4-pad launch complex with automated cargo gantries |
| IngredientStorageUnit | High-throughput storage sized to continuously feed 4 parallel cook lines |
| QualityControlUnit | Inline automated QC integrated with the conveyor network |
| PackagingUnit | High-speed automated packaging line |
| InventoryManagementSystem | Centralized inventory system tracking a single high-volume flow |
| ProductionControlSystem | Single centralized production controller sequencing all 4 cook lines and the gantry complex |
| GravityCompensationSystem | Structural/mount-integrated compensation sized for continuous high-throughput operation |
| *(physical-only, no functional counterpart)* | Fusion power plant |

**Expected strengths.** Highest raw throughput and fleet turnaround performance; parallel cook/prep lines and automated gantries directly target the throughput, cooking-capacity, and rocket-turnaround requirements; automated gantry loading supports fast, low-labor load-out.

**Expected weaknesses.** Single-string cook lines, conveyors, and gantries mean a single-component fault can remove a full production or handling line rather than degrading gracefully; tight budget margins leave little headroom if any subsystem overruns mass/power/cost/volume; fusion plant is a concentrated power dependency.

**SRs this variant stresses.** SR-GS-002 (throughput), SR-GS-022 (cooking capacity), SR-GS-028 (prep throughput), SR-GS-017/SR-GS-018 (concurrent rocket handling and 20-minute turnaround), SR-GS-006 (10-minute load-out), SR-GS-023/SR-GS-024 (internal transfer rate and automation). It is expected to be weakest against SR-GS-011..014 (resource budgets) and SR-GS-026 (single-fault production continuity).

## 2. Variant B — "LeanBroth" (resource-budget-optimized)

**Philosophy.** Maximize margin against the mass, power, cost, and volume budgets (SR-GS-011..014). Meets — but does not exceed — throughput requirements, relies more on human-in-the-loop operation (up to the full 5-operator allowance), and targets the lowest overall cost of the three variants.

**Component concept list.**

| Logical component | LeanBroth physical concept |
|---|---|
| CookingUnit | 2 efficient batch kettles |
| PrepStation | Single semi-automated prep station |
| MaterialTransportSystem | Shared AGV (automated guided vehicle) cart transport |
| ReceivingDock / ShippingBay / RocketFleetSystem | 3 shared-crane landing pads |
| IngredientStorageUnit | Compact, right-sized cold/ambient storage matched to 72-hour buffer with no excess margin |
| QualityControlUnit | Manual/semi-automated QC station supplementing operator inspection |
| PackagingUnit | Single-line packaging station |
| InventoryManagementSystem | Lightweight inventory system sized to a single moderate-volume flow |
| ProductionControlSystem | Single production controller coordinating the smaller equipment set with operator-assisted oversight |
| GravityCompensationSystem | Minimal compensation hardware sized to the operating envelope, not over-built for margin |
| *(physical-only, no functional counterpart)* | Compact fission reactor |

**Expected strengths.** Best expected margins on mass, power, cost, and volume budgets; lowest capital cost; shared/reused equipment (shared cranes, shared AGV fleet) reduces component count and cost.

**Expected weaknesses.** Throughput and turnaround headroom is minimal — batch kettles and a single prep station leave little slack if demand spikes; higher operator involvement (up to 5 concurrent operators) reduces automation margin against SR-GS-003; shared cranes and single-string kettles/prep give it similar (or weaker) fault-tolerance exposure to HyperCook despite the smaller footprint.

**SRs this variant stresses.** SR-GS-011, SR-GS-012, SR-GS-013, SR-GS-014 (mass/power/cost/volume budgets) most favorably. It is expected to be weakest, or run closest to the limit, against SR-GS-002/SR-GS-022 (throughput/cooking capacity, "meet not exceed"), SR-GS-003 (automation level, given heavier reliance on the 5-operator crew), SR-GS-018 (rocket turnaround, given shared rather than dedicated cranes), and SR-GS-026 (fault tolerance, given single-string kettles and prep).

## 3. Variant C — "EverSimmer" (resilience/autonomy-optimized)

**Philosophy.** Eliminate single points of failure. The plant is organized as three fully independent production cells, each with its own prep, cooking, QC, and packaging equipment, so the loss of any one cell degrades gracefully to two-thirds capacity rather than halting production. Targets the highest automation level of the three variants and the smallest operator headcount, accepting higher mass and cost as the price of resilience and autonomy.

**Component concept list.**

| Logical component | EverSimmer physical concept |
|---|---|
| PrepStation, CookingUnit, QualityControlUnit, PackagingUnit | Triplicated: one full prep→cook→QC→package chain per production cell (×3 independent cells) |
| ReceivingDock / ShippingBay / RocketFleetSystem | 3 independent pads, one dedicated per production cell |
| MaterialTransportSystem | Autonomous robotic transport, cell-local with cross-cell contingency routing |
| IngredientStorageUnit | Storage segmented/redundant across cells to preserve independence if one cell is isolated |
| InventoryManagementSystem | Distributed inventory tracking reconciled across the three cells |
| ProductionControlSystem | Distributed control triad — one controller per cell plus cross-cell coordination, so no single controller loss halts the plant |
| GravityCompensationSystem | Redundant compensation hardware, provisioned per cell |
| *(physical-only, no functional counterpart)* | Redundant power: 2 reactors |

**Expected strengths.** Best expected fault tolerance and graceful degradation — any single cell, pad, controller, or reactor loss retains roughly two-thirds capacity rather than a full production halt; highest automation level and lowest operator headcount (2) among the three variants; independent pads naturally satisfy concurrent rocket handling.

**Expected weaknesses.** Triplicating prep/cook/QC/packaging and providing dual power and distributed control is expected to be the heaviest and most expensive variant, putting the most pressure on the mass, cost, and volume budgets (SR-GS-011, SR-GS-013, SR-GS-014); per-cell capacity is necessarily smaller than a single centralized line, so aggregate throughput margin above the 200 bowls/hour floor may be tighter than HyperCook's.

**SRs this variant stresses.** SR-GS-026 (no single-fault production kill) most directly — this is the requirement the entire concept is organized around. Also strongly stresses SR-GS-003/SR-GS-024 (automation level) and SR-GS-004 (operator count, lowest of the three variants), and SR-GS-017 (3 concurrent rockets, satisfied structurally by 3 independent pads). It is expected to be weakest against SR-GS-011..014 (resource budgets), given triplicated equipment and redundant power.

## 4. Cross-variant comparison summary

| Dimension | HyperCook | LeanBroth | EverSimmer |
|---|---|---|---|
| Primary optimization axis | Throughput / logistics | Resource budgets | Resilience / autonomy |
| Production topology | 4 parallel centralized lines | 2 centralized batch kettles | 3 independent cells |
| Automation posture | High, centralized | Moderate, human-in-the-loop | Highest, distributed |
| Operators (expected) | Low-to-moderate | Up to 5 | 2 |
| Fault tolerance posture | Single-string (moderate) | Single-string (moderate) | No single point of failure |
| Power source | Fusion power plant | Compact fission reactor | 2 reactors (redundant) |
| Launch/dock complex | 4-pad, automated gantries | 3 shared-crane pads | 3 independent pads |
| Budget margin expectation | Tight | Best | Tightest |

## 5. How the models are organised

Each physical model groups its components into **bays** — one layer of hierarchy between the model root and the equipment — so that the root diagram reads the way the schematics above do: material flows left to right along one row, with shared services and the plant controller in a band below it (ADR-036).

| Bay | HyperCook | LeanBroth | EverSimmer |
|---|---|---|---|
| `IntakeAndStorage` | dock, cold + ambient stores, inventory | receiving bay, cold + dry stores, inventory | dock, dual-zone store, inventory |
| production | `PrepBay` (2 prep lines), `CookBay` (4 cook lines) | `ProductionLine` (prep, 2 kettles, QC, packaging) | `ProductionCell1..3` (unchanged — the cells predate the bay layer) |
| `FinishingLine` | inline QC, packaging | *(inside `ProductionLine`)* | *(inside each cell)* |
| `LaunchLogistics` | gantry, 4-pad complex, refuelling | shared crane dock, 3-pad field, refuel skid | cargo loader, triple pad, refuel cell |
| `PlantServices` | fusion plant, gravity compensation, conveyors | fission reactor, gravity compensation, AGV pool | reactor pair, gravity mesh, transport swarm |
| controller (at root) | `CentralControlComputer` | `OpsConsole` | `ControlTriad` |

Bay membership is a **readability grouping, not a design change**: it moved no component, added none, and left every stereotype value, requirement link, and allocation intact, so the rolled-up metrics are unchanged. The bays carry the `PhysicalProperties` stereotype only so the roll-up can sum through them. The plant controller stays at the model root because every bay talks to it; nesting it would hide the control topology rather than clarify it.

Both steps are re-runnable: [`architecture/build/regroupPhysicalBays.m`](../architecture/build/regroupPhysicalBays.m) for the grouping and [`architecture/build/layoutPhysicalBays.m`](../architecture/build/layoutPhysicalBays.m) for the layout. **Re-running `arrangeSystem` on these models discards the process-order placement** — `layoutPhysicalBays` has to be re-run to restore it.

One thing the bays do **not** fix: each plant controller still carries one status input port per unit (19 / 16 / 13), and those lines still dominate the lower half of each root diagram. Collapsing them needs a per-bay status aggregator — a real component with mass, power, and cost, which is exactly what EverSimmer's `CellController` is — so it would move the metrics and re-open the trade study. See ADR-036 for that decision and for the remaining duplicate `directive` boundary ports.

## 6. Trade study

The MCDA trade study across these three variants, using the roll-up analysis of stereotype properties, is documented in [`06_trade_study_results.md`](06_trade_study_results.md) (methodology in [`05_trade_study_methodology.md`](05_trade_study_methodology.md)); see also the project [`README.md`](../README.md) trade study summary.
