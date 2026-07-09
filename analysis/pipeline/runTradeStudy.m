function trade = runTradeStudy(includeVariants)
%RUNTRADESTUDY MCDA trade study over the physical architecture variants.
%
%   trade = runTradeStudy() scores every variant in variantMetrics.mat.
%   trade = runTradeStudy(includeVariants) restricts scoring to the given
%   variant names (cellstr) - runFullAnalysis passes the subset that
%   passed the formal compliance gate.
%
%   Produces:
%     - tradeStudyResults.mat / tradeScores.csv    scores per scenario
%     - mcWinShare.csv                             Monte Carlo win shares
%     - ../docs/figures/*.png                      comparison charts
%
%   Method: seven benefit criteria, min-max normalized across variants,
%   weighted-sum scoring under four stakeholder scenarios, plus a
%   5000-sample Dirichlet random-weight sensitivity sweep.

proj = currentProject;
anaDir = char(fullfile(proj.RootFolder, 'analysis', 'results'));
figDir = char(fullfile(proj.RootFolder, 'docs', 'figures'));
if ~isfolder(figDir), mkdir(figDir); end

S = load(fullfile(anaDir, 'variantMetrics.mat'));
R = S.results;
caps = S.caps;

% Fixed per-variant palette assigned by NAME, not position, so an excluded
% variant never repaints the survivors (color follows the entity).
palette = containers.Map( ...
    {'HyperCook','LeanBroth','EverSimmer'}, ...
    {[42 120 214]/255, [27 175 122]/255, [237 161 0]/255});

if nargin > 0 && ~isempty(includeVariants)
    keep = ismember({R.Variant}, includeVariants);
    assert(any(keep), 'None of the requested variants exist in variantMetrics.mat');
    R = R(keep);
end
nV = numel(R);
vnames = {R.Variant};

% --- Criteria (all benefit-form: higher is better) ---
critNames = {'ThroughputMargin','ResourceMargin','CostMargin','Automation', ...
             'CrewMargin','Availability','N1Retention'};
raw = zeros(nV, numel(critNames));
for v = 1:nV
    raw(v,1) = R(v).Throughput_bph / caps.Throughput_bph - 1;
    raw(v,2) = mean([R(v).Margin_Mass, R(v).Margin_Power, R(v).Margin_Volume]);
    raw(v,3) = R(v).Margin_Cost;
    raw(v,4) = R(v).AutomationAvg;
    raw(v,5) = (caps.Operators - R(v).OperatorsRequired) / caps.Operators;
    raw(v,6) = R(v).Availability;
    raw(v,7) = R(v).N1Retention;
end

% Min-max normalize per criterion (guard zero-range)
norm = zeros(size(raw));
for j = 1:size(raw,2)
    rng_ = max(raw(:,j)) - min(raw(:,j));
    if rng_ < eps
        norm(:,j) = 0.5;
    else
        norm(:,j) = (raw(:,j) - min(raw(:,j))) / rng_;
    end
end

% --- Weighting scenarios ---
scen.Balanced         = [0.20 0.10 0.15 0.10 0.10 0.15 0.20];
scen.ThroughputFirst  = [0.35 0.05 0.15 0.10 0.05 0.15 0.15];
scen.CostLean         = [0.10 0.20 0.35 0.05 0.10 0.10 0.10];
scen.MissionAssurance = [0.10 0.05 0.10 0.10 0.10 0.25 0.30];
scenNames = fieldnames(scen);

scores = zeros(nV, numel(scenNames));
for s = 1:numel(scenNames)
    w = scen.(scenNames{s});
    assert(abs(sum(w) - 1) < 1e-9, 'Weights must sum to 1');
    scores(:,s) = norm * w';
end

% --- Monte Carlo weight sensitivity (Dirichlet via normalized exponentials) ---
nMC = 5000;
rngState = rng(42);  %#ok<NASGU> % reproducible
E = -log(rand(nMC, numel(critNames)));
W = E ./ sum(E, 2);
mcScores = W * norm';            % nMC x nV
[~, winner] = max(mcScores, [], 2);
winShare = histcounts(winner, 0.5:1:nV+0.5) / nMC;

% --- Persist results ---
trade.criteria = critNames;
trade.variants = vnames;
trade.raw = raw;
trade.normalized = norm;
trade.scenarios = scen;
trade.scores = scores;
trade.winShare = winShare;
save(fullfile(anaDir, 'tradeStudyResults.mat'), 'trade');

Tsc = array2table(scores, 'VariableNames', scenNames', 'RowNames', vnames');
writetable(Tsc, fullfile(anaDir, 'tradeScores.csv'), 'WriteRowNames', true);
Tmc = table(vnames', winShare', 'VariableNames', {'Variant','WinShare'});
writetable(Tmc, fullfile(anaDir, 'mcWinShare.csv'));

% ===================== Charts =====================
% Per-variant colors resolved by name from the fixed palette
cols = zeros(nV, 3);
for v = 1:nV, cols(v,:) = palette(vnames{v}); end
surf_ = [252 252 251] / 255;
inkP = [11 11 11] / 255;
inkS = [82 81 78] / 255;
gridC = [0.88 0.88 0.87];

% --- Fig 1: budget utilization (% of SR cap) ---
f = figure('Visible','off','Color',surf_,'Position',[100 100 860 420]);
ax = axes(f); hold(ax,'on');
util = zeros(nV,4);
for v = 1:nV
    util(v,:) = 100 * [R(v).Mass_kg/caps.Mass_kg, R(v).Power_kW/caps.Power_kW, ...
                       R(v).Cost_kCredits/caps.Cost_kCredits, R(v).Volume_m3/caps.Volume_m3];
end
b = bar(ax, util', 0.72, 'grouped', 'EdgeColor', surf_, 'LineWidth', 1.5);
for v = 1:nV, b(v).FaceColor = cols(v,:); end
yline(ax, 100, '-', 'SR cap', 'Color', [0.35 0.35 0.35], 'LineWidth', 1, ...
    'LabelHorizontalAlignment','left', 'FontSize', 9);
for v = 1:nV
    xt = b(v).XEndPoints;
    text(ax, xt, util(v,:) + 2.5, compose('%.0f', util(v,:)), ...
        'HorizontalAlignment','center', 'FontSize', 8.5, 'Color', inkS);
end
set(ax, 'XTick', 1:4, 'XTickLabel', {'Mass (15 t)','Power (500 kW)','Cost (2 MCr)','Volume (400 m^3)'}, ...
    'YGrid','on','GridColor',gridC,'GridAlpha',1,'Box','off','Color',surf_, ...
    'XColor',inkS,'YColor',inkS,'FontSize',10);
ylabel(ax, 'Budget utilization (%)', 'Color', inkP);
ylim(ax, [0 118]);
legend(ax, vnames, 'Location','northoutside','Orientation','horizontal','Box','off','TextColor',inkP);
title(ax, 'Resource budget utilization vs SR caps', 'Color', inkP, 'FontWeight','normal','FontSize',12);
exportgraphics(f, fullfile(figDir, 'budget_utilization.png'), 'Resolution', 200);
close(f);

% --- Fig 2: normalized criteria scores ---
f = figure('Visible','off','Color',surf_,'Position',[100 100 940 430]);
ax = axes(f); hold(ax,'on');
b = bar(ax, norm', 0.72, 'grouped', 'EdgeColor', surf_, 'LineWidth', 1.5);
for v = 1:nV, b(v).FaceColor = cols(v,:); end
set(ax, 'XTick', 1:numel(critNames), 'XTickLabel', ...
    {'Throughput','Resource','Cost','Automation','Crew','Availability','N-1 reten.'}, ...
    'YGrid','on','GridColor',gridC,'GridAlpha',1,'Box','off','Color',surf_, ...
    'XColor',inkS,'YColor',inkS,'FontSize',10);
ylabel(ax, 'Normalized score (min-max)', 'Color', inkP);
ylim(ax, [0 1.12]);
legend(ax, vnames, 'Location','northoutside','Orientation','horizontal','Box','off','TextColor',inkP);
title(ax, 'Criterion scores by variant (1 = best of the three)', 'Color', inkP, 'FontWeight','normal','FontSize',12);
exportgraphics(f, fullfile(figDir, 'criteria_scores.png'), 'Resolution', 200);
close(f);

% --- Fig 3: weighted scores per scenario ---
f = figure('Visible','off','Color',surf_,'Position',[100 100 860 420]);
ax = axes(f); hold(ax,'on');
b = bar(ax, scores', 0.72, 'grouped', 'EdgeColor', surf_, 'LineWidth', 1.5);
for v = 1:nV, b(v).FaceColor = cols(v,:); end
for v = 1:nV
    xt = b(v).XEndPoints;
    text(ax, xt, scores(v,:)' + 0.02, compose('%.2f', scores(v,:)'), ...
        'HorizontalAlignment','center', 'FontSize', 8.5, 'Color', inkS);
end
set(ax, 'XTick', 1:numel(scenNames), 'XTickLabel', scenNames, ...
    'YGrid','on','GridColor',gridC,'GridAlpha',1,'Box','off','Color',surf_, ...
    'XColor',inkS,'YColor',inkS,'FontSize',10);
ylabel(ax, 'Weighted MCDA score', 'Color', inkP);
ylim(ax, [0 1.0]);
legend(ax, vnames, 'Location','northoutside','Orientation','horizontal','Box','off','TextColor',inkP);
title(ax, 'Trade study scores under stakeholder weighting scenarios', 'Color', inkP, 'FontWeight','normal','FontSize',12);
exportgraphics(f, fullfile(figDir, 'scenario_scores.png'), 'Resolution', 200);
close(f);

% --- Fig 4: Monte Carlo win share ---
f = figure('Visible','off','Color',surf_,'Position',[100 100 720 300]);
ax = axes(f); hold(ax,'on');
bh = barh(ax, winShare * 100, 0.55, 'EdgeColor', surf_, 'LineWidth', 1.5);
bh.FaceColor = 'flat';
for v = 1:nV, bh.CData(v,:) = cols(v,:); end
text(ax, winShare*100 + 1.5, 1:nV, compose('%.1f%%', winShare*100), ...
    'FontSize', 10, 'Color', inkP, 'VerticalAlignment','middle');
set(ax, 'YTick', 1:nV, 'YTickLabel', vnames, 'XGrid','on','GridColor',gridC, ...
    'GridAlpha',1,'Box','off','Color',surf_,'XColor',inkS,'YColor',inkP,'FontSize',10);
xlabel(ax, 'Share of 5000 random weightings won (%)', 'Color', inkP);
xlim(ax, [0 max(winShare*100) + 12]);
title(ax, 'Weight-sensitivity: how often each variant wins', 'Color', inkP, 'FontWeight','normal','FontSize',12);
exportgraphics(f, fullfile(figDir, 'mc_winshare.png'), 'Resolution', 200);
close(f);

fprintf('Trade study complete. Scores:\n');
disp(Tsc);
fprintf('Monte Carlo win share: %s\n', strjoin(compose('%s %.1f%%', string(vnames'), winShare'*100), ', '));
end
