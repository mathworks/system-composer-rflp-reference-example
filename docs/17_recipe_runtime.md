# 17 — Runtime Recipe Selection and SR-GS-001

SR-GS-001 requires the system to cook at least 8 distinct recipes, selectable at runtime. The `PreparedBatch` bus's `recipeId` element has been present since the bus was first defined and has never carried anything: every prep unit in every variant stubs it to a constant 0. There is no selection logic anywhere in the behavioral layer, no notion of a recipe schedule, and no signal a test could read to demonstrate that more than one recipe was ever cooked. SR-GS-001 sat in the same bucket as SR-GS-015 before doc 14, SR-GS-007 before doc 15, and SR-GS-006 before doc 16: a requirement with a component that could plausibly do the job and no behavior actually doing it. This branch gives every prep unit a real recipe schedule, gives HyperCook's continuous cook lines a changeover cost for switching mid-run, and converts SR-GS-001 from unexercised to verified-by-executed-test.

Artifacts: the `recipeSchedule` and `flushGate` helpers in [`../behavior/build/buildInlineBehaviors.m`](../behavior/build/buildInlineBehaviors.m), [`../analysis/sweeps/runRecipeSweep.m`](../analysis/sweeps/runRecipeSweep.m), [`../tests/analysis/tRecipes.m`](../tests/analysis/tRecipes.m), the `RecipeRotation` suite in [`../tests/system/GalacticSoupSystemTests.mldatx`](../tests/system/GalacticSoupSystemTests.mldatx). Decision: ADR-029 in [`07_decision_log.md`](07_decision_log.md).

## 1. The id nobody stamped

`recipeId` looks, from the bus definition alone, like a requirement that was already accounted for — a component named for the job (each prep unit hands a batch downstream with a recipe identifier attached) with no implementation behind the name. Every producer sets it to the same literal 0, every consumer downstream is free to ignore it since it never changes, and nothing in the plant has ever had a reason to switch what it was cooking. A test asserting "8 distinct recipes" against the pre-existing model would have measured exactly one recipe, forever, regardless of how the assertion was phrased. As with gravity dependence, contamination, and transport latency in the three preceding branches, the fix is not a new component — it is wiring a signal that already exists on the bus to something that actually varies it, and building the schedule that decides what it should be at any given moment.

## 2. Schedule and changeover model

Every prep unit, across all three variants, gains a `recipeSchedule` generator helper (`buildInlineBehaviors.m`; no library model changes) that computes:

```
activeRecipe = 1 + mod(floor(t / Recipe_Block_s), Recipe_Count)
```

built from `Clock`, `Gain`, `Floor`, and `mod` blocks, and stamps the result into `PreparedBatch.recipeId` at every prep unit in the plant. The schedule is a fixed round-robin, not a random draw or an externally commanded sequence: over one `Recipe_Block_s`-long block the plant cooks recipe `N`, then advances to `N+1` at the next block boundary, wrapping back to 1 after `Recipe_Count`. `activeRecipe` is signal-logged once per variant so a test can read back which recipe was active at any point in a run and count how many distinct values actually appeared.

Switching what a prep unit stamps is free — it is a label on a signal, not a physical changeover. The line actually cooking the soup is a different story on the two continuous architectures, HyperCook and EverSimmer's cook lines that run product through steadily rather than in discrete charges. A `flushGate` helper is applied to HyperCook's four continuous cook lines only: each line's enable is gated off for `Recipe_Flush_s` immediately after a recipe switch, computed from an in-flush pulse:

```
inFlush = mod(t, Recipe_Block_s) < Recipe_Flush_s
```

This is the requirement's actual cost of runtime recipe flexibility on a continuous line — residual product from the previous recipe has to clear before the next one starts, and until it does, the line does not count as producing compliant output. Batch vats get no flush gate at all, deliberately: a batch cycle already has a clean/refill phase between charges that the throughput baseline already pays for, so recipe changeover between batches rides a phase the cycle was never free of in the first place. The batch architectures get runtime recipe flexibility architecturally free — nothing in their model changes to grant it.

Three new parameters land in the shared dictionary: `Recipe_Count = 8`, `Recipe_Block_s = 1800` (one switch every 30 minutes, giving 8 recipes across a 4-hour production run), and `Recipe_Flush_s = 0`. The flush default is deliberately neutral, overridden per run rather than left at a realistic value, following the same convention as `Fault_T_*` and the gravity/contamination/transport parameters before it. At the defaults everything is exactly neutral: the throughput baselines carried since doc 12 hold exactly — 308.4 / 196.8 / 231.9 bph for HyperCook, LeanBroth, EverSimmer — and every variant produces all 8 distinct recipes over a production run with no cost anywhere, since a zero-length flush gates nothing.

A realistic flush is not zero. At `Recipe_Flush_s = 120` — two minutes to clear a continuous line after a recipe switch — HyperCook's throughput drops to 289.0 bph, down 19.4 from its 308.4 baseline, and still well clear of the 200 bph floor. That figure is what §4's verification case regression-baselines.

## 3. Pricing the flush

[`runRecipeSweep.m`](../analysis/sweeps/runRecipeSweep.m) prices HyperCook's flush at four points — `Recipe_Flush_s` = 0, 60, 120, and 300 s — to map out how much of HyperCook's margin above the 200 bph floor a realistic changeover time actually spends. The pricing is linear: 308.4 / 298.7 / 289.0 / 259.0 bph at 0 / 60 / 120 / 300 s of flush — about 9.9 bph per flush-minute, one line-minute of output per switch across four lines and eight switches per production run. Even the pessimistic 300 s flush leaves HyperCook at 259 bph, 30% above the floor, and every swept production run still produces all 8 recipes.

The batch variants are immune to this sweep by construction, not by measurement: the flush gate only exists on HyperCook's continuous cook lines, so sweeping `Recipe_Flush_s` has no path to affect LeanBroth or EverSimmer's throughput at all, regardless of how large the flush is set. That is this branch's architectural observation — recipe flexibility is where batch cooking finally wins one. Every prior comparison in this project (throughput, resource margin, fault isolation, contamination containment) has gone continuous's or the distributed architecture's way; changeover cost is the first axis where continuous throughput pays a real price and a batch cycle hides the same cost inside a phase it was already budgeting for.

## 4. Verification

The Simulink Test file gains a `RecipeRotation` suite with two cases:

| Case | Model | Criteria | Verify link |
|---|---|---|---|
| HyperCook recipe rotation | `PhysicalHyperCook` (`Recipe_Flush_s` overridden to 120 s) | ≥ 8 distinct recipes in the logged `activeRecipe` signal AND throughput floor met AND throughput within a regression band of 289.0 bph | SR-GS-001 |
| EverSimmer recipe rotation | `PhysicalEverSimmer` (no override needed) | ≥ 8 distinct recipes in the logged `activeRecipe` signal AND throughput floor met AND throughput within a regression band of 231.9 bph | SR-GS-001 |

HyperCook's case is the one that actually exercises the flush gate — it runs with a realistic, non-neutral `Recipe_Flush_s` rather than the dictionary default, so the regression band is set against 289.0 bph, the flushed figure from §2, not the unflushed 308.4. EverSimmer needs no override at all: it has no flush gate to begin with, so its nominal run already produces 8 distinct recipes at its untouched 231.9 bph baseline.

LeanBroth also produces all 8 recipes over a production run — the schedule stamps `recipeId` identically at every prep unit regardless of variant — but stays unlinked, per the same rule doc 15 and doc 16 both apply: LeanBroth fails the SR-GS-002 throughput floor, so a passing case cannot honestly be presented as SR-GS-001 being met in a shippable configuration. LeanBroth's recipe numbers are not thrown away — they are covered by the sweep's neutrality checks and by `tRecipes.m` — they are just not the basis of a Verify link.

`tRecipes.m`, in the analysis tier, baselines both the sweep from §3 and the batch-immunity property — that `Recipe_Flush_s` has zero effect on LeanBroth's and EverSimmer's throughput at any swept value — as golden values.

With these two cases linked, the verified-by-test count in the requirements coverage summary grows from 7 to 8 of 28.

## 5. Gotchas

- **Signal-logging marks must be applied after the logged line exists, not before.** `recipeSchedule`'s first draft tried to mark its own `activeRecipe` output for logging before the caller had wired that output into the prep unit's line — the mark call received a handle to a line that did not exist yet in the diagram's connection graph, and failed with "Invalid Simulink object handle." The fix is a `logLine` helper, called after `lineTo` has actually made the connection, so the mark always targets a line that is live in the model. This is the third time this exact ordering trap has appeared in the generator — first on vat-temperature logging, then on QC contamination logging, now on the recipe log — and it is worth calling out as a pattern rather than three unrelated bugs: any helper that both creates a signal and wants to log it must sequence the mark strictly after the wiring, never inline with it. It is now a named convention in the generator rather than a lesson re-learned per branch.
