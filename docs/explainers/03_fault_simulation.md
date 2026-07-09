# Break Something on Purpose

**The question this answers:** What happens to production when the single worst component in the plant dies?

## How it works

- Every component has a built-in fault switch that can be flipped at a chosen moment — here, two hours into the run, once the plant has settled into steady output.
- For each variant, the "worst" fault is picked deliberately: whichever single component, if it failed, would hurt production the most. That is a design weak point, not a random pick.
- HyperCook's weak point is its QC scanner — there is only one, and every bowl has to pass through it. LeanBroth's is its one prep station. EverSimmer's is losing one entire production cell out of three.
- Retention is the simple before-and-after ratio: steady output right after the fault, divided by steady output right before it. 100% would mean the fault made no difference; 0% means production stopped entirely.
- The plant's supervisor software also reports its own status during the fault — Nominal, Degraded, or Halted — which is checked against what actually happened to output.

## What we found

| Variant | Retention after worst-case fault | Supervisor reports |
|---|---|---|
| HyperCook | 0% | Nominal (misses the collapse) |
| LeanBroth | 0% | Nominal (misses the collapse) |
| EverSimmer | 67% | Degraded (correctly flags it) |

![Worst-case fault response](../figures/behavioral_fault.png)

## Why it matters

HyperCook and LeanBroth each have one component that, if it breaks, takes down the entire plant — no redundancy to fall back on. EverSimmer's three independent cells mean losing one still leaves two-thirds of the soup flowing. This is the same resilience requirement (SR-GS-026) told as a time history instead of a checkbox, and it is the single number that most separates EverSimmer from the other two designs.

Full detail: [10_behavioral_trade_update.md](../10_behavioral_trade_update.md)
