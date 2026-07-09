# 15 — Contamination Detection and SR-GS-007

Branch exploration: `contamination_ppm` had ridden along on the `SoupStream` bus since the bus was first defined, wired to a constant 0 at every producer and read by nothing downstream — a signal shaped like a requirement with no behavior behind it. SR-GS-007 requires contamination detection before sealing at 99% sensitivity or better, and the QC station that should have been doing that detection had never been asked to. This branch gives `BehQCStation` an actual contamination model, sweeps the incidence rate the requirement has to hold across, and converts SR-GS-007 from unexercised to verified-by-executed-test.

Artifacts: the two new model arguments and outports on the shared QC library model, instance-parameter wiring in [`../behavior/build/buildInlineBehaviors.m`](../behavior/build/buildInlineBehaviors.m), [`../analysis/sweeps/runContaminationSweep.m`](../analysis/sweeps/runContaminationSweep.m), [`../behavior/tests/tBehQCStation.m`](../behavior/tests/tBehQCStation.m) and [`../tests/analysis/tContamination.m`](../tests/analysis/tContamination.m), the `Contamination` suite in [`../tests/system/GalacticSoupSystemTests.mldatx`](../tests/system/GalacticSoupSystemTests.mldatx). Decision: ADR-027 in [`07_decision_log.md`](07_decision_log.md).

## 1. The stubbed signal nobody read

`SoupStream` carries a `contamination_ppm` element that has been present in the bus definition for as long as the bus has existed, and every producer in the behavioral layer sets it to a constant 0. Nothing downstream ever branched on it — the QC station's job, as originally modeled, was purely a quality-pass/quality-reject split on the existing quality signal, with no contamination logic anywhere in the chain. SR-GS-007 was consequently in the same bucket gravity dependence occupied before doc 14: a requirement with a component named for the job (the QC station), no implementation of the job, and no way for a test to exercise it. The fix is not touching the bus element itself — `contamination_ppm` stays as-is for now — but giving `BehQCStation` a real contamination path with its own detected/escaped accounting.

## 2. Detection model

`BehQCStation` gains two model arguments with neutral defaults, so every existing caller is unaffected until a dictionary override says otherwise:

| Argument | Default | Meaning |
|---|---|---|
| `ContamIncidence` | 0 | Fraction of the quality-passed stream that is contaminated |
| `DetectSensitivity` | 0.995 | Fraction of contaminated flow the station catches |

Contamination is applied to the quality-passed stream, `passflow_q`, not the raw input — the station only has to worry about contamination in soup it would otherwise have shipped:

```
contam    = passflow_q * ContamIncidence
detected  = contam * DetectSensitivity        -> routed to the reject stream
escaped   = contam * (1 - DetectSensitivity)  -> ships with the passed flow
```

Two new outports, `contamDetected_bps` and `contamEscaped_bps`, expose the split for logging and for test criteria. At `ContamIncidence = 0`, `contam` is identically zero regardless of `DetectSensitivity`, so the model is exactly neutral — every pre-existing throughput baseline stands unchanged: 308.4 / 196.8 / 231.9 bph for HyperCook, LeanBroth, and EverSimmer respectively, the same figures carried since doc 12's nominal suite.

`DetectSensitivity`'s default of 0.995 sits above the 0.99 requirement floor deliberately — margin against the requirement, not a value backed into from a measurement. The sweep in §3 includes a case that tests the floor itself.

Both new arguments are exposed at the top level via the shared dictionary as `QC_ContamIncidence` (default 0) and `QC_DetectSensitivity` (default 0.995), mapped into each `BehQCStation` instance through instance-parameter expressions in `buildInlineBehaviors.m` — the same generator, and the same per-run override mechanism (`setVariable(..., 'Workspace', model)`), that fault injection and the gravity sweep (docs 13 and 14) already established.

## 3. Design-space sweep

[`runContaminationSweep.m`](../analysis/sweeps/runContaminationSweep.m) sweeps `QC_ContamIncidence` over 0.5%, 1%, 2%, and 5% across all three variants, plus one boundary case with `QC_DetectSensitivity` set to 0.99 — the requirement floor itself, rather than the 0.995 design default — run on EverSimmer only. Results land in `contaminationResults.mat` and `contaminationSweep.csv`, with a summary figure at [`../docs/figures/contamination_sensitivity.png`](figures/contamination_sensitivity.png).

Measured sensitivity is flat at 0.9950 for every variant at every incidence point — as it must be, since the detection split is deterministic flow math; the sweep verifies the plumbing end-to-end through three different architectures rather than sampling a statistic. What varies is the cost of detection: rejecting detected contamination trims throughput roughly in proportion to incidence × sensitivity, and at the worst swept point (5% incidence) the variants land at 293.1 / 187.9 / 220.4 bph (HyperCook / LeanBroth / EverSimmer). No compliance verdict flips anywhere in the sweep: HyperCook and EverSimmer clear the 200 bph floor with room at 5% contamination, and LeanBroth stays below it as it already was at zero.

The boundary case measures exactly 0.9900 — a detector specified at the requirement floor meets the requirement with zero margin, which is precisely why the design value is 0.995 and not 0.99. The escaped-contamination rate at 2% incidence works out to about 103 ppm of packaged flow for the single-QC variants and 34 ppm for EverSimmer, whose per-cell QC stations each see only a third of the plant's flow.

That per-cell number is the one architectural observation in the sweep: contamination detection composes the same way fault tolerance does. EverSimmer's distributed QC doesn't detect any better (sensitivity is identical), but a contamination excursion in one cell is confined to a third of production, which is the same isolation argument that won it the fault-response comparison — showing up unprompted in a completely different quality metric.

## 4. Verification

Signal-logging marks go on `contamDetected_bps` and `contamEscaped_bps` for the QC instance in each variant — `QCBench` in LeanBroth, `InlineQCScanner` in HyperCook, and Cell 1's station only in EverSimmer (its other cells are not marked, consistent with the single-instance logging pattern established for gravity-related signals in doc 14). Simulink Test criteria read both signals from `test.sltest_simout.get('logsout')` and compute:

```
measured sensitivity = detected / (detected + escaped)
```

The `Contamination` suite in `GalacticSoupSystemTests.mldatx` adds two cases, both at 2% incidence:

| Case | Model | Criteria | Verify link |
|---|---|---|---|
| HyperCook contamination 2 percent | `PhysicalHyperCook` | measured sensitivity ≥ 0.99 AND throughput floor still met at 2% incidence | SR-GS-007 |
| EverSimmer contamination 2 percent | `PhysicalEverSimmer` | measured sensitivity ≥ 0.99 AND throughput floor still met at 2% incidence | SR-GS-007 |

LeanBroth gets neither a case nor a link, per the Verify-link semantics rule from doc 12 §3: LeanBroth's nominal throughput already sits below the SR-GS-002 floor, so a passing contamination case on top of an already-noncompliant baseline would not demonstrate SR-GS-007 being genuinely met in a shippable configuration. LeanBroth's numbers are still worth protecting — they're covered by the sweep in §3, which baselines them as a regression baseline without asserting requirement satisfaction.

Below the suite, `tBehQCStation.m` gains a component-level contamination method that checks the exact split ratios (`detected`/`contam`, `escaped`/`contam`) on the library model directly, isolated from the physical-variant simulations. `tContamination.m`, in the analysis tier, baselines the sweep results from §3 and the sensitivity-margin conclusion (0.995 design vs. 0.99 floor) as golden values.

With these two cases linked, the verified-by-test count in the requirements coverage summary grows from 5 to 6 of 28.

## 5. Gotchas

- **Dictionary-side names must differ from model-argument names.** The first attempt named the dictionary entry `ContamIncidence` — identical to the `BehQCStation` model argument it feeds. Every simulation warned that the symbol defined in the model workspace shadows the symbol in `BehParamsCommon.sldd`. The fix is the same `QC_` prefix convention already used elsewhere in the dictionary: the top-level override is `QC_ContamIncidence`, mapped into the model argument `ContamIncidence` via the instance-parameter expression, and the two names never collide again.
- **Contamination applies to the passed stream, not the input.** Computing `contam` from the station's raw input rather than `passflow_q` would double-count flow already rejected on quality grounds — a bug worth checking for explicitly in review, since both signals are available at the same point in the chart and the wrong one type-checks identically.
- **Neutrality at zero is what protects every existing baseline.** Because `contam = passflow_q * ContamIncidence` and the default is 0, the entire contamination path multiplies out to exactly zero with no rounding residue — the same "exactly neutral at the default" property doc 14 relied on for gravity scaling at 1 g, and the reason the 308.4/196.8/231.9 bph baselines needed no re-verification, only a neutrality check.
- **Verify-link asymmetry follows the compliance picture, not the test suite's convenience.** LeanBroth would pass a contamination criterion at 2% incidence in isolation — the QC station's detection math doesn't care which variant hosts it — but linking that pass to SR-GS-007 would claim the requirement is met by a variant that fails the throughput requirement it ships alongside. The link is withheld for the same reason doc 12 withheld LeanBroth's throughput link, not because the contamination behavior itself is suspect.
