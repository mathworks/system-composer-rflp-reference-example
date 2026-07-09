# 18 — Storage Endurance and the SR-GS-021 Finding

SR-GS-021 requires the system to store at least 72 hours of ingredients at nominal production rate. Every branch through doc 17 has followed the same arc: find a requirement with a plausible-looking component and no behavior behind it, wire the behavior in, and watch the requirement convert from unexercised to verified. This branch breaks that arc. The cutoff mechanism and the endurance measurement both work as intended, and the answer they produce is that none of the three variants comes anywhere close to 72 hours — not by a margin that a parameter tweak closes, but by an order of magnitude. Worse, the mass a compliant store would need to carry does not fit inside the system's own mass budget. SR-GS-021 is this verification series's first requirement where the finding is not "the behavior was missing" but "the requirement, as written, cannot be met by any of the three architectures" — and that is the finding this document records, not a verification.

Artifacts: the `Resupply_Cutoff_T` gate in [`../behavior/build/buildInlineBehaviors.m`](../behavior/build/buildInlineBehaviors.m), [`../analysis/sweeps/runEnduranceStudy.m`](../analysis/sweeps/runEnduranceStudy.m), [`../tests/analysis/tEndurance.m`](../tests/analysis/tEndurance.m), the `StorageEndurance` suite in [`../tests/system/GalacticSoupSystemTests.mldatx`](../tests/system/GalacticSoupSystemTests.mldatx). Decision: ADR-030 in [`07_decision_log.md`](07_decision_log.md).

## 1. The 72-hour question

Nothing in the model before this branch could answer how long the plant runs on stored ingredients alone, because nothing ever stopped resupply. Every variant's ingredient stores are fed continuously, so a store's capacity was a sizing number sitting in the dictionary with no scenario that ever drew it down to empty. SR-GS-021 asks a specific question — with resupply cut off entirely, at nominal production rate, how long does the system keep producing before it runs out of ingredients — and answering it requires a scenario that does not otherwise occur: a resupply source that stops.

## 2. Cutoff mechanism and measurement

Every variant's resupply source gains a cutoff gate: a `Step` block at `Resupply_Cutoff_T`, with a model-workspace default of `1e9` seconds — effectively never, within any run length this project simulates — overridable per run through `setVariable(..., 'Workspace', model)`, the same mechanism used for fault injection, gravity, contamination, and transport in the branches before it. At the default, the gate is neutral: resupply never cuts, and every throughput baseline carried since doc 12 holds exactly.

[`runEnduranceStudy.m`](../analysis/sweeps/runEnduranceStudy.m) runs the actual scenario: it fills every ingredient store to capacity, sets `Resupply_Cutoff_T` to 3600 s, and runs 12 more hours past the cutoff. Endurance is measured as the last productive instant minus the cutoff time — the length of time the plant kept producing bowls after resupply stopped, using whatever was already sitting in the stores.

**Gotcha — a first-dip detector mistakes a batch gap for starvation.** The first version of the measurement looked for the first instant production dropped to zero after the cutoff and reported the gap to that instant as endurance. On LeanBroth this reads 1.04 h. LeanBroth's output is bursty by construction — it is a batch architecture, and production comes in discrete charges with gaps between them — so a first-dip detector finds the first ordinary batch gap after the cutoff and reports it as the store running dry, long before the store actually does. The true figure, measured as the last productive instant across the full 12-hour post-cutoff window, is 4.66 h. Last-productive-instant is the robust form of this measurement; first-dip is not, and the discrepancy is large enough (4.5x) that it would have materially understated LeanBroth's actual endurance had it gone unnoticed.

## 3. Results: an order of magnitude short

With the robust measurement in place, `runEnduranceStudy.m` reports:

| Variant | Store capacity | Endurance | Bowls produced after cutoff | Required |
|---|---|---|---|---|
| HyperCook | 2000 bowls | 6.41 h | 1948 | 72 h |
| LeanBroth | 800 bowls | 4.66 h | 917 | 72 h |
| EverSimmer | 1200 bowls | 5.44 h | 1259 | 72 h |

Every variant is short of the 72-hour requirement by roughly an order of magnitude — HyperCook comes closest at 6.41 h, still 11x short. This is not a near-miss that a modest store-capacity increase resolves; it is a gap wide enough that closing it means asking what the requirement, and the store sizing behind it, are actually supposed to represent.

## 4. The requirements conflict

The reason none of the three architectures gets close is not that their stores are undersized relative to their own design intent — it is that a store sized to actually hold 72 hours of ingredients does not fit in the system.

72 hours at nominal production rate works out to 14170 bowls of ingredient throughput for LeanBroth, up to 22205 bowls for HyperCook, and 16697 bowls for EverSimmer. At 0.55 kg per bowl, that is:

| Variant | Bowls for 72 h | Ingredient mass |
|---|---|---|
| HyperCook | 22205 | 12213 kg |
| LeanBroth | 14170 | 7793 kg |
| EverSimmer | 16697 | 9183 kg |

SR-GS-011 caps total system mass at 15000 kg — machinery included. HyperCook's compliant ingredient store alone would consume 12213 kg of that budget, leaving 2787 kg for every vat, line, gantry, and structural member in the plant. LeanBroth and EverSimmer fare better in absolute terms but still commit roughly half the total mass budget to stored ingredients before a single piece of machinery is accounted for.

SR-GS-021 as written is not satisfiable alongside SR-GS-011 by any of the three architectures. This is a conflict between two requirements, not a shortfall in one design. Resolving it is a requirements-owner decision, not an engineering one: relax the 72-hour figure, raise the 15000 kg mass budget, or exclude ingredient mass from the system mass budget that SR-GS-011 governs. The third option is the likely intended reading — a mass budget meant to bound the machinery the system carries, not the consumable inventory that machinery processes — but that reading is not what SR-GS-011 currently says, and changing what it says is a decision this document is not positioned to make on its own.

## 5. What happens next

No Verify link is attached to SR-GS-021 for any variant. The link means a requirement is met; nothing here passes, so nothing here is linked. The verified-by-test count in the requirements coverage summary stays at 8 of 28 — deliberately. Dressing this finding up as a verification would misrepresent what the endurance study actually shows, and the dashboard's value depends on that not happening.

What does get added is a `StorageEndurance` suite with three regression-baseline cases — one per variant — each running the resupply-cutoff scenario against a full store and asserting the measured endurance falls within its band (6.41 / 4.66 / 5.44 h, ±0.3 h). Each case also asserts endurance is less than 72 hours. That second assertion is the point: it means a future redesign that actually closes the gap — a larger store, a different resupply architecture, a relaxed requirement — will fail this suite the moment it succeeds, forcing whoever makes that change to consciously retire the finding rather than have it silently stop being true. `tEndurance.m`, in the analysis tier, baselines both the endurance figures and the mass-conflict numbers from §4 — the required storage mass exceeding half the total mass budget for every variant — as golden values, so the conflict is recorded as a regression baseline alongside the endurance figures rather than left as a one-time calculation in this document.

The options for a requirements owner are the three laid out in §4: relax SR-GS-021's 72-hour figure to something the architectures can actually carry, raise SR-GS-011's 15000 kg ceiling to accommodate compliant storage, or clarify SR-GS-011's scope to exclude ingredient mass. Until one of those decisions is made, SR-GS-021 remains open, unmet, and — per the regression baselines above — will stay visibly unmet even as the rest of the model continues to change underneath it.


## 6. Resolution (ADR-032, 2026-07-08)

The requirements owner resolved the conflict: consumables are excluded from the SR-GS-011 mass budget. The stores were resized to 72 hours at each variant's nominal rate (22300 / 14300 / 16800 bowls), the rack hardware that still counts against every budget went into the storage components' stereotypes, and this document's finding-era regression baselines - built with `< 72 h` assertions precisely so a fix would have to retire them consciously - were retired consciously. SR-GS-021 is now verified for all three variants (projected endurance 72.3 / 72.6 / 72.8 h).

The resolution had a price the finding predicted qualitatively: HyperCook's 20 kCr cost margin and 3 m3 volume margin could not absorb 20,300 bowls of racking. It now fails the cost and volume gates (2061.2 kCr / 417.3 m3 against 2000 / 400), the compliance gate reads 21/24, and the compliant set is {EverSimmer} alone - the trade study is a forced selection. Fixing one requirement moved the non-compliance somewhere else, which is exactly the kind of consequence a requirements decision should get to see before anyone builds a soup factory.
