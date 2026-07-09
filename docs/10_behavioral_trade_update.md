# 10 — Trade Study Update with Behavioral Fidelity

Behavioral models: [`09_behavioral_models.md`](09_behavioral_models.md). Source data: [`../behavior/`](../behavior/) (component library, tests) instantiated inline inside [`../architecture/`](../architecture/)'s three physical variant models, produced by `runBehavioralAnalysis.m`. Decisions: ADR-018 and ADR-020 in [`07_decision_log.md`](07_decision_log.md). Baseline static results this update supersedes: [`06_trade_study_results.md`](06_trade_study_results.md).

## 1. What changed

`runVariantAnalysis.m` now accepts simulated throughput and worst-case single-fault retention from `runBehavioralAnalysis.m` in place of the hand-authored static stage-table values, for those two metrics only — every other rolled-up quantity (mass, power, cost, volume, automation, operators, gravity rating) is unchanged, and the static values are retained alongside the new ones (`Static_Throughput_bph`, `Static_N1Retention`, etc.) for direct comparison rather than being overwritten.

`runBehavioralAnalysis.m` now simulates `PhysicalHyperCook`/`PhysicalLeanBroth`/`PhysicalEverSimmer` directly (ADR-020). The three former `BehPlant*` top models are retired: the behavioral component library is instantiated inline inside the architecture models themselves (see [`09_behavioral_models.md`](09_behavioral_models.md) §5), so simulation, behavioral analysis, and MCDA all run on the same System Composer models that carry the requirements allocation and the roll-up — there is no separate plant model to keep in sync.

The analysis chain is now:

```
runBehavioralAnalysis → runVariantAnalysis → runComplianceGate → runTradeStudy(compliantOnly)
```

Gate policy changed with this update (ADR-018): a variant that fails the formal compliance gate is now **excluded from MCDA scoring** rather than halting the chain for all variants. The previous behavior (ADR-011: the trade study refuses to run if *any* variant fails) is not appropriate once the gate can fail because of newly-modeled loss mechanisms rather than a genuine gate/procedural drift — see §3.

The numbers in this document come from the committed architecture models with inline behavior on every faultable, production, and controller component across all three variants ([`09_behavioral_models.md`](09_behavioral_models.md) §5). `createSubsystemBehavior` preserves each component's stereotype property values (`isReference` stays 0), so the roll-up-corruption caveat that previously confined the `linkToModel` adapter pattern to an on-demand build script for two kettles no longer applies — `BehKettleBehavior.slx` and `behavior/build/buildKettleAdapters.m` are retired, superseded by the inline pattern and its build script, `behavior/build/buildInlineBehaviors.m` (ADR-020).

## 2. Simulated vs. static metrics

These simulated metrics now come from the architecture models directly rather than the retired `BehPlant*` top models. The numbers are numerically almost unchanged from the prior plant-model baseline (throughput within 0.3 bph, energy per bowl within 0.002 kWh, EverSimmer's TTFO within 5 s) — evidence that the inline-integration migration (ADR-020) preserved behavior rather than altering it. HyperCook's TTFO is the one figure that moved meaningfully, from 149 s to 119 s: the architecture model's cold-start path to first packaged output is shorter than the retired plant model's, since the surge buffering ahead of packaging is sized slightly differently in the inline topology.

| Metric | HyperCook | LeanBroth | EverSimmer |
|---|---|---|---|
| Static throughput (bph) | 320 | 210 | 240 |
| Simulated steady throughput (bph) | 308.4 | 196.8 | 231.9 |
| Delta | −3.6% | −6.3% | −3.4% |
| Static N-1 retention | 0 | 0 | 0.667 |
| Simulated worst-fault retention | ~0 (`InlineQCScanner`) | ~0 (`PrepWorkstation`) | 0.672 (`ProductionCell1`) |
| Energy per bowl, kWh (new) | 1.554 | 0.814 | 1.212 |
| Time to first output, s | 119 | 3,444 | 3,439 |
| Mean power, kW | 479 | 160 | 281 |
| Peak power, kW | 479 | 239 | 363 |

Every variant loses throughput relative to its static stage-table value, because the static tables were lossless: a stage's rated bph flowed straight through to the next stage with no yield loss and no downtime. The behavioral QC station now removes a reject fraction (2% automatic inspection, 3% manual bench) and periodically drops offline for calibration, and both effects consume real throughput that the static roll-up never modeled. Batch plants (LeanBroth, EverSimmer) additionally show a roughly one-hour cold start — hopper fill followed by the first heat/simmer cycle — before steady output is reached, versus 119 s for HyperCook's continuous line; this cold start does not change *steady-state* throughput but is a first observation of a cost that the static analysis had no mechanism to represent at all.

N-1 retention is close to the static estimate for EverSimmer (0.672 simulated vs. 0.667 static — the triplicated-cell topology behaves close to its idealized third-of-capacity assumption) but the two single-string variants, which the static table already scored at 0% retention, remain at essentially zero under simulation: losing the single QC/packaging string (HyperCook) or the one prep line (LeanBroth) still collapses the whole plant, confirming rather than revising the static finding. HyperCook's worst-case fault point is `InlineQCScanner` rather than the conveyor: the architecture has no explicit conveyor material edge, so QC and packaging are HyperCook's single-string components.

A supervisory-telemetry limitation surfaces in this pass: `plantMode` (the new `TelemetryBus` field routed from each controller, [`09_behavioral_models.md`](09_behavioral_models.md) §5) stays `Nominal` even under the serial single-string faults that collapse HyperCook and LeanBroth to zero output, because each plant's `BehSupervisor` watches production-line health signals rather than output flow, and the health report path can stay intact even after the line's output has stopped. EverSimmer's supervisor does correctly report `Degraded` on the single-cell fault, since a whole-cell health signal is exactly what's lost there. This is a genuine gap in the current supervisor wiring, not a simulation artifact, and is carried forward as a follow-up in §6.

## 3. LeanBroth formally fails SR-GS-002

**LeanBroth's simulated steady throughput, 196.8 bph, is below the 200 bph SR-GS-002 floor.** The formal Requirements Table gate ([`08_formal_compliance_gate.md`](08_formal_compliance_gate.md)) flags exactly the Throughput row for LeanBroth and no other row, for any variant — 23 of 24 formal/procedural cross-checks pass, and the one disagreement is a genuine compliance failure rather than a formal/procedural drift (the procedural `OK_Throughput` flag agrees with the formal verdict; both say fail).

LeanBroth's static throughput margin was only +5% (210 vs. 200 bph — already the tightest margin of any variant on any gate, flagged as a caveat in [`06_trade_study_results.md`](06_trade_study_results.md) §7 item 3 for automation, and true of throughput too). That 5% margin is exactly the kind of headroom the QC reject fraction and calibration downtime were sized to consume: 3% manual-QC reject plus roughly 4.2% calibration downtime on LeanBroth's single QC bench account for essentially all of the shortfall.

Recovery options exist but are not implemented in this update: a higher-grade QC bench (reject fraction down to 1%, shorter recalibration interval) or an approximately 7% prep-stage rate upgrade would each restore compliance on their own. Until one is adopted, **LeanBroth loses its ADR-009 status as the documented CostLean descope option** — it cannot be carried forward as a fallback architecture while it fails a mandatory SR gate.

LeanBroth is excluded from MCDA scoring for the remainder of this document (§4) per ADR-018.

## 4. Updated trade results (HyperCook vs. EverSimmer)

With LeanBroth excluded, the trade study now scores two compliant variants.

| Scenario | EverSimmer | HyperCook | Winner |
|---|---|---|---|
| Balanced | 0.80 | 0.20 | EverSimmer |
| ThroughputFirst | 0.65 | 0.35 | EverSimmer |
| CostLean | 0.90 | 0.10 | EverSimmer |
| MissionAssurance | 0.90 | 0.10 | EverSimmer |

Monte Carlo weight sensitivity (5,000 Dirichlet draws, `rng(42)`, reproducible): **EverSimmer 98.4%, HyperCook 1.6%**.

EverSimmer now wins **all four** named scenarios, including CostLean — where LeanBroth won at baseline (§5 of [`06_trade_study_results.md`](06_trade_study_results.md)) and where EverSimmer placed second to LeanBroth by a wide margin. With only two variants left, min-max normalization is binary per criterion (whichever variant is better on a criterion scores 1, the other scores 0), so the scenario scores above compress to whichever side of 0.5 the scenario's weights fall on and carry less nuance than the three-variant baseline scores. The Monte Carlo win share and the "wins every scenario" pattern are the informative results here, not the individual score magnitudes.

## 5. Figures

![Simulated nominal throughput](figures/behavioral_throughput.png)
*Steady-state packaged output over time, all three variants — cold-start transients visible for LeanBroth and EverSimmer, near-immediate ramp for HyperCook.*

![Worst-case fault response](figures/behavioral_fault.png)
*Single-fault injection at t = 2 h. HyperCook and LeanBroth collapse to zero output (serial single-string topology, no redundancy to fall back on); EverSimmer steps down to roughly two-thirds output and the BehSupervisor chart transitions to Degraded rather than Halted.*

## 6. Recommendation

**ADR-009 (EverSimmer as baseline) is reinforced, not revised.** The resilience advantage that the static roll-up could only assert as a stereotype-derived percentage (66.7% N-1 retention) is now demonstrated dynamically: fault injection produces the graceful two-thirds step-down and Degraded-mode transition in §5, not merely an arithmetic capacity number. EverSimmer's energy per bowl (1.212 kWh) lands in the middle of the field, between LeanBroth's more efficient batch process (0.814 kWh) and HyperCook's continuous-line draw (1.554 kWh) — a new data point the static analysis had no mechanism to produce, since it never modeled actual power draw against actual throughput.

Cold start is a genuinely new operational consideration this update surfaces: EverSimmer and LeanBroth both take on the order of an hour to reach steady output from a cold hopper, while HyperCook is at steady output in 119 s. This favors HyperCook specifically for surge-restart scenarios (e.g., recovering from a planned full-plant shutdown under time pressure) even though it does not change the overall recommendation.

Follow-ups:

1. **LeanBroth QC redesign study** — evaluate the higher-grade QC bench and prep-upgrade options identified in §3 against their cost impact, since either restores SR-GS-002 compliance and would let LeanBroth be re-evaluated as a descope option.
2. **Backpressure modeling.** Hopper overflow at full buffers is currently discarded outright rather than backing pressure up the chain — mass is not strictly conserved at full buffers in the current models. This is a known gap, not a hidden one (see [`09_behavioral_models.md`](09_behavioral_models.md) §8's batch-drain-burst gotcha, which the surge-buffer fix only partially addresses).
3. **Behavioral gates as Requirements Table stimulus/response tests.** [`08_formal_compliance_gate.md`](08_formal_compliance_gate.md) §6 named preconditions/durations/temporal behavior as "the natural next exploration" once behavior models existed — they now do, and the fault-response trace in §5 above is a plausible first stimulus/response requirement to formalize (e.g., "Degraded mode entered within N seconds of single-cell fault").
4. **Fix `plantMode` fault visibility.** The §2 limitation — `plantMode` reporting `Nominal` under a serial single-string fault because the supervisor watches production-line health rather than output flow — means an operator watching telemetry alone would miss a HyperCook or LeanBroth collapse. Wiring the supervisor's mode logic off output flow (or a combination of flow and line health) would close this gap.

## 7. Threats to validity

The QC reject fractions (2% automatic, 3% manual) and calibration outage schedule are engineering estimates, not values derived from any system requirement — and they are the mechanism that drives the LeanBroth failure in §3. A sensitivity check shows LeanBroth returns to compliance at a manual-QC reject fraction of roughly 1.3% or below, all else equal — the failure is real at the assumed reject rate but is not far from the boundary, and a different (equally defensible) estimate of QC yield could move the compliance verdict. The stereotype rates (Throughput_bph, Power_kW, etc., carried over from the physical layer's `PhysicalProperties` stereotype) anchor every other behavioral parameter and are themselves point estimates, not measured hardware data.

The continuous-flow abstraction (ADR-014) hides discrete-batch queueing effects that a SimEvents-based model would expose — real batch arrivals at a shared downstream resource can queue or block in ways a continuous rate signal cannot represent. Combined with the backpressure gap noted in §6, the models currently understate congestion effects at buffer boundaries; results here should be read as directionally reliable (which variant does better, and by roughly how much) rather than as precise absolute predictions.
