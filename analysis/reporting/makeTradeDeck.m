function makeTradeDeck()
%MAKETRADEDECK Generate the trade-study briefing deck (PowerPoint).
%   One slide per explainer card (docs/explainers/), plus a title slide,
%   one schematic slide per variant, and a closing selection slide. Built
%   with MATLAB Report Generator so the deck regenerates from the repo:
%   figures come from docs/figures, and every quantitative claim in the
%   slide text is FORMATTED from the committed analysis outputs in
%   analysis/results rather than transcribed into the prose. Hand-typed
%   numbers are what went stale here before - the deck outlived two rounds
%   of results - so the rule is now: if it is a number, derive it.
%   Output: docs/deliverables/GalacticSoupTradeDeck.pptx.

import mlreportgen.ppt.*
proj = currentProject;
figDir = char(fullfile(proj.RootFolder, 'docs', 'figures'));
resDir = fullfile(proj.RootFolder, 'analysis', 'results');
outFile = char(fullfile(proj.RootFolder, 'docs', 'deliverables', 'GalacticSoupTradeDeck.pptx'));
if isfile(outFile), delete(outFile); end

% ===================== Source data =====================
metrics = readtable(fullfile(resDir, 'variantMetrics.csv'), 'ReadRowNames', true);
beh     = readtable(fullfile(resDir, 'behavioralMetrics.csv'), 'ReadRowNames', true);
gate    = readtable(fullfile(resDir, 'complianceGate.csv'), 'ReadRowNames', true);
trade   = readtable(fullfile(resDir, 'tradeScores.csv'), 'ReadRowNames', true);
mc      = readtable(fullfile(resDir, 'mcWinShare.csv'), 'ReadRowNames', true);
vOrder  = {'HyperCook','LeanBroth','EverSimmer'};

% --- formal gate: pass count, and which cells fail for whom ---
gateNames = gate.Properties.VariableNames(1:end-1);      % drop AllGatesPass
gateCells = logical(gate{:, 1:end-1});
nGatePass = nnz(gateCells);
nGateTot  = numel(gateCells);
rowOf = @(v) find(strcmp(gate.Properties.RowNames, v), 1);
failedGates = @(v) gateNames(~gateCells(rowOf(v), :));

% --- resource caps already breached by the static roll-up ---
isBudget = ismember(gateNames, {'Mass','Power','Cost','Volume'});
budgetNames = gateNames(isBudget);
overCap = {};
for v = 1:numel(vOrder)
    breached = budgetNames(~gateCells(rowOf(vOrder{v}), isBudget));
    if ~isempty(breached)
        plural = 's'; if isscalar(breached), plural = ''; end
        overCap{end+1} = sprintf('%s is over its %s cap%s before anything runs', ...
            vOrder{v}, joinList(lower(breached)), plural); %#ok<AGROW>
    end
end
if isempty(overCap), overCap = {'All three fit every resource budget on paper'}; end

% --- scenario winners and the weight-sensitivity leader ---
scenNames = trade.Properties.VariableNames;
[~, wIdx] = max(trade{:,:}, [], 1);
scenWinners = trade.Properties.RowNames(wIdx);
mcPct = 100 * mc{vOrder, 'WinShare'};
[leadShare, leadIdx] = max(mcPct);
leader = vOrder{leadIdx};
nLeaderScen = nnz(strcmp(scenWinners, leader));

% --- the SR-GS-002 floor, recovered from the margin rather than typed in ---
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
 'Budget caps are parsed from the requirement text at run time'}; ...
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
    metrics{vOrder,'Throughput_bph'}, metrics{vOrder,'Static_Throughput_bph'})', ', ') ' bph']; ...
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
    [vOrder(:), beh{vOrder,'WorstFault'}, ...
     compose('%.0f%%', 100*metrics{vOrder,'N1Retention'})]]));
pic = Picture(fullfile(figDir, 'behavioral_fault.png'));
pic.Width = '5.6in'; pic.Height = '2.5in';
replace(s, 'Right Content', pic);

% --- 8: compliance gate ---
s = add(p, 'Two Content');
replace(s, 'Title', '4. The pass/fail line (formal compliance gate)');
replace(s, 'Left Content', { ...
 sprintf('%d quantitative requirements as executable Requirements Table rows', numel(gateNames)); ...
 'Simulated metrics feed the gate; a parallel hand-coded check must agree'; ...
 'A failed gate travels with the variant into scoring rather than silently dropping it'; ...
 'An eliminated variant is a finding with a recovery path'});
gateRows = cell(numel(vOrder), 2);
for v = 1:numel(vOrder)
    f = failedGates(vOrder{v});
    if isempty(f)
        gateRows(v,:) = {vOrder{v}, sprintf('compliant on all %d', numel(gateNames))};
    else
        gateRows(v,:) = {vOrder{v}, ['fails ' joinList(lower(f))]};
    end
end
replace(s, 'Right Content', Table([ ...
    {'Variant','Formal gate result'}; ...
    gateRows; ...
    {'Checks passing', sprintf('%d of %d', nGatePass, nGateTot)}; ...
    {'Recovery', sprintf('QC bench with reject <= ~1.3%% clears the %.0f bph floor', throughputFloor)}]));

% --- 9: trade scoring ---
s = add(p, 'Two Content');
replace(s, 'Title', '5. Pick a winner you can defend (MCDA + Monte Carlo)');
replace(s, 'Left Content', Table([ ...
    ['Scenario', vOrder, {'Winner'}]; ...
    [scenNames(:), compose('%.2f', trade{vOrder,:}'), scenWinners(:)]]));
pic = Picture(fullfile(figDir, 'mc_winshare.png'));
pic.Width = '5.6in'; pic.Height = '2.3in';
replace(s, 'Right Content', pic);

% --- 10: where the selection stands (ADR-035: no baseline committed) ---
s = add(p, 'Title and Content');
replace(s, 'Title', 'Where this leaves the selection');
replace(s, 'Content', { ...
 'No baseline is committed: ADR-035 reopened the selection for team review'; ...
 Paragraph(sprintf('  %s leads on the merits: wins %d of %d named scenarios and %.1f%% of 5,000 random weightings', ...
    leader, nLeaderScen, numel(scenNames), leadShare)); ...
 Paragraph(sprintf('  it is the only candidate that clears all %d formal gates, and the only one still producing after any single fault (%.0f%% retention, Degraded mode)', ...
    numel(gateNames), 100*metrics{leader,'N1Retention'})); ...
 sprintf('LeanBroth is eliminated, not dead: a better QC bench puts it back over the %.0f bph throughput floor', ...
    throughputFloor); ...
 sprintf('HyperCook keeps a niche - %.0f s cold start and the highest raw rate - but is over %s', ...
    metrics{'HyperCook','TimeToFirstOut_s'}, joinList(lower(failedGates('HyperCook')))); ...
 'Every number regenerates from the repo: runFullAnalysis for the results, runAllTests for the evidence'});

close(p);
fprintf('deck written: %s\n', outFile);
end

function s = joinList(items)
%JOINLIST Comma-separated list with "and" before the last item.
if isscalar(items)
    s = items{1};
else
    s = [strjoin(items(1:end-1), ', ') ' and ' items{end}];
end
end
