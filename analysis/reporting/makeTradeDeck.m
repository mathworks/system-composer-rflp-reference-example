function makeTradeDeck()
%MAKETRADEDECK Generate the trade-study briefing deck (PowerPoint).
%   One slide per explainer card (docs/explainers/), plus a title slide,
%   one schematic slide per variant, and a closing selection slide. Built
%   with MATLAB Report Generator so the deck regenerates from the repo:
%   figures come from docs/figures, and quantitative claims are formatted
%   directly from the canonical CSVs in analysis/results.
%   Output: docs/deliverables/GalacticSoupTradeDeck.pptx.

import mlreportgen.ppt.*
proj = currentProject;
figDir = char(fullfile(proj.RootFolder, 'docs', 'figures'));
resDir = fullfile(proj.RootFolder, 'analysis', 'results');
outFile = char(fullfile(proj.RootFolder, 'docs', 'deliverables', 'GalacticSoupTradeDeck.pptx'));
if isfile(outFile), delete(outFile); end

metrics = readtable(fullfile(resDir, 'variantMetrics.csv'), 'ReadRowNames', true);
beh = readtable(fullfile(resDir, 'behavioralMetrics.csv'), 'ReadRowNames', true);
gate = readtable(fullfile(resDir, 'complianceGate.csv'), 'ReadRowNames', true);
trade = readtable(fullfile(resDir, 'tradeScores.csv'), 'ReadRowNames', true);
mc = readtable(fullfile(resDir, 'mcWinShare.csv'), 'ReadRowNames', true);
variantOrder = {'HyperCook','LeanBroth','EverSimmer'};

gateNames = gate.Properties.VariableNames(1:end-1);
gateCells = logical(gate{:,1:end-1});
nGatePass = nnz(gateCells);
nGateTotal = numel(gateCells);
rowOf = @(variant) find(strcmp(gate.Properties.RowNames, variant), 1);
failedGates = @(variant) gateNames(~gateCells(rowOf(variant),:));
lowerList = @(items) cellfun(@lower, items, 'UniformOutput', false);

isBudgetGate = ismember(gateNames, {'Mass','Power','Cost','Volume'});
budgetNames = gateNames(isBudgetGate);
overCap = cell(numel(variantOrder), 1);
nOverCap = 0;
for k = 1:numel(variantOrder)
    failedBudgets = budgetNames(~gateCells(rowOf(variantOrder{k}),isBudgetGate));
    if ~isempty(failedBudgets)
        nOverCap = nOverCap + 1;
        overCap{nOverCap} = sprintf('%s is over %s before anything runs', ...
            variantOrder{k}, joinList(lowerList(failedBudgets)));
    end
end
overCap = overCap(1:nOverCap);
if nOverCap == 0
    overCap = {'All three candidates fit every resource budget on paper'};
end

scenarioNames = trade.Properties.VariableNames;
[~,winnerIndex] = max(trade{:,:}, [], 1);
scenarioWinners = trade.Properties.RowNames(winnerIndex);
mcPercent = 100 * mc{variantOrder,'WinShare'};
[leaderShare,leaderIndex] = max(mcPercent);
leader = variantOrder{leaderIndex};
nLeaderScenarios = nnz(strcmp(scenarioWinners, leader));
throughputFloor = metrics{'LeanBroth','Throughput_bph'} / ...
    (1 + metrics{'LeanBroth','Margin_Throughput'});

p = Presentation(outFile);
open(p);

% --- 1: title ---
s = add(p, 'Title Slide');
replace(s, 'Title', 'Intergalactic Vegan Soup Factory');
replace(s, 'Subtitle', ['Architecture trade study at behavioral fidelity' newline ...
    'Three candidates scored side by side - every number reproducible with runFullAnalysis']);

% --- 2-4: the contenders (schematics carry their own stats captions) ---
variants = { ...
 'HyperCook - throughput first',  'variant_schematic_hypercook.png'; ...
 'LeanBroth - budget first',      'variant_schematic_leanbroth.png'; ...
 'EverSimmer - resilience first', 'variant_schematic_eversimmer.png'};
for i = 1:3
    s = add(p, 'Title and Content');
    replace(s, 'Title', variants{i,1});
    pic = Picture(fullfile(figDir, variants{i,2}));
    pic.Width = '11in'; pic.Height = '3.7in';
    replace(s, 'Content', pic);
end

% --- 5: static roll-up ---
s = add(p, 'Two Content');
replace(s, 'Title', '1. The paper numbers (static roll-up)');
replace(s, 'Left Content', [{ ...
 'Every component carries the same 11-property stereotype'; ...
 'Mass, power, cost, volume sum bottom-up through the hierarchy'; ...
 'Throughput is bottleneck math: a chain runs at its slowest stage'; ...
 'Budget caps are parsed from the requirement text at run time'; ...
 sprintf('HyperCook: %.1f kW, %.1f kCr, %.1f m^3', ...
    metrics{'HyperCook','Power_kW'}, metrics{'HyperCook','Cost_kCredits'}, ...
    metrics{'HyperCook','Volume_m3'})}; ...
 overCap(:); ...
 {'Claims, not evidence: assumes lossless flow'}]);
pic = Picture(fullfile(figDir, 'budget_utilization.png'));
pic.Width = '5.6in'; pic.Height = '2.75in';
replace(s, 'Right Content', pic);

% --- 6: nominal simulation ---
s = add(p, 'Two Content');
replace(s, 'Title', '2. Run the factory (nominal simulation)');
replace(s, 'Left Content', { ...
 'Behaviors live inside the architecture models themselves'; ...
 'Batch kettles heat up physically; QC rejects a few percent and recalibrates'; ...
 ['Simulated vs rated: ' strjoin(compose('%.0f vs %.0f', ...
    metrics{variantOrder,'Throughput_bph'}, ...
    metrics{variantOrder,'Static_Throughput_bph'})', ', ') ' bph']; ...
 sprintf('First bowl: %.0f s continuous vs ~%.0f min batch cold start', ...
    metrics{'HyperCook','TimeToFirstOut_s'}, ...
    max(metrics{{'LeanBroth','EverSimmer'},'TimeToFirstOut_s'})/60); ...
 'LeanBroth''s margin is gone before the trade study even starts'});
pic = Picture(fullfile(figDir, 'behavioral_throughput.png'));
pic.Width = '5.6in'; pic.Height = '2.5in';
replace(s, 'Right Content', pic);

% --- 7: fault simulation ---
s = add(p, 'Two Content');
replace(s, 'Title', '3. Break something on purpose (worst-case fault)');
replace(s, 'Left Content', Table([{'Variant','Worst single fault','Retention'}; ...
    [variantOrder(:), beh{variantOrder,'WorstFault'}, ...
     compose('%.0f%%', 100*metrics{variantOrder,'N1Retention'})]]));
pic = Picture(fullfile(figDir, 'behavioral_fault.png'));
pic.Width = '5.6in'; pic.Height = '2.5in';
replace(s, 'Right Content', pic);

% --- 8: compliance gate ---
s = add(p, 'Two Content');
replace(s, 'Title', '4. The pass/fail line (formal compliance gate)');
replace(s, 'Left Content', { ...
 sprintf('%d quantitative requirements as executable Requirements Table rows', numel(gateNames)); ...
 'Canonical roll-up and simulation metrics feed the gate'; ...
 'A parallel hand-coded check must agree with every formal verdict'; ...
 'A failed gate stays visible when all three candidates are scored'});
gateRows = cell(numel(variantOrder), 2);
for k = 1:numel(variantOrder)
    failures = failedGates(variantOrder{k});
    if isempty(failures)
        gateRows(k,:) = {variantOrder{k}, ...
            sprintf('compliant on all %d', numel(gateNames))};
    else
        gateRows(k,:) = {variantOrder{k}, ...
            ['fails ' joinList(lowerList(failures))]};
    end
end
replace(s, 'Right Content', Table([ ...
    {'Variant','Formal gate result'}; ...
    gateRows; ...
    {'Checks passing', sprintf('%d of %d', nGatePass, nGateTotal)}; ...
    {'Recovery', sprintf('QC reject <= ~1.3%% clears the %.0f bph floor', ...
        throughputFloor)}]));

% --- 9: trade scoring ---
s = add(p, 'Two Content');
replace(s, 'Title', '5. Pick a winner you can defend (MCDA + Monte Carlo)');
replace(s, 'Left Content', Table([ ...
    ['Scenario', variantOrder, {'Winner'}]; ...
    [scenarioNames(:), compose('%.2f', trade{variantOrder,:}'), ...
     scenarioWinners(:)]]));
pic = Picture(fullfile(figDir, 'mc_winshare.png'));
pic.Width = '5.6in'; pic.Height = '2.3in';
replace(s, 'Right Content', pic);

% --- 10: current selection status (ADR-035) ---
s = add(p, 'Title and Content');
replace(s, 'Title', 'Where this leaves the selection');
replace(s, 'Content', { ...
 'No baseline is committed: ADR-035 reopened the selection for team review'; ...
 Paragraph(sprintf('  %s leads on the merits: wins %d of %d named scenarios and %.1f%% of 5,000 random weightings', ...
    leader, nLeaderScenarios, numel(scenarioNames), leaderShare)); ...
 Paragraph(sprintf('  it is the only candidate that clears all %d formal gates and still produces after any single fault (%.0f%% retention)', ...
    numel(gateNames), 100*metrics{leader,'N1Retention'})); ...
 sprintf('LeanBroth remains a descope option, but misses the %.0f bph throughput floor', ...
    throughputFloor); ...
 sprintf('HyperCook keeps the %.0f s cold-start and raw-rate advantages, but fails %s', ...
    metrics{'HyperCook','TimeToFirstOut_s'}, ...
    joinList(lowerList(failedGates('HyperCook')))); ...
 'Every number regenerates from the repo: runFullAnalysis for results, runAllTests for evidence'});

close(p);
fprintf('deck written: %s\n', outFile);
end

function text = joinList(items)
%JOINLIST Format a short list with "and" before the final item.
if isscalar(items)
    text = items{1};
else
    text = [strjoin(items(1:end-1), ', ') ' and ' items{end}];
end
end
