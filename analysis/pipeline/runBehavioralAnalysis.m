function beh = runBehavioralAnalysis()
%RUNBEHAVIORALANALYSIS Simulate the three physical ARCHITECTURE models
%   (behavior lives inline in the System Composer components, ADR-020)
%   and extract the metrics that feed the trade study at higher fidelity
%   than the static stage-table roll-up:
%
%     SimThroughput_bph   steady-state packaged throughput at the root
%                         OutboundShipments.flow_bps port, nominal run
%     TimeToFirstSoup_s   cold-start time until COOKED SOUP first exists
%                         at the cook-stage output (logged soupFlow_*)
%     TimeToFirstOut_s    cold-start time until PACKAGED flow appears at
%                         the root port - later by the QC/packaging lag
%     TimeToNominal_s     cold start to a SUSTAINED nominal production
%                         rate (dwell band, gsStartupMetrics / ADR-040)
%     TimeToModeRunning_s when the supervisor enters RUNNING (all lines
%                         healthy and flowing - a health state, not a rate)
%     StartupEnergy_kWh   energy consumed before the plant reaches nominal
%     Energy_kWh_per_bowl integrated Telemetry.totalPower_kW (aggregated
%                         by the controller from every component's status
%                         bus, incl. physical heater duty) per bowl
%     SimRetention        worst-case single-fault throughput retention;
%                         faults inject via Fault_T_* model-workspace
%                         variables (component self-gates at that time)
%     PeakPower_kW        maximum instantaneous plant power draw
%
%   Writes behavioralMetrics.mat/.csv and docs/figures/behavioral_*.png.
%   Results are consumed by runVariantAnalysis, which overrides its static
%   throughput and N-1 retention values when this file is present.

proj = currentProject;
anaDir = char(fullfile(proj.RootFolder, 'analysis', 'results'));
figDir = char(fullfile(proj.RootFolder, 'docs', 'figures'));
if ~isfolder(figDir), mkdir(figDir); end

T_NOM   = 14400;   % nominal run length (4 h)
T_FLT   = 21600;   % fault run length (6 h)
T_FAULT = 7200;    % fault injection time
T_SS    = 7200;    % steady-state window start

% {Variant, architecture model, worst-fault variable, worst-fault label}
plants = { ...
 'HyperCook',  'PhysicalHyperCook',  'Fault_T_QC',    'InlineQCScanner (serial single-string)'; ...
 'LeanBroth',  'PhysicalLeanBroth',  'Fault_T_Prep',  'PrepWorkstation (serial single-string)'; ...
 'EverSimmer', 'PhysicalEverSimmer', 'Fault_T_Cell1', 'ProductionCell1 (one of three cells)'};

beh = struct([]);
traces = struct([]);
for v = 1:size(plants, 1)
    mdl = plants{v,2};

    % --- Nominal run ---
    in = Simulink.SimulationInput(mdl);
    in = in.setModelParameter('StopTime', num2str(T_NOM), ...
        'SaveOutput','on', 'SaveFormat','Dataset');
    out = sim(in);
    [flow, tele] = harvest(out);
    soup = harvestSoup(out);

    ss = flow.Time >= T_SS;
    r.Variant = plants{v,1};
    r.SimThroughput_bph = trapz(flow.Time(ss), flow.Data(ss)) ...
                          / (flow.Time(end) - T_SS) * 3600;

    % --- startup transient (SR-GS-025): the two questions are separate,
    % and the shared extractor is also what the Simulink Test criteria
    % call, so analysis and evidence cannot drift apart
    st = gsStartupMetrics(struct('flow', flow, 'soup', soup, ...
        'mode', tele.plantMode, 'power', tele.totalPower_kW), ...
        struct('SteadyStart_s', T_SS));
    assert(~isnan(st.TimeToFirstOut_s), '%s produced no output', mdl);
    r.TimeToFirstSoup_s   = st.TimeToFirstSoup_s;
    r.TimeToFirstOut_s    = st.TimeToFirstOut_s;
    r.TimeToNominal_s     = st.TimeToNominal_s;
    r.TimeToModeRunning_s = st.TimeToModeRunning_s;
    r.StartupEnergy_kWh   = st.StartupEnergy_kWh;

    bowlsSS  = trapz(flow.Time(ss), flow.Data(ss));
    pw = tele.totalPower_kW;
    energySS = trapz(pw.Time(pw.Time >= T_SS), pw.Data(pw.Time >= T_SS)) / 3600;
    r.Energy_kWh_per_bowl = energySS / bowlsSS;
    r.MeanPower_kW = mean(pw.Data(pw.Time >= T_SS));
    r.PeakPower_kW = max(pw.Data);
    assert(tele.plantMode.Data(end) == 1, '%s not Running at end of clean run', mdl);

    % --- Worst-case single-fault run (component self-gates at T_FAULT) ---
    in = Simulink.SimulationInput(mdl);
    in = in.setModelParameter('StopTime', num2str(T_FLT), ...
        'SaveOutput','on', 'SaveFormat','Dataset');
    in = in.setVariable(plants{v,3}, T_FAULT, 'Workspace', mdl);
    out = sim(in);
    [fflow, ftele] = harvest(out);
    pre  = fflow.Time > 3600 & fflow.Time < T_FAULT;
    post = fflow.Time > T_FLT - 7200;
    preRate  = trapz(fflow.Time(pre),  fflow.Data(pre))  / (T_FAULT - 3600) * 3600;
    postRate = trapz(fflow.Time(post), fflow.Data(post)) / 7200 * 3600;
    r.SimRetention = max(0, min(1, postRate / preRate));
    r.WorstFault = plants{v,4};
    r.FaultEndMode = double(ftele.plantMode.Data(end));

    if isempty(beh), beh = r; else, beh(end+1) = r; end %#ok<AGROW>
    traces(v).nomT = flow.Time / 3600;  traces(v).nomY = flow.Data * 3600;
    traces(v).fltT = fflow.Time / 3600; traces(v).fltY = fflow.Data * 3600;
    traces(v).st   = st;
    % show the startup window with headroom past the slowest settle
    traces(v).stopMinutes = 1.3 * max([st.TimeToNominal_s, st.TimeToFirstOut_s, 1800]) / 60;
end

save(fullfile(anaDir, 'behavioralMetrics.mat'), 'beh');
writetable(struct2table(beh), fullfile(anaDir, 'behavioralMetrics.csv'));

% ===================== Trace figures =====================
th = gsPlotTheme();   % dark house style; series by fixed variant order
cols = th.series;
surf_ = th.surface; inkP = th.inkP; inkS = th.inkS; gridC = th.grid;

f = figure('Visible','off','Color',surf_,'Position',[100 100 900 400]);
ax = axes(f); hold(ax,'on');
for v = 1:3
    plot(ax, traces(v).nomT, movmean(traces(v).nomY, 25), 'Color', cols(v,:), 'LineWidth', 2);
end
yline(ax, 200, '--', 'SR-GS-002 floor (200 bph)', 'Color', th.limit, ...
    'LineWidth', 1, 'FontSize', 9, 'LabelHorizontalAlignment','left');
set(ax,'YGrid','on','GridColor',gridC,'GridAlpha',1,'Box','off','Color',surf_, ...
    'XColor',inkS,'YColor',inkS,'FontSize',10);
xlabel(ax,'Time (h)','Color',inkP); ylabel(ax,'Packaged throughput (bph, smoothed)','Color',inkP);
legend(ax, {beh.Variant}, 'Location','southeast','Box','off','TextColor',inkP);
title(ax,'Simulated architecture models: cold start and steady state (nominal)', ...
    'Color',inkP,'FontWeight','normal','FontSize',12);
exportgraphics(f, fullfile(figDir,'behavioral_throughput.png'), 'Resolution', 200);
close(f);

f = figure('Visible','off','Color',surf_,'Position',[100 100 900 400]);
ax = axes(f); hold(ax,'on');
for v = 1:3
    plot(ax, traces(v).fltT, movmean(traces(v).fltY, 25), 'Color', cols(v,:), 'LineWidth', 2);
end
xline(ax, 2, ':', 'worst-case fault injected', 'Color', th.muted, ...
    'LineWidth', 1.2, 'FontSize', 9);
yline(ax, 200, '--', 'SR floor', 'Color', th.limit, 'LineWidth', 1, 'FontSize', 9);
set(ax,'YGrid','on','GridColor',gridC,'GridAlpha',1,'Box','off','Color',surf_, ...
    'XColor',inkS,'YColor',inkS,'FontSize',10);
xlabel(ax,'Time (h)','Color',inkP); ylabel(ax,'Packaged throughput (bph, smoothed)','Color',inkP);
legend(ax, {beh.Variant}, 'Location','northeast','Box','off','TextColor',inkP);
title(ax,'Worst-case single-fault response (fault at t = 2 h)', ...
    'Color',inkP,'FontWeight','normal','FontSize',12);
exportgraphics(f, fullfile(figDir,'behavioral_fault.png'), 'Resolution', 200);
close(f);

% --- Startup transient: the two SR-GS-025 questions, drawn (ADR-040) ---
% Rate is the trailing 5-minute production rate, i.e. what the plant is
% actually delivering - not the instantaneous flow, which for the batch
% variants is a train of drain spikes and reads as noise.
tMax = max([traces.stopMinutes]);
f = figure('Visible','off','Color',surf_,'Position',[100 100 900 420]);
ax = axes(f); hold(ax,'on');
h = gobjects(1,3);
for v = 1:3
    st = traces(v).st;
    h(v) = plot(ax, st.Rate_t/60, st.Rate_bph, 'Color', cols(v,:), 'LineWidth', 2);
    yline(ax, st.SettleBand_bph, ':', 'Color', cols(v,:), 'LineWidth', 1);
    % first soup and first packaged output sit at zero delivered rate -
    % the gap between them is the QC/packaging pipeline lag
    plot(ax, st.TimeToFirstSoup_s/60, 0, 'o', 'Color', cols(v,:), ...
        'MarkerFaceColor', surf_, 'MarkerSize', 7, 'LineWidth', 1.5);
    plot(ax, st.TimeToFirstOut_s/60, 0, 's', 'Color', cols(v,:), ...
        'MarkerFaceColor', cols(v,:), 'MarkerSize', 7);
    if ~isnan(st.TimeToNominal_s)
        plot(ax, st.TimeToNominal_s/60, st.SettleBand_bph, '^', ...
            'Color', cols(v,:), 'MarkerFaceColor', cols(v,:), 'MarkerSize', 8);
    end
end
yline(ax, 200, '--', 'SR-GS-002 floor (200 bph)', 'Color', th.limit, ...
    'LineWidth', 1, 'FontSize', 9, 'LabelHorizontalAlignment','left');
xlim(ax, [0 tMax]);
set(ax,'YGrid','on','GridColor',gridC,'GridAlpha',1,'Box','off','Color',surf_, ...
    'XColor',inkS,'YColor',inkS,'FontSize',10);
xlabel(ax,'Time from cold start (min)','Color',inkP);
ylabel(ax,'Trailing 5-min production rate (bph)','Color',inkP);
legend(ax, h, {beh.Variant}, 'Location','southeast','Box','off','TextColor',inkP);
% keep the title short enough not to clip at the axes width; the marker
% legend lives in the figure caption in docs/20
title(ax,'Cold start: ramp to sustained nominal production rate', ...
    'Color',inkP,'FontWeight','normal','FontSize',12);
exportgraphics(f, fullfile(figDir,'behavioral_startup.png'), 'Resolution', 200);
close(f);

fprintf('Behavioral analysis complete (architecture-level simulation):\n');
disp(struct2table(beh));
end

function soup = harvestSoup(out)
% Cook-stage soup flow from logsout. HyperCook and LeanBroth have a
% plant-wide merge point and log a single soupFlow_bps; EverSimmer's
% three cells never merge before packaging, so its per-cell signals are
% summed here to the same quantity (see buildInlineBehaviors).
ls = out.logsout;
names = string(ls.getElementNames());
if any(names == "soupFlow_bps")
    soup = ls.get('soupFlow_bps').Values;
    return
end
cells = names(startsWith(names, "soupFlow_Cell"));
assert(~isempty(cells), ['no cook-stage soup signal logged - re-run ' ...
    'behavior/build/buildInlineBehaviors and save the model']);
soup = ls.get(char(cells(1))).Values;
for k = 2:numel(cells)
    soup = soup + resample(ls.get(char(cells(k))).Values, soup.Time);
end
end

function [flow, tele] = harvest(out)
% root outports: OutboundShipments (bus with flow_bps) + Telemetry
flow = []; tele = [];
for i = 1:out.yout.numElements
    v = out.yout{i}.Values;
    if isstruct(v) && isfield(v, 'flow_bps'), flow = v.flow_bps; end
    if isstruct(v) && isfield(v, 'totalPower_kW'), tele = v; end
end
assert(~isempty(flow) && ~isempty(tele), 'root telemetry/shipments outputs missing');
end
