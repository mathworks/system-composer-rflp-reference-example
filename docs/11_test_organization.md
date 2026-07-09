# 11 — Test Organization for Analysis Verification

Branch exploration: reorganizing analysis verification as a tagged MATLAB Test suite. Every quantitative claim the analysis chain makes — golden roll-up totals, gate verdicts, MCDA determinism, traceability integrity, simulated system behavior — now has a test that baselines it independently of the code that produces it, rather than an assertion buried inside a script that only fails if someone happens to run that script and read its output.

Artifacts: [`../tests/`](../tests/) (six test classes, `runAllTests.m`), [`../behavior/tests/`](../behavior/tests/) (the pre-existing 21 component unit tests, unchanged, folded into the same suite). Decision: ADR-021 in [`07_decision_log.md`](07_decision_log.md).

## 1. Why organize analysis as tests

Before this branch, the analysis chain's correctness lived in two places: procedural `OK_*` flags and hard `assert`s scattered through `runVariantAnalysis.m`, `runComplianceGate.m`, and the trade-study scripts ([`05_trade_study_methodology.md`](05_trade_study_methodology.md), [`08_formal_compliance_gate.md`](08_formal_compliance_gate.md)), plus whatever a developer happened to eyeball in the command window after a run. That is fine for catching gross breakage — the gate harness already hard-errors on formal/procedural disagreement (ADR-011) — but it has no mechanism for catching *quiet* drift: a golden total that shifts by a few percent and still "looks compliant," a gate verdict pattern that changes shape without anyone noticing, an MCDA win share that moves half a point. Nothing was baselined against a value someone had actually decided was correct.

The fix is to say the expectations out loud, as tests, separately from the code that computes them. A `matlab.unittest` test class does not care how `runVariantAnalysis` gets to 7,570 kg for LeanBroth's mass — it just checks that it does, and fails loudly the moment it doesn't. This is the same discipline the behavioral component library already applied to unit-level correctness ([`09_behavioral_models.md`](09_behavioral_models.md) §7); this branch extends it up to the analysis and system level: roll-up invariants, gate agreement, trade determinism, traceability integrity, and full system simulation.

## 2. The four tiers

`GalacticSoup/tests/` holds four new tiers, distinguished by `matlab.unittest.TestTags`, on top of the pre-existing component tier in `behavior/tests/` (untagged — legacy, selected by folder membership rather than a tag, and left as-is: all 21 methods still pass unchanged).

| Tier | Tag | Classes | What breaks it |
|---|---|---|---|
| Component | *(untagged)* | 7 classes in `behavior/tests/` (`tBehStorage` … `tBehSupervisor`), 21 test methods | Any regression in a behavioral component's simulated response — unchanged from [`09_behavioral_models.md`](09_behavioral_models.md) §7. |
| Analysis | `'analysis'` | `tRollupInvariants`, `tGateAgreement`, `tTradeDeterminism` | Golden roll-up totals (mass/power/cost/volume) drifting per variant; budget caps parsed from requirement text changing; the `Compliant` flag disagreeing with its own eight gate flags; the formal gate's 23/24 verdict pattern moving off "LeanBroth throughput fails, and nothing else does"; the seeded MCDA losing bit-for-bit reproducibility, or EverSimmer no longer winning every named scenario and its baselined 98.42% Monte Carlo win share. |
| Traceability | `'traceability'` | `tTraceability` | Any of the 36 requirement links failing to resolve to a live architecture element, a link source landing outside its expected model, a link destination no longer matching an `SR-GS-*` id, the per-model link counts (10/10/16 for HyperCook/LeanBroth/EverSimmer) changing, or an allocation set losing members — `LogicalToEverSimmer` is baselined at 24 allocations. |
| System | `'system'` | `tSystemNominal`, `tSystemFault` | A physical architecture model's simulated steady-state packaged throughput drifting outside its tolerance band (308.4 / 196.8 / 231.9 bph for HyperCook / LeanBroth / EverSimmer), a plant not ending a clean run in `Nominal` mode, worst-single-fault retention drifting (0 / 0 / 0.672), or EverSimmer's supervisor failing to report `Degraded` under its cell fault. |

Each tier maps to an existing analysis document: the analysis tier baselines values from [`05_trade_study_methodology.md`](05_trade_study_methodology.md) and [`08_formal_compliance_gate.md`](08_formal_compliance_gate.md); the system tier baselines the simulated figures from [`09_behavioral_models.md`](09_behavioral_models.md) and [`10_behavioral_trade_update.md`](10_behavioral_trade_update.md).

## 3. Suite assembly and running it

Suite membership is project metadata, not a hard-coded file list: every test file (the four new classes' folder plus the pre-existing `behavior/tests/`) carries the MATLAB project's `Test` classification label, and `matlab.unittest.TestSuite.fromProject(currentProject)` discovers all of them — 37 tests in total (21 component + 16 across the four new tiers). Adding a test file to the project and labeling it `Test` is enough to fold it into the suite; nothing needs to be registered by path.

`tests/runAllTests.m` wraps suite assembly, tag filtering, and a coverage plugin:

```
runAllTests()            % entire suite: component + analysis + traceability + system
runAllTests("system")    % one tier only, by tag
```

It runs with `matlab.unittest.TestRunner.withTextOutput`. An earlier version attached a `CodeCoveragePlugin` over the analysis code, but line coverage of scripts exercised by the very tests being run proved circular rather than informative and was removed (ADR-023) — full runs now end with a *requirements coverage* summary instead: implemented / gate-checked / test-verified counts over all 28 SRs, with the formal document version generated by `analysis/reporting/makeRequirementsReport`. `assertSuccess` on the result means a non-zero exit is available to any CI wrapper that wants one, though this project runs the suite interactively today.

One chain-hygiene fix made running tiers back-to-back reliable: `runComplianceGate.m` now closes the `GalacticSoupComplianceGate` model on exit. Previously, the model stayed loaded after a gate run, and its embedded requirement set then blocked `slreq.clear` for any code that ran afterward in the same session — a documented gotcha ([`08_formal_compliance_gate.md`](08_formal_compliance_gate.md) §5) that the analysis and traceability tests now trip over directly, since both the analysis tier (which runs the gate) and the traceability tier (which calls `slreq.clear` before loading each model's link set) can land in the same session. `tRollupInvariants` and `tTraceability` additionally close the gate model defensively in their own class setup, in case it was left open by something outside the suite.

## 4. The golden-totals catch

The suite paid for itself before it was even finished. `tRollupInvariants`'s `goldenTotals` test baselines LeanBroth's mass/power/cost/volume at 7,570 kg / 1,070 kCr / 240 m³ (rounding aside, these match the current roll-up and the corrected figures in [`docs/explainers/01_static_rollup.md`](explainers/01_static_rollup.md)). Writing that assertion surfaced that an earlier value — 6,170 kg / 880 kCr / 200 m³ — had been circulating: it was a session dump taken while LeanBroth's kettles were mid-incident during the ADR-017 `linkToModel` stereotype-loss episode ([`07_decision_log.md`](07_decision_log.md) ADR-017), when the kettles' `PhysicalProperties` values were dropped from the roll-up. That transient, wrong snapshot had leaked into an explainer card and stuck around after the underlying bug was fixed and reverted.

This is the case for baselining values in a test rather than trusting a script's latest printout: the roll-up code was already correct by the time this was caught — the problem was a stale number that had escaped into a document and had no mechanism forcing it back into agreement with the code. A test that asserts the golden total is either right or fails; there is no third state where a wrong number just quietly persists in a card nobody re-derives.

## 5. Requirements-linking limitation

The traceability tier stops short of one thing it would ideally do: link the tests themselves to the requirements they verify, so a requirement's verification status could roll up from test results in the Requirements Editor / Test Manager the way a Requirements Table row's status does ([`08_formal_compliance_gate.md`](08_formal_compliance_gate.md)). That turns out not to be possible programmatically in R2026a. `slreq.createLink` rejects a `matlab.unittest.Test` element outright with "Link creation failed," and the `matlabtest` namespace exposes no API for creating a verification link from a test artifact. Neither a scripted workaround nor an alternative entry point was found.

The practical consequence: linking tests to requirements for verification-status rollup remains an interactive workflow — done by hand in the Requirements Editor or the Test Browser, not by a build script. `tTraceability` does not attempt to substitute for that link; instead it guards the thing that *is* checkable programmatically — that the 36 existing requirement links resolve to live architecture elements and that allocation sets stay complete — which is a different guarantee (link integrity) from verification-status rollup (which test proved which requirement), but is the one this suite can enforce without manual steps.

## 6. Runtime

The full suite (`runAllTests()`, all 37 tests) takes about 2.5 minutes. The system tier dominates: `tSystemNominal` and `tSystemFault` together simulate all three physical architecture models twice each (once nominal, once with a fault injected at 7,200 s, run out to 14,400–21,600 s of simulated time) — six full architecture simulations, against which the component, analysis, and traceability tiers are comparatively instantaneous. Running a single tier via `runAllTests("analysis")` or similar is the faster inner loop when iterating on roll-up, gate, or trade-study logic without needing a full system re-simulation.
