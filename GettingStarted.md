# Start Here: Intergalactic Vegan Soup Factory

This is a lightweight table of contents for the repo. It is an orientation document, not a walkthrough of results.

Before doing anything else, open `IntergalacticVeganSoupFactory.prj` in MATLAB so project paths and metadata are loaded.

## Project Root

Main entry point:

- `IntergalacticVeganSoupFactory.prj`

Top-level folders:

| Folder | What it contains |
| --- | --- |
| `requirements/` | Requirements Toolbox sets and imported requirement sources |
| `architecture/` | System Composer models, interface dictionaries, stereotype profile, and compliance gate |
| `behavior/` | Reusable Simulink, Stateflow, and Simscape behavioral components and data |
| `analysis/` | Pipeline scripts, sweeps, reporting scripts, utilities, and generated results |
| `tests/` | MATLAB analysis tests and Simulink Test assets |
| `docs/` | Explanatory documentation, generated figures, and review deliverables |

## Requirements

Primary requirement artifacts:

| Artifact | Path |
| --- | --- |
| Stakeholder needs | `requirements/StakeholderNeeds.slreqx` |
| System requirements | `requirements/SystemRequirements.slreqx` |

Read first:

- [`docs/01_requirements_analysis.md`](docs/01_requirements_analysis.md)

## Architecture Models

The repo is organized as an RFLP stack plus a generated gate model.

| Layer | Main model | Notes |
| --- | --- | --- |
| Functional | `architecture/functional/GalacticSoupFunctional.slx` | Functional decomposition of the system |
| Logical | `architecture/logical/GalacticSoupLogical.slx` | Logical organization and typed interfaces |
| Physical A | `architecture/physical/HyperCook/PhysicalHyperCook.slx` | HyperCook variant |
| Physical B | `architecture/physical/LeanBroth/PhysicalLeanBroth.slx` | LeanBroth variant |
| Physical C | `architecture/physical/EverSimmer/PhysicalEverSimmer.slx` | EverSimmer variant |
| Compliance gate | `architecture/gate/GalacticSoupComplianceGate.slx` | Generated executable gate over key quantitative requirements |

## Stereotypes, Interfaces, and Dictionaries

If you are looking for property definitions, typed interfaces, or parameter dictionaries, start here.

| Artifact | Path |
| --- | --- |
| Stereotype profile | `architecture/GalacticSoupProfile.xml` |
| Functional interfaces | `architecture/functional/FunctionalInterfaces.sldd` |
| Logical interfaces | `architecture/logical/LogicalInterfaces.sldd` |
| Shared physical interfaces | `architecture/physical/PhysicalInterfaces.sldd` |
| HyperCook wrapper dictionary | `architecture/physical/HyperCook/PhysicalHyperCookData.sldd` |
| LeanBroth wrapper dictionary | `architecture/physical/LeanBroth/PhysicalLeanBrothData.sldd` |
| EverSimmer wrapper dictionary | `architecture/physical/EverSimmer/PhysicalEverSimmerData.sldd` |

## Behavioral Content

The physical architectures use shared behavioral building blocks from `behavior/`.

| Area | Path |
| --- | --- |
| Behavioral component library | `behavior/components/` |
| Subsystem references | `behavior/subsystems/` |
| Shared behavior interfaces | `behavior/data/BehaviorInterfaces.sldd` |
| Common parameters | `behavior/data/BehParamsCommon.sldd` |
| Per-variant parameter dictionaries | `behavior/data/BehParamsHyperCook.sldd`, `behavior/data/BehParamsLeanBroth.sldd`, `behavior/data/BehParamsEverSimmer.sldd` |

Read next:

- [`docs/09_behavioral_models.md`](docs/09_behavioral_models.md)
- [`docs/10_behavioral_trade_update.md`](docs/10_behavioral_trade_update.md)

## Analysis Entry Points

The main analysis scripts live in `analysis/pipeline/`.

| Script | Purpose |
| --- | --- |
| `analysis/pipeline/runFullAnalysis.m` | Run the end-to-end analysis chain |
| `analysis/pipeline/runBehavioralAnalysis.m` | Regenerate behavioral simulation metrics |
| `analysis/pipeline/runVariantAnalysis.m` | Roll up per-variant metrics |
| `analysis/pipeline/runComplianceGate.m` | Run the formal compliance gate |
| `analysis/pipeline/runTradeStudy.m` | Generate trade-study outputs and figures |
| `analysis/pipeline/buildComplianceGate.m` | Rebuild the generated gate model |

## Analysis Subfolders

| Folder | Purpose |
| --- | --- |
| `analysis/utils/` | Shared `gs*` helper functions |
| `analysis/sweeps/` | Focused studies such as gravity, contamination, transport, turnaround, endurance, recipes, and uncertainty |
| `analysis/reporting/` | Report, deck, schematic, and trace-matrix generation |
| `analysis/results/` | Generated `.csv` and `.mat` outputs |

## Generated Results

Common outputs people usually look for first:

| Artifact | Path |
| --- | --- |
| Rolled-up variant metrics | `analysis/results/variantMetrics.csv` |
| Formal gate results | `analysis/results/complianceGate.csv` |
| Trade-study scenario scores | `analysis/results/tradeScores.csv` |
| Monte Carlo win share | `analysis/results/mcWinShare.csv` |
| Behavioral metrics | `analysis/results/behavioralMetrics.csv` |
| Uncertainty summary | `analysis/results/uncertaintySummary.csv` |
| Compliant-only rerun artifacts | `analysis/results/*_compliant.*` |

## Tests

| Entry point | Path |
| --- | --- |
| Run the whole suite | `tests/runAllTests.m` |
| MATLAB analysis tests | `tests/analysis/` |
| Simulink Test assets | `tests/system/` |
| Harness and test generators | `tests/system/buildSystemTestFile.m`, `tests/system/buildTestHarnesses.m` |

Read next:

- [`docs/11_test_organization.md`](docs/11_test_organization.md)
- [`docs/12_simulink_test_organization.md`](docs/12_simulink_test_organization.md)

## Documentation

Key docs:

| Topic | Path |
| --- | --- |
| Requirements analysis | `docs/01_requirements_analysis.md` |
| Functional architecture | `docs/02_functional_architecture.md` |
| Logical architecture | `docs/03_logical_architecture.md` |
| Physical variants | `docs/04_physical_variants.md` |
| Trade-study methodology | `docs/05_trade_study_methodology.md` |
| Trade-study results | `docs/06_trade_study_results.md` |
| Decision log | `docs/07_decision_log.md` |
| Formal compliance gate | `docs/08_formal_compliance_gate.md` |
| Behavioral models | `docs/09_behavioral_models.md` |
| Explainer cards | `docs/explainers/README.md` |

Generated review artifacts:

- `docs/figures/`
- `docs/deliverables/GalacticSoupRequirementsReport.pdf`
- `docs/deliverables/GalacticSoupTradeDeck.pptx`
- `docs/deliverables/variantRequirementsTraces.md`

## Suggested Paths Through the Repo

If you want to:

| Goal | Start here |
| --- | --- |
| Understand the requirements | `requirements/` and [`docs/01_requirements_analysis.md`](docs/01_requirements_analysis.md) |
| Browse the architecture stack | `architecture/functional/`, `architecture/logical/`, `architecture/physical/` |
| Find stereotype properties and interfaces | `architecture/GalacticSoupProfile.xml` and the `.sldd` files under `architecture/` |
| Understand the executable behavior | `behavior/` and [`docs/09_behavioral_models.md`](docs/09_behavioral_models.md) |
| Regenerate analysis outputs | `analysis/pipeline/runFullAnalysis.m` |
| Inspect generated outputs | `analysis/results/`, `docs/figures/`, `docs/deliverables/` |
| Verify the repo state | `tests/runAllTests.m` |
