function unc = runUncertaintyStudy()
%RUNUNCERTAINTYSTUDY Parameter-uncertainty Monte Carlo post-processing.
%   Consumes the per-variant simulation batches from runUncertaintySims
%   (600 architecture simulations: 200 common-random-number draws of the
%   QC reject fraction and calibration schedule, x3 variants) and answers
%   the question the weights-only Monte Carlo in runTradeStudy cannot:
%   how robust are the trade-study conclusions to the parameters that are
%   engineering estimates rather than measurements?
%
%   Produces:
%     - uncertaintyResults.mat / uncertaintySummary.csv
%     - docs/figures/uncertainty_throughput.png   throughput distributions
%       against the SR-GS-002 floor, with per-variant compliance probability
%     - docs/figures/uncertainty_winshare.png     win share under parameter
%       AND weight uncertainty vs. the weights-only baseline
%
%   Method: per parameter draw, the compliance gate rule is applied with
%   that draw's simulated throughput (a variant below the floor is
%   excluded from that draw's scoring, mirroring runFullAnalysis), the
%   ThroughputMargin criterion is recomputed, the remaining six criteria
%   keep their measured values, and K Dirichlet weight draws score the
%   compliant set. Win share aggregates over N*K = 5000 scored worlds.

spec = uncertaintySpec();
proj = currentProject;
anaDir = char(fullfile(proj.RootFolder, 'analysis', 'results'));
figDir = char(fullfile(proj.RootFolder, 'docs', 'figures'));

vnames = fieldnames(spec.variants)';
nV = numel(vnames);
thr = zeros(spec.N, nV); energy = zeros(spec.N, nV);
for v = 1:nV
    f = fullfile(anaDir, ['uncertaintySims_' vnames{v} '.mat']);
    assert(isfile(f), 'missing %s - run runUncertaintySims(''%s'') first', f, vnames{v});
    S = load(f);
    thr(:,v) = S.sims.thr_bph;
    energy(:,v) = S.sims.energy_kWh_per_bowl;
end

M = load(fullfile(anaDir, 'variantMetrics.mat'));
caps = M.caps;
[~, order] = ismember(vnames, {M.results.Variant});
R = M.results(order);

% --- compliance probability per variant ---
floorBph = caps.Throughput_bph;
pPass = mean(thr >= floorBph, 1);

% --- static criteria (6 of 7; ThroughputMargin recomputed per draw) ---
critNames = {'ThroughputMargin','ResourceMargin','CostMargin','Automation', ...
             'CrewMargin','Availability','N1Retention'};
rawStatic = zeros(nV, 7);
for v = 1:nV
    rawStatic(v,2) = mean([R(v).Margin_Mass, R(v).Margin_Power, R(v).Margin_Volume]);
    rawStatic(v,3) = R(v).Margin_Cost;
    rawStatic(v,4) = R(v).AutomationAvg;
    rawStatic(v,5) = (caps.Operators - R(v).OperatorsRequired) / caps.Operators;
    rawStatic(v,6) = R(v).Availability;
    rawStatic(v,7) = R(v).N1Retention;
end

% --- double Monte Carlo: parameter draws x weight draws ---
rng(spec.seedWeights);
E = -log(rand(spec.N * spec.K, numel(critNames)));
W = E ./ sum(E, 2);
wins = zeros(1, nV);
for i = 1:spec.N
    inc = find(thr(i,:) >= floorBph);
    assert(~isempty(inc), 'draw %d: no compliant variant', i);
    raw = rawStatic(inc,:);
    raw(:,1) = thr(i,inc)' / floorBph - 1;
    nrm = zeros(size(raw));
    for j = 1:size(raw,2)
        rj = max(raw(:,j)) - min(raw(:,j));
        if rj < eps, nrm(:,j) = 0.5; else, nrm(:,j) = (raw(:,j)-min(raw(:,j)))/rj; end
    end
    Wi = W((i-1)*spec.K + (1:spec.K), :);
    [~, wIdx] = max(Wi * nrm', [], 2);
    for k = 1:spec.K
        wins(inc(wIdx(k))) = wins(inc(wIdx(k))) + 1;
    end
end
winShare2 = wins / (spec.N * spec.K);

% --- persist ---
unc.spec = rmfield(spec, 'variants');
unc.variants = vnames;
unc.thr_bph = thr;
unc.energy_kWh_per_bowl = energy;
unc.pPass = pPass;
unc.winShare2 = winShare2;
unc.floor_bph = floorBph;
save(fullfile(anaDir, 'uncertaintyResults.mat'), 'unc');
T = table(vnames', pPass', median(thr)', prctile(thr,5)', prctile(thr,95)', ...
    winShare2', 'VariableNames', ...
    {'Variant','PComply','MedianThr_bph','P5Thr_bph','P95Thr_bph','WinShare'});
writetable(T, fullfile(anaDir, 'uncertaintySummary.csv'));

% ===================== figures (house style) =====================
th = gsPlotTheme();   % dark house style; colors by variant name
palette = th.palette;
surf_ = th.surface; inkP = th.inkP; inkS = th.inkS; gridC = th.grid;

f = figure('Visible','off','Color',surf_,'Position',[100 100 900 420]);
ax = axes(f); hold(ax,'on');
for v = 1:nV
    [d, x] = ksdensity(thr(:,v));
    fill(ax, [x fliplr(x)], [d zeros(size(d))], palette(vnames{v}), ...
        'FaceAlpha', 0.25, 'EdgeColor', palette(vnames{v}), 'LineWidth', 2);
end
xline(ax, floorBph, '--', 'SR-GS-002 floor (200 bph)', 'Color', th.limit, ...
    'LineWidth', 1.2, 'FontSize', 9, 'LabelVerticalAlignment','bottom', ...
    'LabelHorizontalAlignment','right');
yl = ylim(ax);
% each distribution is named by its own direct label (ink, not series
% color) - identity is explicit text over the curve, so no legend box
% competing with the labels for the top band
for v = 1:nV
    text(ax, median(thr(:,v)), yl(2)*0.92, ...
        sprintf('%s\\newlineP(comply) = %.1f%%', vnames{v}, pPass(v)*100), ...
        'Color', inkP, 'FontSize', 9, 'HorizontalAlignment','center');
end
set(ax,'YGrid','on','GridColor',gridC,'GridAlpha',1,'Box','off','Color',surf_, ...
    'XColor',inkS,'YColor',inkS,'FontSize',10);
xlabel(ax,'Steady-state packaged throughput (bph)','Color',inkP);
ylabel(ax,'Probability density','Color',inkP);
title(ax, sprintf(['Throughput under parameter uncertainty: %d simulations ' ...
    'per variant'], spec.N), 'Color', inkP, 'FontWeight','normal','FontSize',12);
exportgraphics(f, fullfile(figDir,'uncertainty_throughput.png'), 'Resolution', 200);
close(f);

% weights-only baseline for comparison (from the compliant-set trade study)
base = zeros(1, nV);
Tr = load(fullfile(anaDir, 'tradeStudyResults.mat'));
[tf, loc] = ismember(vnames, Tr.trade.variants);
base(tf) = Tr.trade.winShare(loc(tf));

f = figure('Visible','off','Color',surf_,'Position',[100 100 900 380]);
ax = axes(f); hold(ax,'on');
yy = 1:nV;
for v = 1:nV
    barh(ax, yy(v)+0.17, winShare2(v)*100, 0.32, 'FaceColor', palette(vnames{v}), ...
        'EdgeColor','none');
    barh(ax, yy(v)-0.17, base(v)*100, 0.32, 'FaceColor', palette(vnames{v}), ...
        'EdgeColor','none', 'FaceAlpha', 0.35);
    text(ax, winShare2(v)*100+1.2, yy(v)+0.17, sprintf('%.1f%%', winShare2(v)*100), ...
        'Color', inkP, 'FontSize', 9);
    text(ax, base(v)*100+1.2, yy(v)-0.17, sprintf('%.1f%% (weights only)', base(v)*100), ...
        'Color', inkS, 'FontSize', 8);
end
set(ax,'YTick',yy,'YTickLabel',vnames,'XGrid','on','GridColor',gridC,'GridAlpha',1, ...
    'Box','off','Color',surf_,'XColor',inkS,'YColor',inkP,'FontSize',10);
xlabel(ax,'Win share (%)','Color',inkP);
xlim(ax, [0 max([winShare2 base])*100 + 16]);
title(ax,'Win share: parameter + weight uncertainty vs. weights only', ...
    'Color',inkP,'FontWeight','normal','FontSize',12);
exportgraphics(f, fullfile(figDir,'uncertainty_winshare.png'), 'Resolution', 200);
close(f);

fprintf('Parameter-uncertainty study: %d draws x %d variants\n', spec.N, nV);
disp(T);
end
