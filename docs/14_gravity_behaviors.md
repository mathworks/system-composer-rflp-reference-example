# 14 — Gravity-Dependent Behavior and New Requirement Verification

Branch exploration: the behavioral layer had no gravity dependence at all, despite SR-GS-015 requiring nominal operation across 0.1 g to 12 g — and despite every variant carrying a gravity-compensation component that had never been asked to compensate for anything. This branch gives the behaviors gravity physics, sweeps the full required range, and converts three previously-unexercised requirements (SR-GS-015, SR-GS-025, SR-GS-008) into verified-by-executed-test status. Two design findings came out, one per fidelity direction: the trade winner has a microgravity hole, and the vat targeted the top of the serving-temperature band.

Artifacts: gravity physics in [`../behavior/build/buildInlineBehaviors.m`](../behavior/build/buildInlineBehaviors.m) (instance-parameter expressions), [`../analysis/sweeps/runGravitySweep.m`](../analysis/sweeps/runGravitySweep.m), [`../tests/analysis/tGravity.m`](../tests/analysis/tGravity.m), the `GravityExtremes` suite in [`../tests/system/GalacticSoupSystemTests.mldatx`](../tests/system/GalacticSoupSystemTests.mldatx). Decision: ADR-026 in [`07_decision_log.md`](07_decision_log.md).

## 1. Where the physics lives

No behavioral library model changed. The gravity effects are **instance-parameter expressions** on the existing `Beh*` model references, evaluated in the parent architecture's resolution context — which is exactly what makes per-run overrides work: `Gravity_g` sits in the shared dictionary (default 1), and `setVariable('Gravity_g', g, 'Workspace', model)` shadows it per simulation, the same mechanism the fault injection and the uncertainty study use.

| Effect | Expression | Physics |
|---|---|---|
| Batch vat drain | `DrainTime_s / sqrt(Gravity_g)` | Torricelli: gravity-driven outflow speed scales with √g. At 0.1 g a drain takes 3.16× longer; the chart's `outflow = BatchSize/DrainTime` stays self-consistent (same batch, slower flow). |
| Robotic prep (HC, ES) | `PrepRate · max(0.5, 1 − 0.015·max(0, g−4))` | Servo torque margin: gentle derate above 4 g, floor at 50%. |
| Manual prep (LB) | `PrepRate · max(0.5, 1 − 0.05·max(0, g−2))` | Human-paced work derates from 2 g, three times steeper than robotics. |
| Continuous cook lines | none | Pumped, closed-loop flow: gravity-insensitive by design. This is HyperCook's quiet superpower. |

All scaling is exactly neutral at 1 g (√1 = 1, derates inactive), so every pre-gravity baseline in the suite remains authoritative — `tGravity/oneGNeutrality` pins that contract permanently.

## 2. The sweep

`runGravitySweep` simulates all three architectures at 8 points spanning the SR-GS-015 range (24 simulations, `parsim`, ~2.5 min):

| g | 0.1 | 0.25 | 0.5 | 1 | 2 | 4 | 8 | 12 |
|---|---|---|---|---|---|---|---|---|
| HyperCook | 308 | 308 | 308 | 308 | 308 | 308 | 290 | 271 |
| LeanBroth | 163 | 189 | 197 | 197 | 197 | 171 | 144 | 100 |
| EverSimmer | **189** | 221 | 231 | 232 | 234 | 232 | 224 | **201** |

**Finding 1: EverSimmer fails SR-GS-015 at 0.1 g.** Its batch vats drain at √g, and at 0.1 g the stretched drain phase costs it 43 bph, landing at 189 against the 200 floor. It also holds only a 0.9 bph margin at 12 g. The trade winner — the resilience champion that survives any single fault — cannot serve a microgravity outpost as designed. The redesign path is pump-assisted vat drains, which would also buy back its 12 g margin. HyperCook, whose pumped continuous lines never touch gravity, is the only variant compliant across the full range; LeanBroth is compliant nowhere and its human-paced prep collapses to 100 bph at 12 g.

## 3. New requirement verification

The Simulink Test file gains a `GravityExtremes` suite and richer nominal criteria; the verified-by-test column of the requirements coverage summary grows from 2 to 5:

| SR | Verified by | How |
|---|---|---|
| SR-GS-015 (gravity range) | HyperCook at 0.1 g + at 12 g | Floor check with `Gravity_g` parameter overrides; only HyperCook links, per the Verify-link semantics rule. EverSimmer's 0.1 g case stays an unlinked regression baseline (189.3 band) documenting the hole. |
| SR-GS-025 (startup readiness) | HC + ES nominal | First packaged output within the defined 3600 s startup period (HC: ~2 min; ES: ~50 min). |
| SR-GS-008 (serving temperature) | ES nominal | Vat temperature sampled *while draining* (state == `VAT_DRAIN`, via logged `vatTemp_Cell1`/`vatState_Cell1` signals) must sit in 70–95 °C. |

**Finding 2: the vat targeted the top of the serving band.** The first run of the SR-GS-008 criterion failed: serving temperature reached 95.23 °C. The design had `SimmerTemp_C = 95` — the band edge — and the bang-bang heater's ±0.5 °C ripple carried drain-onset temperature past the limit. The fix is design margin, not test tolerance: target 94 °C, serve at 92.5–94.2 °C. Cycle-time impact is ~3 s in ~1,860 (all throughput baselines hold to the displayed digit). This is the golden-values philosophy meeting requirements verification: the criterion refused to vouch for a band-edge design, and the requirement pushed a real margin decision back into the model.

## 4. Gotchas

- `parsim` requires all `SimulationInput` objects in one call to target the same model — batch per variant.
- `DataLogging` is a property of the source **port**, not the line; the line takes only the `Name`. And the logging mark can only be applied after the port's line exists — generator ordering matters.
- Signal-logging marks inside inline behaviors surface in the top model's `logsout`, and Simulink Test criteria reach them via `test.sltest_simout.get('logsout')` — the clean route for component-internal quantities (vat temperature) that don't warrant interface changes.
- Instance-parameter expressions are the lightest place to put environment physics: evaluated in the parent's context (so dictionary + model-workspace override machinery just works), visible in one grep, zero library churn, and exactly neutral when the environment variable is at its default.
