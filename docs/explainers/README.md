# Analysis Explainers

This folder has one plain-language card per analysis case in the trade-study chain — each one written for an engineer who is not a systems engineer and has about three minutes. They complement the deep methodology and results docs (05, 06, 08, 09, 10); they do not replace them. Read the cards in order below to follow the chain from raw datasheet numbers to a defensible pick.

| File | Question it answers | One-line result |
|---|---|---|
| [01_static_rollup.md](01_static_rollup.md) | What does each architecture claim on its datasheet? | All three architectures fit their budgets on paper — but paper assumes nothing ever goes wrong. |
| [02_nominal_simulation.md](02_nominal_simulation.md) | What does each architecture actually produce when the soup flows? | Every variant makes less soup than its datasheet promised, and LeanBroth loses the most. |
| [03_fault_simulation.md](03_fault_simulation.md) | What happens to production when the worst single component dies? | HyperCook and LeanBroth stop cold; EverSimmer keeps two-thirds of its output. |
| [04_compliance_gate.md](04_compliance_gate.md) | Which variants can actually be built as specified? | Only EverSimmer clears all eight gates — but failing variants stay in the comparison. |
| [05_trade_scoring.md](05_trade_scoring.md) | Which one should we build, and how do the others compare? | EverSimmer wins three of four scenarios and 85.5% of random weightings; LeanBroth takes CostLean. |
