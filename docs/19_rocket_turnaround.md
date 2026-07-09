# 19 — Rocket Turnaround and SR-GS-018

SR-GS-018 requires the system to complete loading or unloading of a delivery rocket within 20 minutes (1200 s). Unlike the branches that preceded it, this one adds no new behavior to any model. Turnaround is fill time plus handling, and fill time is already sitting in the loaded-shipment flow that doc 16 logged to satisfy SR-GS-006 — `loadedFlow_bps`. The only genuinely new content is two shared-dictionary parameters, both flagged as engineering estimates, and the measurement code that turns an existing signal into a turnaround figure. This is the cheapest increment of the verification series so far, and it rides entirely on instrumentation built for a different requirement.

Artifacts: [`../analysis/sweeps/runTurnaroundSweep.m`](../analysis/sweeps/runTurnaroundSweep.m), [`../tests/analysis/tTurnaround.m`](../tests/analysis/tTurnaround.m), the `RocketTurnaround` suite in [`../tests/system/GalacticSoupSystemTests.mldatx`](../tests/system/GalacticSoupSystemTests.mldatx). Decision: ADR-031 in [`07_decision_log.md`](07_decision_log.md).

## 1. Riding existing instrumentation

Every loader already logs `loadedFlow_bps` — the cumulative loaded-bowl flow doc 16 built to derive transport latency for SR-GS-006. That signal answers a question SR-GS-018 also needs answered: how long does it take to move one rocket's worth of bowls across the dock? No block diagram changes, no new signal taps, no model rebuild. The elaboration is:

- `Rocket_Load_bowls = 60` — the nominal shipment size per rocket, an estimate.
- `Rocket_Handling_s = 120` — dock and undock overhead not captured by the flow signal at all: securing the rocket, opening and closing the cargo interface, paperwork-equivalent delay. Also an estimate.

Both parameters go into the shared dictionary alongside `Transport_Rate_bph` and `Transport_Latency_s`, and both carry the same estimate flag those doc-16 parameters carried before they were exercised — there is no measured basis for either number yet, only a plausible placeholder pending a logistics-owner sign-off.

## 2. Turnaround model and the sweep

Turnaround is modeled as:

```
turnaround = fill_time(R) + Rocket_Handling_s
```

`fill_time(R)` is the time for the cumulative `loadedFlow_bps` curve to advance by `R` bowls — one rocket load — measured the same way doc 16 measured latency: robust to startup transients and to residual burstiness in the flow curve. The measurement takes 11 steady-state start points spanning 30% to 70% of cumulative production, computes the crossing time for each, and reports the median. Handling is a flat addition — `Rocket_Handling_s`, currently 120 s for all three variants — layered on top of whatever fill time the flow curve gives.

[`runTurnaroundSweep.m`](../analysis/sweeps/runTurnaroundSweep.m) sweeps `R = [40 60 80 120]` bowls per variant. Because fill time for any `R` falls out of the same cumulative curve — the curve doesn't change shape with shipment size, only the distance being measured along it does — the sweep needs exactly one nominal simulation per variant, three simulations total, not twelve.

## 3. Results and the shipment envelope

| R (bowls) | HyperCook | LeanBroth | EverSimmer |
|---|---|---|---|
| 40 | 580.6 s | 900.4 s | 696.4 s |
| 60 (design) | 808.1 s | 1241.5 s | 1086.0 s |
| 80 | 1039.3 s | 1568.8 s | 1389.1 s |
| 120 | 1497.8 s | 2227.1 s | 1965.9 s |

Against the 1200 s ceiling: everyone passes at 40 bowls, everyone fails at 120. At the 60-bowl design shipment, results split — HyperCook passes at 808.1 s, EverSimmer passes at 1086.0 s with 114 s of margin, and LeanBroth fails at 1241.5 s, missing the ceiling by 41.5 s.

Interpolating linearly between swept points gives the compliant shipment-size envelope for each variant: roughly up to 92 bowls for HyperCook, 66 for EverSimmer, and 57 for LeanBroth. HyperCook's envelope comfortably contains the 60-bowl design point; EverSimmer's contains it with room to spare; LeanBroth's does not.

**Caveat.** Both `Rocket_Load_bowls` and `Rocket_Handling_s` are estimates, not measured quantities, and LeanBroth's fail verdict is sensitive to them — at a 55-bowl shipment size, LeanBroth would pass. A single-point verdict at the assumed design shipment would either overstate confidence in a pass or understate how close a fail sits to flipping. The sweep is the honest response to that sensitivity: publish the envelope, not just the design-point verdict. If the logistics owner later fixes the real shipment size — or refines either estimate — the envelope and the baselines in `tTurnaround.m` say exactly where each variant stands without rerunning the analysis.

## 4. Verification

The `RocketTurnaround` suite gains three cases, each measured from the logged loaded-flow curve at the 60-bowl design shipment:

| Case | Model | Criteria | Verify link |
|---|---|---|---|
| HyperCook rocket turnaround | `PhysicalHyperCook` | turnaround ≤ 1200 s AND within regression band of 808.1 s | SR-GS-018 |
| EverSimmer rocket turnaround | `PhysicalEverSimmer` | turnaround ≤ 1200 s AND within regression band of 1086.0 s | SR-GS-018 |
| LeanBroth rocket turnaround | `PhysicalLeanBroth` | turnaround > 1200 s AND within regression band of 1241.5 s | none |

HyperCook and EverSimmer carry Verify links to SR-GS-018 — both genuinely meet the requirement at the design shipment. LeanBroth's case is deliberately unlinked: it is a regression baseline asserting turnaround exceeds 1200 s, the same convention doc 18 used for the SR-GS-021 endurance cases. The point of asserting the failure rather than only recording it is that a future fix — a smaller design shipment, a lower handling estimate, an actual dock-process improvement — will fail this case the moment it succeeds, forcing whoever makes that change to consciously retire the finding instead of having it silently stop being true.

`tTurnaround.m`, in the analysis tier, baselines both the design-point figures and the envelope pattern from §3 as golden values. With the two new links, the verified-by-test count in the requirements coverage summary grows from 8 to 9 of 28.

## 5. Gotchas

- **Fill time is a production-rate measurement, not a dock-capacity measurement.** At steady state the dock forwards production one-for-one, so `loadedFlow_bps`'s slope tracks each variant's throughput baseline, not its pickup capacity. The turnaround ranking across variants is therefore the throughput ranking, inverted — the slower producer takes longer to accumulate one rocket load, regardless of how fast its dock could move bowls if it had more of them to move.
- **A batchy loading profile inflates fill time beyond what a naive rate calculation predicts.** EverSimmer's loaded-flow curve is not smooth — it arrives in discrete charges rather than a steady trickle — and measuring fill time off the actual cumulative curve catches that: 966 s measured at R = 60 versus roughly 931 s from a naive bowls-over-rate calculation using EverSimmer's nominal throughput. The gap is small in absolute terms but is exactly the kind of discrepancy the median-of-11-crossings method exists to catch — a single-point measurement landing on a batch gap would have reported a worse or better number depending on luck, not physics.
