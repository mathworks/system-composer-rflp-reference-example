# The Pass/Fail Line

**The question this answers:** Which variants can actually be built as specified?

## How it works

- There are eight hard requirements — mass, power, cost, volume, throughput, automation, crew size, gravity rating — and each one is a formal, executable check inside a Requirements Table model, not an informal spreadsheet formula.
- The simulated numbers from cards 02 and 03 (not the paper numbers from card 01) feed directly into these checks — real behavior decides pass or fail, not the datasheet.
- A variant that fails even one check is still scored in card 05, but carries its verdict with it. The chain writes two sets of trade results: the canonical one over all three candidates, and a compliant-only rerun alongside it. Scoring is relative — best-of-the-set gets a 1 — so quietly dropping a variant would rescale everyone else's numbers.
- A second, independently hand-coded check runs the same eight tests in parallel, as a cross-check. The two methods have to agree, or something is wrong with one of them.

## What we found

20 of 24 checks pass, and two of the three variants fail something.

| Variant | Result |
|---|---|
| HyperCook | Fails power (500.4 vs. 500 kW), cost (2097 vs. 2000 kCr) and volume (418 vs. 400 m³) |
| LeanBroth | Fails throughput (196.8 vs. 200 bph floor) |
| EverSimmer | Compliant |

LeanBroth's rated 210 bph looked safe on paper — the simulation says it is not, and a better QC bench (reject rate down to roughly 1.3%) would put it back over the line.

HyperCook's failures arrived later and from two directions: sizing its stores for the full 72-hour endurance requirement added rack hardware its thin cost and volume margins could not absorb, and the six bay status concentrators added 0.4 kW each to a variant already running at 498 of its 500 kW cap. It is the clearest illustration in the project of what a design with no margin left pays for every subsequent decision.

## Why it matters

A gate failure is not a dead end — each one here is a specific, well-understood problem with a specific fix. That is exactly why failing variants stay in the comparison: the team needs to see what a design is worth *and* what it would take to make it legal, and a variant deleted from the table tells them neither.

Full detail: [08_formal_compliance_gate.md](../08_formal_compliance_gate.md), [10_behavioral_trade_update.md](../10_behavioral_trade_update.md)
