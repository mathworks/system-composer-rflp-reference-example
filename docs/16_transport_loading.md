# 16 — Transport Loading Latency and SR-GS-006

Branch exploration: SR-GS-006 requires packaged soup to reach transport within 10 minutes of packaging (a 600 s ceiling), and all three loader components — LeanBroth's `SharedCraneDock`, HyperCook's `CargoLoaderGantry`, EverSimmer's `AutoCargoLoader` — were rate-capped pass-throughs with the cap hard-coded in the block rather than driven by anything. The dictionary already carried `Transport_Rate_bph` (250/400/300) and `Transport_Latency_s` (120/30/60) per variant, and nothing read either of them. SR-GS-006 sat in the same bucket as SR-GS-015 before doc 14 and SR-GS-007 before doc 15: implemented in name, unexercised in practice. This branch gives each loader a real dock-and-transit model, sweeps loading capacity down toward the point where latency would breach the ceiling, and converts SR-GS-006 from unexercised to verified-by-executed-test.

Artifacts: the dock-and-transit path in [`../behavior/build/buildInlineBehaviors.m`](../behavior/build/buildInlineBehaviors.m), [`../analysis/sweeps/runTransportSweep.m`](../analysis/sweeps/runTransportSweep.m), [`../tests/analysis/tTransport.m`](../tests/analysis/tTransport.m), the `TransportLoading` suite in [`../tests/system/GalacticSoupSystemTests.mldatx`](../tests/system/GalacticSoupSystemTests.mldatx). Decision: ADR-028 in [`07_decision_log.md`](07_decision_log.md).

## 1. Parameters nobody used

`Transport_Rate_bph` and `Transport_Latency_s` had entries in the shared dictionary for all three variants — 250/400/300 bph and 120/30/60 s respectively — with plausible-looking, per-variant-distinct values that suggested someone had sized them against the real loaders at some point. Nothing was wired to either. Each loader's cap was a literal number baked into the block, disconnected from the dictionary entries sitting next to it, and there was no transit delay anywhere in the loading path at all — a packaged bowl and a loaded bowl were the same event in the model. SR-GS-006 could not fail, because there was no latency for it to measure.

## 2. The dock model

Each loader gains a `dockPath` (a generator helper in `buildInlineBehaviors.m`, shared across all three instances) consisting of a fluid dock queue followed by a transit delay:

```
out   = min(pickupRate, in + level/30)
level = integral(in - out), saturated to [0, 600] bowls
```

`pickupRate` now comes from `Transport_Rate_bph`, dictionary-driven and overridable per run through the same model-workspace mechanism (`setVariable(..., 'Workspace', model)`) used for gravity and contamination. The queue absorbs any momentary mismatch between packaging output and pickup capacity; `level` is the backlog sitting at the dock waiting to be picked up, and it only grows if packaging is outrunning transport.

Downstream of the queue, a `Transport Delay` block set to `Transport_Latency_s` sits on a measurement tap — not in the mass-flow path itself. Loading latency, as reported to the requirement, is queue wait plus this fixed transit time. Two neutrality problems surfaced getting the model to this shape, both worth walking through since they are the reason the architecture looks the way it does rather than the more obvious alternative.

**Gotcha 1 — a stateful queue leaks flow under a variable-step solver.** The first attempt used a `BehStorage` instance as the dock queue, with its draw rate set above the expected inflow so it would behave as a pass-through in the steady state. It doesn't: `BehStorage` chatters at empty — the solver takes steps that briefly let level go slightly negative or oscillate around zero before saturation clamps it back, and each chatter step loses a sliver of flow that never gets replayed. Over a full run this cost HyperCook 5-10% of its throughput baseline (308.4 → 277.4 bph), for no reason connected to the physics being modeled. The fluid-queue form above passes flow through *exactly* when the queue is empty — `out = min(pickupRate, in + 0/30) = min(pickupRate, in)`, and when `in <= pickupRate` that's just `in` — with no state to chatter, because the min/saturate arithmetic is memoryless at the instant the level is zero. That closed-form neutrality is why the fluid queue replaced `BehStorage` rather than the other way around.

**Gotcha 2 — a transit delay in the mass-flow path shifts measurement windows, not just latency.** Wiring the `Transport Delay` directly into the root output — so the loader's mass-flow port itself carried the delayed signal — shifted LeanBroth's bursty, batch-shaped flow relative to the steady-state window used to measure throughput. The delay is deterministic and the shift is real, but it isn't physics the requirement cares about: it moved LeanBroth's measured throughput from 196.8 to 194.1 bph purely as a windowing phase artifact, breaking a baseline that doc 12 had already settled. The fix is that the root port carries the queue's output undelayed — packaging-side throughput is unaffected by transport latency, which is correct, since a loading delay does not change how fast soup gets packaged. The `Transport Delay` rides a measurement-only tap instead, logging `loadedFlow_bps` alongside the existing `packedFlow_bps`; latency is derived from the pair of logged signals, not from anything in the mass-flow chain. With this split, all three throughput baselines hold exactly: 308.4 / 196.8 / 231.9 bph for HyperCook, LeanBroth, EverSimmer.

Latency itself is computed as the median, over mass thresholds from 20% to 80% of cumulative production, of the time lag between the packed and loaded cumulative curves — a threshold-crossing measurement robust to the startup transient and to any residual burstiness in the packed-side curve.

At nominal capacity, measured latency equals transit time exactly — HyperCook 30 s, LeanBroth 120 s, EverSimmer 60 s — because the dock queue never backs up: pickup capacity exceeds packaging rate in every variant at 100% of nominal, so `level` stays at zero and the queue contributes no wait. All three sit far below the 600 s ceiling.

## 3. Design-space sweep

[`runTransportSweep.m`](../analysis/sweeps/runTransportSweep.m) derates transport pickup capacity through 100%, 80%, 60%, and 40% of nominal for each variant — 12 simulations via `parsim` — to find where a degraded transport capability starts eating into the SR-GS-006 margin. As pickup capacity falls below packaging throughput, the dock queue backs up and queue wait starts contributing to latency on top of the fixed transit time; the question the sweep answers is how far capacity has to degrade before that wait pushes total latency toward the 600 s ceiling.

Every variant holds the ceiling at 80% capacity and loses it decisively by 60%: latencies at the four sweep points run 30.0 / 30.5 / 1547.7 / 3312.3 s for HyperCook, 120.0 / 196.6 / 1434.3 / 2921.8 s for LeanBroth, and 60.0 / 86.1 / 1275.7 / 2697.9 s for EverSimmer. The margin cliff is a fluid-queue property: the moment pickup capacity falls below production rate the backlog grows without bound, so the interesting number is not where the cliff is (between 80% and 60% for everyone) but who stands closest to its edge. That is LeanBroth: at 80% its pickup rate is 200 bph against 196.8 bph of production — a 1.6% margin — and its latency has already climbed from 120 s to 196.6 s while the other two variants barely move. The same low-capital sizing philosophy that gives LeanBroth its budget headroom leaves it one sluggish crane away from a loading backlog.

Figure: [`figures/transport_latency.png`](figures/transport_latency.png).

## 4. Verification

The Simulink Test file gains a `TransportLoading` suite with three cases, one per variant, each run at nominal transport capacity:

| Case | Model | Criteria | Verify link |
|---|---|---|---|
| HyperCook transport loading | `PhysicalHyperCook` | latency ≤ 600 s AND latency within a regression band of transit time (30 s) | SR-GS-006 |
| LeanBroth transport loading | `PhysicalLeanBroth` | latency ≤ 600 s AND latency within a regression band of transit time (120 s) | SR-GS-006 |
| EverSimmer transport loading | `PhysicalEverSimmer` | latency ≤ 600 s AND latency within a regression band of transit time (60 s) | SR-GS-006 |

All three variants carry the Verify link, including LeanBroth — the first Verify link LeanBroth has earned anywhere in the suite. LeanBroth fails the throughput floor in SR-GS-002 and has been withheld from every other Verify link on that basis (docs 12 and 15 both apply the rule explicitly), but SR-GS-006 is a different requirement measuring a different thing: it asks whether packaged soup reaches transport within 10 minutes, and LeanBroth's dock-and-transit path genuinely does that, independent of whether LeanBroth ships enough soup overall to be a compliant design. The link-attaches-only-where-a-passing-case-means-the-requirement-is-met rule cuts both ways — it withholds a link where a pass would misrepresent overall compliance, and it grants one where a pass is a truthful statement about the specific requirement under test, even from a variant that fails elsewhere.

`tTransport.m`, in the analysis tier, baselines the sweep from §3 as golden values — the per-variant, per-capacity-point latency figures and the transit-time-only nominal case.

With these three cases linked, the verified-by-test count in the requirements coverage summary grows from 6 to 7 of 28.

## 5. Gotchas

- **`BehStorage` chatters at empty under a variable-step solver and leaks flow.** Any queue-like component sitting at zero level with a draw rate above inflow is a candidate for this — the fix is not a tighter tolerance on the storage block but a memoryless closed form (`min(cap, in + level/30)`) that has no state to chatter through.
- **The measurement-tap pattern: delay the copy, not the original.** Any time a delay or transformation exists purely to produce a reported quantity rather than to change what downstream consumers receive, it belongs on a tap off the signal, not spliced into the signal itself — splicing it in shifts whatever measurement window depends on the original signal's timing, and the shift is real but not meaningful. Doc 14's vat-temperature logging used the same shape for a different reason (state-conditioned sampling); this is the failure-mode version: putting the transform in-line breaks a baseline that has nothing to do with the transform's intent.
- **`addBlock`-style instance-parameter rows for the dock queue want N-by-2 form, not concatenated scalars.** The queue's saturation limits and the transit latency are set together as parameter pairs on the instance; writing them as separate scalar assignments in the same expression silently produces the wrong array shape for the block's expected `[min max]` parameter, which then either errors at compile or — worse — accepts a shape Simulink coerces without complaint. The generator builds these as an explicit N-by-2 row per instance rather than assembling scalars.
