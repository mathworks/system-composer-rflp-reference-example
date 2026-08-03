%[text] # Start here: Intergalactic Vegan Soup Factory
%[text] A guided, five-minute tour of this project. It reads the artifacts that are already committed under `analysis/results/` and `docs/`, so nothing here simulates, sweeps, or rebuilds anything — run it top to bottom and it finishes in seconds.
%[text] **Before you run this:** open the MATLAB project `IntergalacticVeganSoupFactory.prj` so the paths and artifact context are loaded.
%[text] The story in one sentence: three competing physical architectures for a space-based soup factory are pushed through requirements traceability, budget roll-up, executable behavior, a formal compliance gate, and a weighted trade study — and they fail in different places.
%%
%[text] ## 1. Where you are
%[text] This is an **RFLP** project: Requirements, Functional, Logical, Physical, each layer a real System Composer&trade; model that traces to the one above it.
proj = currentProject;
root = proj.RootFolder
%[text] The folders you will actually care about, in the order the work flows through them:
layout = table( ...
    ["Stakeholder needs and system requirements (.slreqx), imported from spreadsheets"; ...
     "The RFLP model stack: functional, logical, three physical variants, and the generated compliance gate"; ...
     "Reusable Simulink/Stateflow/Simscape components that give the physical variants executable dynamics"; ...
     "Roll-up, compliance gate, trade study, sweeps, reporting, and every generated result"; ...
     "The verification suite: MATLAB analysis tiers plus the Simulink Test system tier"; ...
     "Systems-engineering write-ups, decision log, figures, explainer cards, and generated deliverables"], ...
    RowNames = ["requirements"; "architecture"; "behavior"; "analysis"; "tests"; "docs"], ...
    VariableNames = "Contents")
%%
%[text] ## 2. The three candidates
%[text] Each physical variant realizes the same logical architecture with a different design philosophy:
%[text] - **HyperCook** — throughput first. Continuous line, highest raw rate, razor-thin budget margins. \
%[text] - **LeanBroth** — budget first. Smallest, cheapest, least power, fewest components. \
%[text] - **EverSimmer** — resilience first. Three independent production cells, so one failure is not the end of production. \
%[text] Here is EverSimmer, the resilience-first candidate, as a generated schematic:
schematic = imread(fullfile(root, "docs", "figures", "variant_schematic_eversimmer.png"));
image(schematic)
axis image off
%[text] The other two are [`variant_schematic_hypercook.png`](matlab:open docs/figures/variant_schematic_hypercook.png) and [`variant_schematic_leanbroth.png`](matlab:open docs/figures/variant_schematic_leanbroth.png), and the models themselves open with [`open_system PhysicalEverSimmer`](matlab:open_system PhysicalEverSimmer), [`open_system PhysicalHyperCook`](matlab:open_system PhysicalHyperCook), or [`open_system PhysicalLeanBroth`](matlab:open_system PhysicalLeanBroth).
%%
%[text] ## 3. What each architecture costs you
%[text] Every component carries the same stereotype properties, and `analysis/pipeline/runVariantAnalysis` rolls them bottom-up through the hierarchy. `N1Retention` is the fraction of production surviving the worst single component failure.
metrics = readtable(fullfile(root, "analysis", "results", "variantMetrics.csv"), ...
    ReadRowNames = true);
variants = string(metrics.Properties.RowNames);
summaryTable = table(metrics.Mass_kg, metrics.Power_kW, metrics.Cost_kCredits, ...
    metrics.Volume_m3, metrics.Throughput_bph, metrics.N1Retention, ...
    RowNames = metrics.Properties.RowNames, ...
    VariableNames = ["Mass_kg", "Power_kW", "Cost_kCredits", "Volume_m3", ...
                     "Throughput_bph", "N1Retention"])
%[text] Note the last column: HyperCook and LeanBroth both drop to essentially zero output after a single fault, because each runs one production string. EverSimmer keeps two thirds.
%%
%[text] ## 4. The number that changes the argument
%[text] The datasheet throughput is bottleneck math on rated component values. The simulated throughput comes from actually running the behavior — rate-limited flow, batch kettle thermal dynamics, QC rejects and recalibration downtime. The gap between them is where a trade study earns its keep.
theme = gsPlotTheme;
variantColors = cell2mat(cellfun(@(v) theme.palette(v), metrics.Properties.RowNames, ...
    UniformOutput = false));
% The SR-GS-002 floor is recovered from the margins rather than hardcoded, so
% this chart stays correct if the requirement text changes.
throughputFloor = round(mean(metrics.Throughput_bph ./ (1 + metrics.Margin_Throughput)));
bars = bar([metrics.Static_Throughput_bph, metrics.Throughput_bph]);
bars(1).FaceColor = "flat";
bars(1).CData = repmat(theme.muted, numel(variants), 1);
bars(1).EdgeColor = theme.surface;
bars(2).FaceColor = "flat";
bars(2).CData = variantColors;
bars(2).EdgeColor = theme.surface;
yline(throughputFloor, Color = theme.limit, LineWidth = 1.5);
title("Rated vs. simulated throughput")
subtitle("Red line: SR-GS-002 throughput floor, " + throughputFloor + " bowls/h")
ylabel("Bowls per hour")
xticklabels(variants)
legendHandle = legend(["Rated (datasheet roll-up)", "Simulated (executable behavior)"], ...
    Location = "southoutside", Orientation = "horizontal");
legendHandle.TextColor = theme.inkS;
legendHandle.Color = theme.surface;
legendHandle.EdgeColor = theme.axisC;
ax = gca;
styleAxes(ax, theme, "y")
ax.Subtitle.Color = theme.limit;   % the subtitle is what names the red limit line
%[text] LeanBroth is rated above the floor and simulates below it. That single fact eliminates it from the compliance gate in the next section.
%%
%[text] ## 5. The pass/fail line
%[text] Eight quantitative system requirements are formalized as executable rows in a generated Requirements Table model (`architecture/gate/GalacticSoupComplianceGate.slx`). Simulated metrics feed the gate, and a parallel hand-coded check has to agree with it or the pipeline hard-errors.
gate = readtable(fullfile(root, "analysis", "results", "complianceGate.csv"), ...
    ReadRowNames = true);
gateVerdicts = repmat("PASS", height(gate), width(gate));
gateVerdicts(gate{:,:} == 0) = "FAIL";
gateTable = array2table(gateVerdicts, RowNames = gate.Properties.RowNames, ...
    VariableNames = gate.Properties.VariableNames)
%[text] Failing a gate excludes a variant from scoring rather than ranking it lower — an eliminated variant is a finding with a recovery path, not a loser. See [`docs/08_formal_compliance_gate.md`](matlab:open docs/08_formal_compliance_gate.md).
%%
%[text] ## 6. Picking a winner you can defend
%[text] The multi-criteria decision analysis scores the variants under four stakeholder weighting scenarios, then re-runs the scoring across thousands of randomized weightings to see how sensitive the answer is to the weights you chose.
trade = readtable(fullfile(root, "analysis", "results", "tradeScores.csv"), ...
    ReadRowNames = true);
tradeColors = cell2mat(cellfun(@(v) theme.palette(v), trade.Properties.RowNames, ...
    UniformOutput = false));
scenarioBars = bar(trade{:,:}');
for k = 1:numel(scenarioBars)
    scenarioBars(k).FaceColor = tradeColors(k,:);
    scenarioBars(k).EdgeColor = theme.surface;
end
title("MCDA score by stakeholder scenario")
ylabel("Weighted score")
xticklabels(trade.Properties.VariableNames)
legendHandle = legend(trade.Properties.RowNames, Location = "southoutside", ...
    Orientation = "horizontal");
legendHandle.TextColor = theme.inkS;
legendHandle.Color = theme.surface;
legendHandle.EdgeColor = theme.axisC;
styleAxes(gca, theme, "y")
%[text] EverSimmer takes three of the four scenarios; LeanBroth takes CostLean, but it is the variant that failed the throughput gate above, so that win comes with an asterisk.
%[text] Now the weight-sensitivity sweep — the share of randomized weightings each variant wins:
winShare = readtable(fullfile(root, "analysis", "results", "mcWinShare.csv"), ...
    ReadRowNames = true);
shareBars = barh(100 * winShare.WinShare);
shareBars.FaceColor = "flat";
shareBars.CData = cell2mat(cellfun(@(v) theme.palette(v), winShare.Properties.RowNames, ...
    UniformOutput = false));
shareBars.EdgeColor = theme.surface;
title("Monte Carlo weight-sensitivity: share of weightings won")
xlabel("Percent of randomized weightings")
yticklabels(winShare.Properties.RowNames)
styleAxes(gca, theme, "x")
%%
%[text] ## 7. What is actually proven, per candidate
%[text] Requirements Toolbox&trade; rolls verification status up over all loaded link sets and cannot scope to a single candidate, so per-variant status is computed by link attribution instead (ADR-035). No variant is committed as the baseline in the artifacts — all three keep their `Implement` links and their own test evidence, so each compliance story reads on its own terms.
traces = readtable(fullfile(root, "docs", "deliverables", "variantRequirementsTraces.csv"), ...
    TextType = "string");
[groupIndex, tracedVariants] = findgroups(traces.Variant);
nVerified = splitapply(@(v) sum(v == "verified"), traces.Verdict, groupIndex);
nFailing = splitapply(@(v) sum(v == "FAILS"), traces.Verdict, groupIndex);
evidence = table(nVerified, nFailing, RowNames = cellstr(tracedVariants), ...
    VariableNames = ["VerifiedBySimulation", "KnownFailures"])
%[text] The side-by-side design-review evidence lives in [`docs/deliverables/variantRequirementsTraces.md`](matlab:open docs/deliverables/variantRequirementsTraces.md).
%%
%[text] ## 8. Where to go next
%[text] Read, in roughly this order:
%[text] - [`docs/explainers/`](matlab:open docs/explainers/README.md) — five plain-language cards, one per analysis case, about three minutes each. \
%[text] - [`docs/01_requirements_analysis.md`](matlab:open docs/01_requirements_analysis.md) through `docs/04_physical_variants.md` — how the RFLP layers were built. \
%[text] - [`docs/05_trade_study_methodology.md`](matlab:open docs/05_trade_study_methodology.md) and [`docs/06_trade_study_results.md`](matlab:open docs/06_trade_study_results.md) — the method and the full results, including threats to validity. \
%[text] - [`docs/07_decision_log.md`](matlab:open docs/07_decision_log.md) — every architectural decision and why it was made. \
%[text] Run, when you want to prove the numbers rather than read them:
%[text] - `runFullAnalysis` — regenerates the whole chain: behavioral simulation, roll-up, compliance gate, trade study. Takes minutes, not seconds. \
%[text] - `tests/runAllTests` — verifies the regenerated results and refreshes requirements verification status. \
%[text] Everything shown above came from files those two commands produce, so if a number here ever looks stale, regenerate and re-run this script.

function styleAxes(ax, theme, gridAxis)
%STYLEAXES Apply the house dark theme (gsPlotTheme) to one axes.
%   GRIDAXIS is "x" or "y" - the value axis of the chart, so the gridlines
%   help read magnitudes instead of separating categories.
ax.Color = theme.surface;
ax.XColor = theme.muted;
ax.YColor = theme.muted;
ax.GridColor = theme.grid;
ax.Title.Color = theme.inkP;
ax.Subtitle.Color = theme.inkS;
ax.Box = "off";
ax.Parent.Color = theme.surface;
if gridAxis == "x"
    ax.XGrid = "on";
else
    ax.YGrid = "on";
end
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
