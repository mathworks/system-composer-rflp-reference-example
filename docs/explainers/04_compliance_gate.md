# The Pass/Fail Line

**The question this answers:** Which variants are even allowed into the final comparison?

## How it works

- There are eight hard requirements — mass, power, cost, volume, throughput, automation, crew size, gravity rating — and each one is a formal, executable check inside a Requirements Table model, not an informal spreadsheet formula.
- The simulated numbers from cards 02 and 03 (not the paper numbers from card 01) feed directly into these checks — real behavior decides pass or fail, not the datasheet.
- A variant that fails even one check is dropped from the scoring round entirely. Comparing a non-compliant design against compliant ones on "which is best" would not mean anything — it first has to qualify.
- A second, independently hand-coded check runs the same eight tests in parallel, as a cross-check. The two methods have to agree, or something is wrong with one of them.

## What we found

23 of 24 checks pass. The one failure: **LeanBroth's throughput**, 196.8 bph against the 200 bph floor. Its rated 210 bph looked safe on paper — the simulation says it is not.

| Variant | Result |
|---|---|
| HyperCook | Compliant |
| LeanBroth | Fails throughput (196.8 vs. 200 bph floor) |
| EverSimmer | Compliant |

A better QC bench — cutting the reject rate to roughly 1.3% or lower — would put LeanBroth back over the line.

## Why it matters

A gate failure here is not a dead end for LeanBroth — it is a specific, well-understood problem with a specific fix. That distinction matters: it tells the team exactly what to go improve rather than just scoring the design out of contention.

Full detail: [08_formal_compliance_gate.md](../08_formal_compliance_gate.md), [10_behavioral_trade_update.md](../10_behavioral_trade_update.md)
