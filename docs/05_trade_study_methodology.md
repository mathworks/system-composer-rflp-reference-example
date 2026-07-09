# 05 — Trade Study Methodology

Analysis scripts: [`../analysis/pipeline/runVariantAnalysis.m`](../analysis/pipeline/runVariantAnalysis.m) (roll-up and SR-gate compliance), [`../analysis/pipeline/runTradeStudy.m`](../analysis/pipeline/runTradeStudy.m) (MCDA scoring and Monte Carlo sensitivity), plus helpers [`gsRollup.m`](../analysis/utils/gsRollup.m), [`gsCollectLeaves.m`](../analysis/utils/gsCollectLeaves.m), [`gsParseBudgetValue.m`](../analysis/utils/gsParseBudgetValue.m). Outputs: [`../analysis/results/variantMetrics.csv`](../analysis/results/variantMetrics.csv), [`../analysis/results/tradeScores.csv`](../analysis/results/tradeScores.csv), [`../analysis/results/mcWinShare.csv`](../analysis/results/mcWinShare.csv), and the figures in [`figures/`](figures/). Results are presented in [`06_trade_study_results.md`](06_trade_study_results.md).

This document describes *how* the numbers in `06` were produced, so the roll-up and MCDA method can be audited, reproduced, and re-run if a variant model or requirement changes.

## 1. Roll-up model

Each physical variant (`PhysicalHyperCook.slx`, `PhysicalLeanBroth.slx`, `PhysicalEverSimmer.slx`) is instantiated against the `GalacticSoupProfile` profile and walked with `iterate(instance, 'PostOrder', @gsRollup)` (see [`04_physical_variants.md`](04_physical_variants.md) for the stereotype and ADR-007 for why one stereotype covers every component).

**Additive properties (PostOrder roll-up).** `Mass_kg`, `Power_kW`, `Cost_kCredits`, `Volume_m3`, and `OperatorsRequired` are summed bottom-up: `gsRollup` visits children before parents and, at every composite, sets the parent's value to the sum of its children's values for each of these five properties. Because the walk is post-order, this composes correctly through arbitrary nesting depth — it is why EverSimmer's three `ProductionCell` composites (each itself a sum of 5 leaf units) roll up correctly into the top-level totals alongside the 10 non-cell top-level components, without any cell-specific logic in the roll-up function itself.

**Leaf-mean properties.** `AutomationAvg` is the arithmetic mean of `AutomationLevel` over every leaf component (`gsCollectLeaves`), not a roll-up sum — automation is an intensity, not a quantity, so summing it across components would not be meaningful. `GravityMin` is the minimum `GravityRating_g` over the same leaf set, since the weakest-rated component sets the system's actual gravity ceiling.

**Throughput (stage-chain model).** Total system throughput is not a stereotype roll-up at all; it is computed from a hand-authored *stage table* per variant (defined in `runVariantAnalysis.m`) that lists, for each processing/handling stage, which components belong to it and whether the stage is parallel or serial:

- **Parallel stage** (e.g., HyperCook's 4 cook lines, LeanBroth's 2 kettles): stage capacity = **sum** of member throughputs — losing none of the units, they add.
- **Serial stage** (e.g., a single receiving dock): stage capacity = capacity of that one member.
- **Composite member (EverSimmer's `ProductionCell`s):** a cell contains its own internal prep→cook→QC→pack chain. The cell's capacity is the **interior chain minimum** — the min throughput over the cell's own production-path leaves (flagged via `IsProductionPath`) — computed recursively with `gsCollectLeaves`, then that single number is used as the cell's capacity when the outer `cells` stage (itself parallel across the 3 cells) sums or mins as appropriate.
- **Overall system throughput** = **minimum across all stages** in the chain (the classic bottleneck rule: a serial pipeline runs no faster than its slowest stage), i.e. `r.Throughput_bph = min(stageCap)`.

This stage-table approach is necessary because System Composer's stereotype properties have no built-in notion of "this component is redundant with that one" or "these five components form a serial sub-chain" — that topology knowledge is only available by hand-encoding which components are parallel/serial per variant (see §4, threat to validity).

**Availability.** Each leaf unit's availability is `MTBF / (MTBF + MTTR)` with a fixed `MTTR = 24 h` for every component in every variant (steady-state availability under an exponential-repair approximation). Stage availability composes the same way capacity does: **parallel stage** availability = `1 - ∏(1 - a_i)` (the stage is down only if *every* redundant unit is down); **serial stage** (including a composite cell's internal chain) availability = `∏ a_i` (the stage is down if *any* one member is down). System availability is the product of all stage availabilities together with the non-processing support components (control, power, gravity compensation), since a support-component outage is modeled as taking down the whole system.

**N-1 retention.** For each *processing* stage (prep, cook, QC, pack, or an EverSimmer cell — stages flagged `isProcessing` in the stage table), compute the capacity lost by removing the single largest-capacity member of that stage (`stageCap(s) - max(unitCaps{s})`), divide by total system throughput, and take the **worst (minimum)** such ratio across all processing stages. This is the fraction of nominal throughput the system retains after the single worst-case unit loss — 0% means some processing stage is single-string (any unit loss there stops that stage, and since throughput is a chain minimum, it stops the system); EverSimmer's 66.7% reflects that losing one of its three parallel, independent production cells leaves two-thirds capacity.

## 2. Budget caps and compliance gates

The eight SR compliance gates are evaluated against caps **parsed at analysis time from the requirement text** in `requirements/SystemRequirements.slreqx`, via `gsParseBudgetValue` (extracts the first numeric token from a requirement's `Description`). This keeps the analysis cap values mechanically in sync with the requirements set — if an SR's numeric limit is edited in the `.slreqx`, the next analysis run picks up the new cap automatically rather than relying on a hand-copied constant that can drift out of sync.

| Cap | Source SR | Parsed value | Units in analysis |
|---|---|---|---|
| Mass | SR-GS-011 | 15,000 | kg |
| Power | SR-GS-012 | 500 | kW |
| Cost | SR-GS-013 | 2,000,000 credits → 2,000 | kCr (divided by 1000 after parsing) |
| Volume | SR-GS-014 | 400 | m³ |
| Throughput | SR-GS-002 | 200 | bowls/hr (floor, not ceiling) |
| Automation | SR-GS-003 | 0.8 | fraction (floor; hard-coded, not text-parsed, since the requirement text does not carry a bare numeric token in the same form) |
| Operators | SR-GS-004 | 5 | count (ceiling) |
| Gravity | SR-GS-015 / SR-GS-016 | 12 | g (floor rating a variant's weakest component must meet) |

A variant is **compliant** only if all eight gates pass simultaneously (`r.Compliant` is the logical AND of all eight `OK_*` flags). Margins are reported as the fraction of headroom remaining against each cap (e.g., `Margin_Mass = 1 - Mass_kg/caps.Mass_kg`), so 0% margin means running exactly at the cap and negative margin (not observed for any variant here) would mean non-compliance.

## 3. MCDA method

**Criteria (seven, all benefit-form — higher is always better).**

| Criterion | Definition |
|---|---|
| ThroughputMargin | `Throughput_bph / cap - 1` (fractional headroom above the 200 bph floor) |
| ResourceMargin | Mean of `Margin_Mass`, `Margin_Power`, `Margin_Volume` (cost margin is scored separately, so it is excluded here to avoid double-weighting cost) |
| CostMargin | `Margin_Cost` |
| Automation | `AutomationAvg` (leaf mean, §1) |
| CrewMargin | `(cap_Operators - OperatorsRequired) / cap_Operators` (fractional headroom below the 5-operator ceiling) |
| Availability | System availability (§1) |
| N1Retention | N-1 capacity retention (§1) |

**Normalization.** Each criterion is **min-max normalized across the three variants**: for criterion *j*, `norm(v,j) = (raw(v,j) - min_v raw(v,j)) / (max_v raw(v,j) - min_v raw(v,j))`, so the best variant on any single criterion always scores 1.0 and the worst always scores 0.0 on that criterion, regardless of the absolute magnitude of the gap between them. If all three variants tie on a criterion (zero range), that criterion is scored 0.5 for everyone as a neutral guard against division by zero (not triggered by the current data set).

**Weighting scenarios.** Four weight vectors over the same seven criteria (in the order above), each summing to 1, represent different stakeholder priorities:

| Scenario | ThroughputMargin | ResourceMargin | CostMargin | Automation | CrewMargin | Availability | N1Retention |
|---|---|---|---|---|---|---|---|
| Balanced | 0.20 | 0.10 | 0.15 | 0.10 | 0.10 | 0.15 | 0.20 |
| ThroughputFirst | 0.35 | 0.05 | 0.15 | 0.10 | 0.05 | 0.15 | 0.15 |
| CostLean | 0.10 | 0.20 | 0.35 | 0.05 | 0.10 | 0.10 | 0.10 |
| MissionAssurance | 0.10 | 0.05 | 0.10 | 0.10 | 0.10 | 0.25 | 0.30 |

Each variant's scenario score is the weighted sum `score(v) = Σ_j norm(v,j) * w(j)`.

**Monte Carlo weight sensitivity.** To check whether the ranking is an artifact of the four hand-picked scenarios above, 5,000 random weight vectors are drawn from a symmetric Dirichlet distribution over the seven criteria (implemented as normalized i.i.d. `Exponential(1)` draws, `w = -log(rand(1,7))` renormalized to sum to 1 — a standard equivalence for uniform sampling over the simplex), using `rng(42)` for reproducibility. Each of the 5,000 weight vectors is applied to the same normalized criteria matrix, the winning variant (highest weighted score) is recorded, and the **win share** is the fraction of the 5,000 draws each variant wins. A robust winner should win a large majority of draws across the whole space of plausible stakeholder priorities, not just the four named scenarios.

## 4. Threats to validity

- **Point estimates, not distributions.** Every stereotype property (mass, power, cost, MTBF, etc.) is a single deterministic value per component. The roll-up and MCDA method carries no uncertainty bands — a component whose true mass could plausibly vary ±10% is treated as exact, so reported margins (e.g., EverSimmer's 4.7% cost margin) should be read as point estimates under current design assumptions, not statistically bounded results.
- **Min-max normalization is sensitive to the 3-variant set.** Because normalization is relative to the min and max *within this comparison* rather than to an absolute scale, every score in `06` is only meaningful as a comparison among HyperCook, LeanBroth, and EverSimmer. Adding, removing, or re-scoping a fourth variant would shift every other variant's normalized scores (and possibly the ranking) even if their raw metrics did not change.
- **Availability model simplifications.** The `MTTR = 24 h` constant is applied uniformly to every component regardless of type, complexity, or crew repair capacity, and treats failures as independent (no shared-cause or cascading failure modes, no spares logistics, no repair queue contention when multiple units fail concurrently). The parallel-stage availability formula `1 - ∏(1-a_i)` also assumes any one surviving unit can fully cover the stage's demand, which is optimistic relative to the N-1 *throughput* retention numbers reported separately (a stage can be "available" at reduced capacity).
- **Stage tables encode topology by hand.** The parallel/serial structure used for the throughput and availability chain (§1) is authored manually per variant in `runVariantAnalysis.m`, not derived automatically from the System Composer model's connectivity. If a variant model's topology changes (a component renamed, a stage re-parallelized, a new production cell added), the corresponding stage table must be updated by hand or the analysis will silently compute against stale topology — this is the main manual-maintenance risk in the whole pipeline.
