# 13 — Parameter-Uncertainty Monte Carlo

Branch exploration: giving the trade study's *performance* claims the same sensitivity treatment its *preference* claims already had. The weights-only Monte Carlo (ADR-013, [`05_trade_study_methodology.md`](05_trade_study_methodology.md)) answers "does the winner depend on whose opinion you ask?" — it re-scores fixed metrics under 5,000 random stakeholder weightings, running zero simulations. This study answers the question that sweep deliberately leaves open: "does the verdict depend on the parameters that are engineering estimates rather than measurements?" — by actually simulating the architecture models under parameter draws.

Artifacts: [`../analysis/sweeps/uncertaintySpec.m`](../analysis/sweeps/uncertaintySpec.m) (study definition), [`../analysis/sweeps/runUncertaintySims.m`](../analysis/sweeps/runUncertaintySims.m) (per-variant `parsim` batches), [`../analysis/sweeps/runUncertaintyStudy.m`](../analysis/sweeps/runUncertaintyStudy.m) (post-processing, figures), [`../tests/analysis/tUncertainty.m`](../tests/analysis/tUncertainty.m) (baselines + reproducibility contract). Decision: ADR-025 in [`07_decision_log.md`](07_decision_log.md).

## 1. What is uncertain

The behavioral docs ([`10_behavioral_trade_update.md`](10_behavioral_trade_update.md)) flag exactly which numbers are estimates: the QC reject fractions and calibration schedules. Those became the uncertain parameters — three per variant, overriding the `*_QCReject`, `*_QCCalibPeriod_s`, and `*_QCCalibTime_s` dictionary entries:

| Parameter | Distribution | Rationale |
|---|---|---|
| Reject fraction | Triangular, right-skewed (e.g. LeanBroth 1.5% / 3% / 7%) | Yield problems have a long bad tail; processes rarely reject *less* than designed |
| Calibration period | Uniform, ±25% of nominal | Schedule drift in both directions, no strong prior |
| Calibration duration | Triangular ×(0.7 / 1.0 / 2.5) of nominal | Maintenance runs over far more often than under |

Sampling is one 200-draw Latin hypercube (`lhsdesign`, seeded) shared by all three variants — common random numbers, so each draw is one "world" all variants experience together and cross-variant comparisons are variance-reduced.

## 2. How the study runs

`runUncertaintySims(variant)` builds 200 `Simulink.SimulationInput` objects, each overriding the three parameters *in the model workspace* — which shadows the attached data dictionary entry of the same name, so the dictionaries on disk are never touched (the same mechanism the fault injection uses for `Fault_T_*`). The batch runs through `parsim`; 600 simulations total, roughly 35 minutes on a 4-worker pool. Steady-state throughput and energy per bowl are harvested exactly as `runBehavioralAnalysis` does, and each variant's batch persists to `uncertaintySims_<Variant>.mat`.

`runUncertaintyStudy` then post-processes without any further simulation: compliance probability per variant, and a **double Monte Carlo** for the win share — per parameter draw, the compliance rule is applied with *that draw's* throughput (a variant below the floor is excluded from that draw's scoring, mirroring `runFullAnalysis`), the ThroughputMargin criterion is recomputed, the other six criteria keep their measured values, and 25 seeded Dirichlet weight draws score the compliant set. 200 × 25 = 5,000 scored worlds, uncertain in both parameters and priorities.

## 3. Results

| Variant | P(comply) | Median bph | P5–P95 | Win share (param + weights) | Win share (weights only) |
|---|---|---|---|---|---|
| HyperCook | 100% | 304.0 | 298.1–309.1 | 1.6% | 1.6% |
| LeanBroth | **4%** | 193.1 | 185.5–199.7 | 0.6% | excluded |
| EverSimmer | 100% | 228.6 | 222.6–233.2 | **97.8%** | 98.4% |

The headline: **LeanBroth's borderline compliance failure now has a probability instead of a point verdict.** The deterministic run said 196.8 bph against a floor of 200 (ADR-018); the study says that in 96% of parameter worlds it misses the floor, and even its 95th-percentile world (199.7 bph) falls just short. "LeanBroth fails SR-GS-002" upgrades from "at nominal parameter estimates" to "with 96% confidence over the stated parameter uncertainty" — a much stronger statement, and a fairer one, since it also quantifies the 4% of worlds where a better-than-feared QC bench would clear it.

Second finding: **the trade verdict is robust to both kinds of uncertainty.** EverSimmer wins 97.8% of scored worlds when parameters and priorities vary together, versus 98.4% under priority variation alone. HyperCook's and EverSimmer's compliance never wavers across any draw. Nobody's decision was hiding in the error bars.

## 4. Reproducibility contract

Three artifacts must stay in agreement: the spec (distributions + seeds), the saved simulation batches, and the published results. `tUncertainty` enforces all three legs: the spec regenerates its own draws bit-identically; the parameter values stored inside each simulation batch equal what today's spec generates (so editing `uncertaintySpec.m` without re-running the study fails the suite); and rerunning the seeded post-processing over the saved batches reproduces the published compliance probabilities and win shares exactly. The simulation study itself (35 minutes, 600 simulations) is deliberately outside the test suite and outside `runFullAnalysis` — it reruns only when the spec or the models change, and the spec-vs-batch test is what tells you that rerun is due.

## 5. Gotchas

- **Model-workspace overrides shadow dictionary entries.** `setVariable(in, name, value, 'Workspace', model)` wins over an attached `.sldd` entry of the same name — the clean per-run override for dictionary-parameterized models; nothing on disk changes.
- **Ragged cell literals fail at construction.** A parameter table as a cell literal needs every row the same width; rows with fewer entries need explicit padding.
- **`verifyTrue`/`assertTrue` take no sprintf varargs** — unlike `verifyEqual`'s diagnostic argument, the message must be pre-formatted with `sprintf`.
- **`parsim` pool startup dominates short batches.** ~2.5 minutes before the first simulation starts (pool + Simulink + project load per worker); batching per variant (200 runs) amortizes it, and simulation wall time per run roughly doubles with 4 workers saturating 4 cores relative to a lone serial run.
