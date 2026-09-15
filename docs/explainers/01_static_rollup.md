# The Paper Numbers

**The question this answers:** What does each architecture claim on its datasheet, before anything actually runs?

## How it works

- Every component in every variant — a cook line, a QC bench, a storage tank — carries the same 11 numbers: mass, power, cost, volume, throughput capacity, automation level, and a few others. Same scorecard for every part, so nothing gets left out.
- Numbers like mass, power, cost, and volume just add up. A part inside a part inside a part still adds to the total — nesting components into a group costs nothing extra in the math.
- Throughput does not add up the same way. A chain of stages only moves as fast as its slowest stage — think of a conveyor belt with one narrow spot. Parallel stages (four cook lines running side by side) do add, because losing none of them means all four contribute.
- Automation is an average across every component, not a sum — it describes how hands-off the system is, not a quantity you can pile up.
- The budget caps this analysis checks against (mass, power, cost, and so on) are read directly out of the requirement documents when the analysis runs, not typed in by hand. Change a requirement's number, and every future run picks it up automatically.

## What we found

| | HyperCook | LeanBroth | EverSimmer |
|---|---|---|---|
| Mass (kg) | 14,917.5 | 7,967.5 | 11,555.0 |
| Power, rated (kW) | 500.4 | 240.6 | 364.2 |
| Cost (kCr) | 2,097.2 | 1,148.0 | 1,985.4 |
| Volume (m³) | 418.2 | 254.1 | 313.1 |
| Throughput, rated (bph) | 320 | 210 | 240 |
| Automation | 0.955 | 0.838 | 0.960 |
| Operators | 3.8 | 4.9 | 2.7 |

![Budget utilization across variants](../figures/budget_utilization.png)

**HyperCook: 500.4 kW, 2097.2 kCr, 418.2 m^3.** Those totals breach the 500 kW power, 2,000 kCr cost, and 400 m^3 volume caps before anything runs. EverSimmer is close to its cost cap at 1,985.4 kCr, while LeanBroth retains comfortable resource margin.

## Why it matters

This pass is fast and touches every requirement, so it is the right first cut at whether a design is even in the ballpark — and it already exposes HyperCook's three resource violations. But it assumes soup flows through the factory with zero losses and nothing ever breaks. These are claims on a spec sheet, not evidence from a running plant. The next card puts that claim to the test.

Full detail: [05_trade_study_methodology.md](../05_trade_study_methodology.md)
