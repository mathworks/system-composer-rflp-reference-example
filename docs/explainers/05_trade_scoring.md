# Pick a Winner You Can Defend

**The question this answers:** Which one should we actually build — and how do the ones we cannot build compare?

## How it works

- Seven criteria matter here — throughput headroom, resource headroom (mass/power/volume), cost headroom, automation, crew headroom, availability, and fault retention (card 03's number). Each variant is scored 0 to 1 on each one, best gets a 1, worst gets a 0.
- Four named stakeholder viewpoints are scored separately — Balanced, ThroughputFirst, CostLean, MissionAssurance — because how much a criterion matters is a matter of opinion, and different stakeholders have different opinions.
- To check whether the answer depends on picking the "right" stakeholder, the analysis also draws 5,000 random weightings and asks: who wins across nearly every plausible way of caring about these seven things? The randomness is seeded, so anyone can rerun it and get the identical 5,000 draws.
- **Every** variant is scored, including the two that failed the gate in card 04, and each carries its verdict. The chain also writes a second, compliant-only rerun into `analysis/results/*_compliant.*` for the selection decision. Scores are relative — best-of-the-set gets a 1 — so the two sets are not directly comparable, and the canonical all-candidate numbers are the ones below.

## What we found

| Scenario | EverSimmer | LeanBroth *(fails gate)* | HyperCook *(fails gate)* |
|---|---|---|---|
| Balanced | **0.69** | 0.35 | 0.35 |
| ThroughputFirst | **0.60** | 0.30 | 0.47 |
| CostLean | 0.53 | **0.61** | 0.20 |
| MissionAssurance | **0.82** | 0.31 | 0.25 |

EverSimmer wins three of the four named scenarios and **85.5%** of the 5,000 random weightings. LeanBroth takes CostLean — it really is the cheaper, lighter design, and it really cannot meet the throughput floor. Both halves of that are true at once, which is why it stays in the table.

(In the compliant-only rerun, where EverSimmer is the sole qualifying variant, selection is forced rather than scored.)

![Scenario scores](../figures/scenario_scores.png)
![Monte Carlo win share](../figures/mc_winshare.png)

## Why it matters

Winning a few hand-picked scenarios could just mean the committee happened to ask the right questions. Winning 85.5% of 5,000 random ones means EverSimmer is the answer almost regardless of which stakeholder is in the room — that is the difference between "the committee liked it" and "it holds up under scrutiny."

The share it loses is informative rather than embarrassing: it sits in weightings that care most about cost and resource margin, where LeanBroth genuinely is the better design. If the throughput floor were ever renegotiated, the recommendation would deserve a fresh look — a conversation the team can only have if the losing variants are still on the chart.

Full detail: [05_trade_study_methodology.md](../05_trade_study_methodology.md), [06_trade_study_results.md](../06_trade_study_results.md), [10_behavioral_trade_update.md](../10_behavioral_trade_update.md)
