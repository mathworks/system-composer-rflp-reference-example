# The Pass/Fail Line

**The question this answers:** Which variants actually qualify, and which ones carry a failure into the comparison?

## How it works

- There are eight hard requirements — mass, power, cost, volume, throughput, automation, crew size, gravity rating — and each one is a formal, executable check inside a Requirements Table model, not an informal spreadsheet formula.
- Where simulation has something to say, it overrules the datasheet: throughput and fault retention come from cards 02 and 03, not card 01. The rest — mass, power, cost, volume, automation, crew, gravity — are the rolled-up numbers from card 01, because no simulation changes what a component weighs or costs.
- A variant that fails even one check has not qualified, and its scores in card 05 have to be read with that failure attached — a non-compliant design is not simply a lower-ranked one.
- A second, independently hand-coded check runs the same eight tests in parallel, as a cross-check. The two methods have to agree, or something is wrong with one of them.

## What we found

21 of 24 checks pass. Three fail, and they are not all the same kind of problem:

| Variant | Result |
|---|---|
| HyperCook | Fails cost (2,061 vs. 2,000 kCr cap) and volume (417 vs. 400 m³ cap) |
| LeanBroth | Fails throughput (196.8 vs. 200 bph floor) |
| EverSimmer | Compliant on all eight |

**HyperCook's two failures were visible on paper** (card 01) — it was over budget on cost and volume before anything simulated. **LeanBroth's is the one simulation found**: its rated 210 bph looked safe, but real yield loss and calibration downtime pulled it under the floor. A better QC bench — cutting the reject rate to roughly 1.3% or lower — would put it back over the line.

## Why it matters

Neither failure is a dead end. LeanBroth's is a specific, well-understood problem with a specific fix, and HyperCook's is a budget question for the team rather than a physics one. That distinction matters: it tells the team exactly what to go improve rather than just scoring the design out of contention. Only EverSimmer walks into card 05 with nothing attached.

Full detail: [08_formal_compliance_gate.md](../08_formal_compliance_gate.md), [10_behavioral_trade_update.md](../10_behavioral_trade_update.md)
