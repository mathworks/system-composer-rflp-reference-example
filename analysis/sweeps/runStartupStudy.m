function st = runStartupStudy(mode)
%RUNSTARTUPSTUDY Startup transient vs initial ingredient stock (SR-GS-025).
%   The nominal startup numbers reported by runBehavioralAnalysis are
%   measured from a plant whose ingredient stores are ALREADY STOCKED at
%   activation (HC 1500 / LB 600 / ES 900 bowls, see setupBehaviorData).
%   That is a defensible reading of "activation" - a commissioned factory
%   has a larder - but it is an assumption the startup numbers are
%   sensitive to, and it is invisible in a single-point result.
%
%   This study sweeps the stock at activation over
%   [0, 0.5, 1, 2] x the variant default and reports, per point:
%
%     TimeToFirstSoup_s   cook stage produces soup
%     TimeToFirstOut_s    first packaged bowl at the root port
%     TimeToNominal_s     sustained nominal rate (dwell band, ADR-040)
%
%   The 0x point is the honest cold case: an empty larder at activation,
%   with production limited by the resupply rate until the stores fill.
%
%   12 simulations of 4 h each; expect this to be the longest-running
%   script in analysis/sweeps. Produces startupResults.mat /
%   startupSweep.csv and docs/figures/startup_*.png.
%
%   Gravity is NOT swept here - runGravitySweep already covers it, and
%   the batch drain time it moves (ADR-026) shows up in these metrics
%   through the same vat cycle.
%
%   runStartupStudy('figures') redraws the figures from the saved
%   startupResults.mat without re-simulating - the figures are functions
%   of the saved result struct alone, so a plotting change costs nothing.

arguments
    mode (1,:) char {mustBeMember(mode, {'run','figures'})} = 'run'
end

FRAC   = [0 0.5 1 2];
T_STOP = 14400;   % 4 h, same window runBehavioralAnalysis uses
T_SS   = 7200;

proj = currentProject;
anaDir = char(fullfile(proj.RootFolder, 'analysis', 'results'));
figDir = char(fullfile(proj.RootFolder, 'docs', 'figures'));
reqDir = char(fullfile(proj.RootFolder, 'requirements'));
if ~isfolder(figDir), mkdir(figDir); end

if strcmp(mode, 'figures')
    S = load(fullfile(anaDir, 'startupResults.mat'));
    st = S.st;
    makeTimelineFigure(st, figDir);
    makeSensitivityFigure(st, figDir);
    fprintf('startup figures redrawn from startupResults.mat\n');
    return
end

% startup period caps parsed from the requirement text, not hardcoded here
slreq.clear();
srSet = slreq.load(fullfile(reqDir, 'SystemRequirements.slreqx'));
cap_firstSoup_s = gsParseBudgetValue(srSet, 'SR-GS-025.1') * 60;   % min -> s
cap_nominal_s   = gsParseBudgetValue(srSet, 'SR-GS-025.2') * 60;

% {variant, model, storage-init variable, default init bowls}
models = {'HyperCook','PhysicalHyperCook','HC_StorageInit_bowls',1500; ...
          'LeanBroth','PhysicalLeanBroth','LB_StorageInit_bowls',600; ...
          'EverSimmer','PhysicalEverSimmer','ES_StorageInit_bowls',900};
nV = size(models,1); nF = numel(FRAC);

firstSoup_s = NaN(nV,nF); firstOut_s = NaN(nV,nF); nominal_s = NaN(nV,nF);
steady_bph  = NaN(nV,nF);
for v = 1:nV
    for k = 1:nF
        in = Simulink.SimulationInput(models{v,2});
        in = in.setModelParameter('StopTime', num2str(T_STOP), ...
            'SaveOutput','on', 'SaveFormat','Dataset');
        in = in.setVariable(models{v,3}, FRAC(k)*models{v,4}, ...
            'Workspace', models{v,2});
        out = sim(in);
        m = gsStartupMetrics(harvestSignals(out), struct('SteadyStart_s', T_SS));
        firstSoup_s(v,k) = m.TimeToFirstSoup_s;
        firstOut_s(v,k)  = m.TimeToFirstOut_s;
        nominal_s(v,k)   = m.TimeToNominal_s;
        steady_bph(v,k)  = m.SteadyThroughput_bph;
        fprintf('%s @ %.1fx stock: soup %s, packaged %s, nominal %s\n', ...
            models{v,1}, FRAC(k), mins(m.TimeToFirstSoup_s), ...
            mins(m.TimeToFirstOut_s), mins(m.TimeToNominal_s));
    end
end

st.variants = models(:,1)';
st.frac = FRAC;
st.defaultInit_bowls = cell2mat(models(:,4))';
st.firstSoup_s = firstSoup_s;
st.firstOut_s = firstOut_s;
st.nominal_s = nominal_s;
st.steady_bph = steady_bph;
st.cap_firstSoup_s = cap_firstSoup_s;
st.cap_nominal_s = cap_nominal_s;
st.compliant = firstSoup_s <= cap_firstSoup_s & nominal_s <= cap_nominal_s;
save(fullfile(anaDir, 'startupResults.mat'), 'st');

rows = table();
for v = 1:nV
    for k = 1:nF
        rows = [rows; table(string(models{v,1}), FRAC(k), ...
            FRAC(k)*models{v,4}, firstSoup_s(v,k), firstOut_s(v,k), ...
            nominal_s(v,k), steady_bph(v,k), st.compliant(v,k), ...
            'VariableNames', {'Variant','StockFrac','InitStock_bowls', ...
            'TimeToFirstSoup_s','TimeToFirstOut_s','TimeToNominal_s', ...
            'SteadyThroughput_bph','Compliant'})]; %#ok<AGROW>
    end
end
writetable(rows, fullfile(anaDir, 'startupSweep.csv'));

% figures are drawn from the SAVED result struct, so they can be
% regenerated without re-running the twelve simulations
makeTimelineFigure(st, figDir);
makeSensitivityFigure(st, figDir);

fprintf('\nStartup study complete (caps: first soup %s, nominal %s):\n', ...
    mins(cap_firstSoup_s), mins(cap_nominal_s));
disp(rows);
end

% =====================================================================

function sig = harvestSignals(out)
% root outports carry packaged flow + telemetry; logsout carries the
% cook-stage soup flow (single signal, or per-cell for EverSimmer)
sig = struct('flow', [], 'soup', [], 'mode', [], 'power', []);
for i = 1:out.yout.numElements
    y = out.yout{i}.Values;
    if isstruct(y) && isfield(y,'flow_bps'), sig.flow = y.flow_bps; end
    if isstruct(y) && isfield(y,'totalPower_kW')
        sig.power = y.totalPower_kW;
        sig.mode  = y.plantMode;
    end
end
names = string(out.logsout.getElementNames());
if any(names == "soupFlow_bps")
    sig.soup = out.logsout.get('soupFlow_bps').Values;
else
    cells = names(startsWith(names, "soupFlow_Cell"));
    assert(~isempty(cells), ['no cook-stage soup signal logged - re-run ' ...
        'behavior/build/buildInlineBehaviors and save the model']);
    sig.soup = out.logsout.get(char(cells(1))).Values;
    for k = 2:numel(cells)
        sig.soup = sig.soup + resample(out.logsout.get(char(cells(k))).Values, ...
            sig.soup.Time);
    end
end
assert(~isempty(sig.flow) && ~isempty(sig.power), ...
    'root telemetry/shipments outputs missing');
end

function s = mins(t)
if isnan(t), s = 'never'; else, s = sprintf('%.0f min', t/60); end
end

function makeTimelineFigure(st, figDir)
% Off -> first soup -> first packaged -> nominal, one bar row per variant,
% at the nominal (1x) stock point
th = gsPlotTheme(); cols = th.series;
names = st.variants; nV = numel(names);
k1 = find(st.frac == 1, 1);
f = figure('Visible','off','Color',th.surface,'Position',[100 100 900 320]);
ax = axes(f); hold(ax,'on');
for v = 1:nV
    y = nV - v + 1;   % variant 1 draws at the TOP row
    tN = st.nominal_s(v,k1); if isnan(tN), tN = st.cap_nominal_s; end
    % three segments: dead time, cook-to-pack pipeline, ramp to nominal
    seg = [0 st.firstSoup_s(v,k1); ...
           st.firstSoup_s(v,k1) st.firstOut_s(v,k1); ...
           st.firstOut_s(v,k1) tN] / 60;
    alpha = [0.35 0.65 1];
    for k = 1:3
        patch(ax, [seg(k,1) seg(k,2) seg(k,2) seg(k,1)], ...
            y + [-0.28 -0.28 0.28 0.28], cols(v,:), ...
            'FaceAlpha', alpha(k), 'EdgeColor','none');
    end
    if isnan(st.nominal_s(v,k1))
        text(ax, seg(3,2), y, '  never reaches nominal', 'Color', th.limit, ...
            'FontSize', 9, 'VerticalAlignment','middle');
    end
end
% both cap labels drawn to the LEFT of their line, so the SR-GS-025.2
% line at the right-hand edge does not push its label off the axes
xline(ax, st.cap_firstSoup_s/60, ':', 'SR-GS-025.1 first soup', ...
    'Color', th.limit, 'LineWidth', 1, 'FontSize', 9, ...
    'LabelHorizontalAlignment','left');
xline(ax, st.cap_nominal_s/60, '--', 'SR-GS-025.2 nominal', ...
    'Color', th.limit, 'LineWidth', 1, 'FontSize', 9, ...
    'LabelHorizontalAlignment','left');
xlim(ax, [0 st.cap_nominal_s/60 * 1.05]);
% YTick must ascend; row y = nV-v+1 puts variant 1 on top, so the labels
% run in reverse order against the ascending ticks
set(ax,'YTick',1:nV,'YTickLabel',flip(names),'XGrid','on', ...
    'GridColor',th.grid,'GridAlpha',1,'Box','off','Color',th.surface, ...
    'XColor',th.inkS,'YColor',th.inkS,'FontSize',10);
ylim(ax,[0.4 nV+0.6]);
xlabel(ax,'Minutes from activation','Color',th.inkP);
title(ax,'Startup timeline: dead time / cook-to-pack pipeline / ramp to nominal', ...
    'Color',th.inkP,'FontWeight','normal','FontSize',12);
exportgraphics(f, fullfile(figDir,'startup_timeline.png'), 'Resolution', 200);
close(f);
end

function makeSensitivityFigure(st, figDir)
th = gsPlotTheme(); cols = th.series; names = st.variants;
f = figure('Visible','off','Color',th.surface,'Position',[100 100 900 400]);
ax = axes(f); hold(ax,'on');
for v = 1:numel(names)
    plot(ax, st.frac, st.nominal_s(v,:)/60, '-o', 'Color', cols(v,:), ...
        'MarkerFaceColor', cols(v,:), 'LineWidth', 2);
end
yline(ax, st.cap_nominal_s/60, '--', 'SR-GS-025.2 startup period', ...
    'Color', th.limit, 'LineWidth', 1, 'FontSize', 9);
set(ax,'XTick',st.frac,'YGrid','on','GridColor',th.grid,'GridAlpha',1, ...
    'Box','off','Color',th.surface,'XColor',th.inkS,'YColor',th.inkS,'FontSize',10);
xlabel(ax,'Ingredient stock at activation (x variant default)','Color',th.inkP);
ylabel(ax,'Time to sustained nominal rate (min)','Color',th.inkP);
legend(ax, names, 'Location','northeast','Box','off','TextColor',th.inkP);
title(ax,'How much of the startup number is the stocked larder?', ...
    'Color',th.inkP,'FontWeight','normal','FontSize',12);
exportgraphics(f, fullfile(figDir,'startup_sensitivity.png'), 'Resolution', 200);
close(f);
end
