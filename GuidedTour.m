%[text] # Guided Tour
%[text] This is a link-first orientation script for exploring the repo from MATLAB. It is intentionally lightweight: mostly headings, short explanations, and clickable links that open models, files, folders, and artifacts.
%[text] **Start here:** [`Open the MATLAB project`](matlab:openProject('IntergalacticVeganSoupFactory.prj'))
%%
%[text] ## 1. Core entry points
%[text] Open the main project and the repo overview:
%[text] - [`IntergalacticVeganSoupFactory.prj`](matlab:openProject('IntergalacticVeganSoupFactory.prj'))
%[text] - [`README.md`](matlab:open('README.md'))
%[text] - [`GettingStarted.md`](matlab:open('GettingStarted.md'))
%%
%[text] ## 2. Requirements
%[text] Open the main requirements artifacts:
%[text] - [`requirements/StakeholderNeeds.slreqx`](matlab:open('requirements/StakeholderNeeds.slreqx'))
%[text] - [`requirements/SystemRequirements.slreqx`](matlab:open('requirements/SystemRequirements.slreqx'))
%[text]
%[text] Read the requirements write-up:
%[text] - [`docs/01_requirements_analysis.md`](matlab:open('docs/01_requirements_analysis.md'))
%%
%[text] ## 3. Architecture stack
%[text] Functional and logical layers:
%[text] - [`GalacticSoupFunctional`](matlab:open_system('GalacticSoupFunctional'))
%[text] - [`GalacticSoupLogical`](matlab:open_system('GalacticSoupLogical'))
%[text] - [`docs/02_functional_architecture.md`](matlab:open('docs/02_functional_architecture.md'))
%[text] - [`docs/03_logical_architecture.md`](matlab:open('docs/03_logical_architecture.md'))
%[text]
%[text] Physical variants:
%[text] - [`PhysicalHyperCook`](matlab:open_system('PhysicalHyperCook'))
%[text] - [`PhysicalLeanBroth`](matlab:open_system('PhysicalLeanBroth'))
%[text] - [`PhysicalEverSimmer`](matlab:open_system('PhysicalEverSimmer'))
%[text] - [`docs/04_physical_variants.md`](matlab:open('docs/04_physical_variants.md'))
%[text]
%[text] Generated compliance-gate model:
%[text] - [`GalacticSoupComplianceGate`](matlab:open_system('GalacticSoupComplianceGate'))
%[text] - [`docs/08_formal_compliance_gate.md`](matlab:open('docs/08_formal_compliance_gate.md'))
%%
%[text] ## 4. Stereotypes, interfaces, and dictionaries
%[text] Open the stereotype profile and the main interface dictionaries:
%[text] - [`architecture/GalacticSoupProfile.xml`](matlab:open('architecture/GalacticSoupProfile.xml'))
%[text] - [`architecture/functional/FunctionalInterfaces.sldd`](matlab:open('architecture/functional/FunctionalInterfaces.sldd'))
%[text] - [`architecture/logical/LogicalInterfaces.sldd`](matlab:open('architecture/logical/LogicalInterfaces.sldd'))
%[text] - [`architecture/physical/PhysicalInterfaces.sldd`](matlab:open('architecture/physical/PhysicalInterfaces.sldd'))
%[text]
%[text] Per-variant wrapper dictionaries:
%[text] - [`PhysicalHyperCookData.sldd`](matlab:open('architecture/physical/HyperCook/PhysicalHyperCookData.sldd'))
%[text] - [`PhysicalLeanBrothData.sldd`](matlab:open('architecture/physical/LeanBroth/PhysicalLeanBrothData.sldd'))
%[text] - [`PhysicalEverSimmerData.sldd`](matlab:open('architecture/physical/EverSimmer/PhysicalEverSimmerData.sldd'))
%%
%[text] ## 5. Behavioral content
%[text] Open the shared behavioral assets:
%[text] - [`behavior/components/`](matlab:winopen('behavior\components'))
%[text] - [`behavior/subsystems/`](matlab:winopen('behavior\subsystems'))
%[text] - [`behavior/data/`](matlab:winopen('behavior\data'))
%[text] - [`docs/09_behavioral_models.md`](matlab:open('docs/09_behavioral_models.md'))
%[text] - [`docs/10_behavioral_trade_update.md`](matlab:open('docs/10_behavioral_trade_update.md'))
%%
%[text] ## 6. Analysis scripts
%[text] Main pipeline entry points:
%[text] - [`analysis/pipeline/runFullAnalysis.m`](matlab:open('analysis/pipeline/runFullAnalysis.m'))
%[text] - [`analysis/pipeline/runBehavioralAnalysis.m`](matlab:open('analysis/pipeline/runBehavioralAnalysis.m'))
%[text] - [`analysis/pipeline/runVariantAnalysis.m`](matlab:open('analysis/pipeline/runVariantAnalysis.m'))
%[text] - [`analysis/pipeline/runComplianceGate.m`](matlab:open('analysis/pipeline/runComplianceGate.m'))
%[text] - [`analysis/pipeline/runTradeStudy.m`](matlab:open('analysis/pipeline/runTradeStudy.m'))
%[text] - [`analysis/pipeline/buildComplianceGate.m`](matlab:open('analysis/pipeline/buildComplianceGate.m'))
%[text]
%[text] Supporting folders:
%[text] - [`analysis/utils/`](matlab:winopen('analysis\utils'))
%[text] - [`analysis/sweeps/`](matlab:winopen('analysis\sweeps'))
%[text] - [`analysis/reporting/`](matlab:winopen('analysis\reporting'))
%%
%[text] ## 7. Results and figures
%[text] Open the generated outputs:
%[text] - [`analysis/results/`](matlab:winopen('analysis\results'))
%[text] - [`docs/figures/`](matlab:winopen('docs\figures'))
%[text] - [`docs/deliverables/`](matlab:winopen('docs\deliverables'))
%[text]
%[text] Common files people inspect:
%[text] - [`analysis/results/variantMetrics.csv`](matlab:open('analysis/results/variantMetrics.csv'))
%[text] - [`analysis/results/complianceGate.csv`](matlab:open('analysis/results/complianceGate.csv'))
%[text] - [`analysis/results/tradeScores.csv`](matlab:open('analysis/results/tradeScores.csv'))
%[text] - [`analysis/results/mcWinShare.csv`](matlab:open('analysis/results/mcWinShare.csv'))
%[text] - [`docs/deliverables/variantRequirementsTraces.md`](matlab:open('docs/deliverables/variantRequirementsTraces.md'))
%%
%[text] ## 8. Tests
%[text] Verification entry points:
%[text] - [`tests/runAllTests.m`](matlab:open('tests/runAllTests.m'))
%[text] - [`tests/analysis/`](matlab:winopen('tests\analysis'))
%[text] - [`tests/system/`](matlab:winopen('tests\system'))
%[text] - [`docs/11_test_organization.md`](matlab:open('docs/11_test_organization.md'))
%[text] - [`docs/12_simulink_test_organization.md`](matlab:open('docs/12_simulink_test_organization.md'))
%%
%[text] ## 9. Decision log and method docs
%[text] If you are trying to understand why the repo looks the way it does:
%[text] - [`docs/05_trade_study_methodology.md`](matlab:open('docs/05_trade_study_methodology.md'))
%[text] - [`docs/06_trade_study_results.md`](matlab:open('docs/06_trade_study_results.md'))
%[text] - [`docs/07_decision_log.md`](matlab:open('docs/07_decision_log.md'))
%[text] - [`docs/explainers/README.md`](matlab:open('docs/explainers/README.md'))
%%
%[text] ## 10. Suggested routes
%[text] Start from the links above based on what you need:
%[text] - To inspect **requirements**, open the `.slreqx` files and `docs/01_requirements_analysis.md`.
%[text] - To inspect **architecture**, open the functional, logical, and physical models.
%[text] - To inspect **definitions**, open `GalacticSoupProfile.xml` and the `.sldd` files.
%[text] - To inspect **analysis flow**, open the scripts under `analysis/pipeline/`.
%[text] - To inspect **outputs**, open `analysis/results/`, `docs/figures/`, and `docs/deliverables/`.
%[text] - To inspect **verification**, open `tests/runAllTests.m`, `tests/analysis/`, and `tests/system/`.

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
