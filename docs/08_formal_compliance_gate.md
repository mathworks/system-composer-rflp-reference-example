# 08 — Formal Compliance Gate with Requirements Table

Branch exploration: replacing hand-coded compliance checks with an executable, requirement-linked formal gate built on the [Requirements Table block](https://www.mathworks.com/help/slrequirements/ref/requirementstable.html) (Requirements Toolbox).

Artifacts: [`../architecture/gate/GalacticSoupComplianceGate.slx`](../architecture/gate/GalacticSoupComplianceGate.slx) (generated model), [`../analysis/pipeline/buildComplianceGate.m`](../analysis/pipeline/buildComplianceGate.m) (generator), [`../analysis/pipeline/runComplianceGate.m`](../analysis/pipeline/runComplianceGate.m) (verification harness), [`../analysis/pipeline/runFullAnalysis.m`](../analysis/pipeline/runFullAnalysis.m) (orchestrator), [`../analysis/results/complianceGate.csv`](../analysis/results/complianceGate.csv) (results). Decisions: ADR-010 and ADR-011 in [`07_decision_log.md`](07_decision_log.md).

## 1. Why a Requirements Table here

The baseline analysis ([`05_trade_study_methodology.md`](05_trade_study_methodology.md) §2) evaluates the eight SR compliance gates as procedural MATLAB comparisons inside `runVariantAnalysis.m` (`r.OK_Mass = r.Mass_kg <= caps.Mass_kg`, etc.). That works, but the checks live only in analysis code: they are not model artifacts, they are not linked to the requirements they implement, and nothing in the Requirements Toolbox ecosystem knows they exist.

The Requirements Table block inverts this. Each gate becomes a *formal requirement row* with a machine-checkable postcondition (`mass_kg <= MASS_CAP`). The rows are real Requirements Toolbox requirement objects stored in the model, so they participate in traceability (each row carries a Refine link back to its source SR in `SystemRequirements.slreqx`), and checking them is a *simulation* rather than a script convention. The variants' rolled-up metrics are fed in as inputs, and each row independently reports satisfied/violated.

Of the use patterns we considered for this feature against the variant architectures (formalizing behavioral requirements per variant model, stimulus/response verification of future behavior models, or formalizing the system-level quantitative gates), the quantitative gate is the one that pays off *now*: it operates on data the roll-up analysis already produces, it covers all three variants with a single table, and it turns the eight most load-bearing SRs in the project into executable artifacts. Behavioral requirement rows (preconditions over time, durations) become valuable once the architecture components get Simulink behavior models, which is future work.

## 2. Gate model design

`GalacticSoupComplianceGate.slx` contains one Requirements Table block with:

| Element | Content |
|---|---|
| 8 input symbols | `mass_kg`, `power_kW`, `cost_kCr`, `volume_m3`, `throughput_bph`, `automationAvg`, `operators`, `gravityMin_g` — each marked **`IsDesignOutput = true`** |
| 8 parameter symbols | `MASS_CAP`, `POWER_CAP`, `COST_CAP`, `VOL_CAP`, `THR_FLOOR`, `AUTO_FLOOR`, `OPS_CAP`, `GRAV_FLOOR` — values held in the **model workspace** |
| 8 requirement rows | one per gate, postcondition only (no preconditions: the gates apply unconditionally), e.g. `SR-GS-012: Total power within budget` with postcondition `power_kW <= POWER_CAP` |
| 8 Constant blocks | one per input; the harness overrides their `Value` per variant via `Simulink.SimulationInput.setBlockParameter` |

The whole model is **generated** by `buildComplianceGate.m`, never hand-edited. The generator parses the cap values out of the requirement text in `SystemRequirements.slreqx` at build time (same `gsParseBudgetValue` mechanism the roll-up analysis uses), so the single-source-of-truth property established in the baseline is preserved: a requirement cap change is picked up by rebuilding the gate, and the postconditions stay symbolic against named parameters rather than embedding magic numbers.

## 3. Execution and status harvesting

`runComplianceGate.m` loads `variantMetrics.mat`, and for each variant sets the eight constants and simulates the gate model. Each requirement row logs a status signal to the Simulation Data Inspector named `R:<rowId>`; the data is **0 while the row is satisfied and 1 while violated**. The harness collects the signals, maps them to gates by sorting the numeric row ids (creation order), and reduces each to a pass flag with `any()` over time.

Two hard assertions protect the chain:

1. The number of logged status signals must equal the number of gates (catches a drifted gate model).
2. Every formal verdict must equal the corresponding procedural `OK_*` flag from `runVariantAnalysis` (the two independently implemented compliance paths cross-check each other; a mismatch is an error, not a warning).

`runFullAnalysis.m` sequences the whole chain: roll-up, then formal gate, then MCDA. The trade study only runs if every variant passes the formal gate, which encodes the methodological position that a non-compliant variant has no business being scored.

## 4. Results

All 24 variant-gate checks pass and agree with the baseline procedural flags ([`complianceGate.csv`](../analysis/results/complianceGate.csv)):

| Variant | Mass | Power | Cost | Volume | Throughput | Automation | Operators | Gravity |
|---|---|---|---|---|---|---|---|---|
| HyperCook | pass | pass | pass | pass | pass | pass | pass | pass |
| LeanBroth | pass | pass | pass | pass | pass | pass | pass | pass |
| EverSimmer | pass | pass | pass | pass | pass | pass | pass | pass |

A deliberate negative test (HyperCook metrics with power inflated to 600 kW against the 500 kW cap) flagged exactly the Power row and no others, confirming the gate detects violations and localizes them to the right requirement.

The trade study rerun downstream of the gate reproduces the baseline results exactly (deterministic with `rng(42)`): EverSimmer wins Balanced/ThroughputFirst/MissionAssurance and 84.0% of the Monte Carlo weight draws. This is the expected outcome: the gate changes *how compliance is established*, not the metric values or scoring.

## 5. Implementation notes and API gotchas (R2026a)

Discovered empirically while building the generator; recorded here because most are not obvious from the documentation:

- **Postconditions must reference a design output.** A table whose postcondition uses only plain inputs fails at initialization with the unhelpful top-level error `Table contains one or more semantic issues`. The fix is `symbol.IsDesignOutput = true` on the checked inputs, which is exactly the right semantic for this use case anyway (the metrics *are* outputs of the design under verification).
- **Surfacing the real diagnostic requires a diary.** The semantic error's cause chain is opaque; `sldiagviewer.diary(file)` around `set_param(mdl,'SimulationCommand','update')` captures the actual row-level message (`Requirement postcondition must contain a design model output`).
- **Parameter symbols cannot take `InitialValue`.** They resolve by name from a workspace. Using the *model workspace* (`get_param(mdl,'ModelWorkspace')` + `assignin`) keeps the cap values inside the .slx with no base-workspace state.
- **The default table ships with a placeholder row** (empty pre and postconditions) that is itself a semantic error once you try to simulate; remove it before adding real rows.
- **Rate inheritance:** with only Constant blocks driving the table there is no discrete rate to inherit; set the underlying Stateflow chart (`find(sfroot,'-isa','Stateflow.Chart','Path',<blockpath>)`) to `ChartUpdate='DISCRETE'` with an explicit sample time.
- **Status signal names use persistent row ids, not display indices.** After deleting the placeholder row, eight rows log `R:2` through `R:9`. Map signals to rows by sorted numeric id, never by assuming `R:1..R:N`.
- **Rebuilds leave zombie Refine links.** Table rows are requirement objects stored in the model; regenerating the model kills the rows but the links to the SRs survive as stale inLinks on the requirement side. The generator purges existing Refine inLinks on each gate SR before re-linking (and deletes the stale `~mdl.slmx` before rebuild).
- **`slreq.clear` refuses while the gate model is open**, because the table's internal requirement set belongs to the model. Close the model first in any script that manages requirement state.

## 6. Assessment

Worth keeping. The gate adds a formal, traceable, executable expression of the eight quantitative SRs at the cost of one generated model and ~150 lines of generator/harness code, and the procedural/formal cross-check caught the kind of drift that silent hand-coded checks invite. The main limitation is that this pattern covers *static* gate checking of rolled-up metrics; the block's richer semantics (preconditions, durations, temporal behavior) remain unexercised until behavior models exist for the architecture components. That is the natural next exploration on this branch's theme.
