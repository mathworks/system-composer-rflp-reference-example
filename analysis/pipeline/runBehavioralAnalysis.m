function beh = runBehavioralAnalysis()
%RUNBEHAVIORALANALYSIS Simulate the three physical ARCHITECTURE models
%   (behavior lives inline in the System Composer components, ADR-020)
%   and extract the metrics that feed the trade study at higher fidelity
%   than the static stage-table roll-up:
%
%     SimThroughput_bph   steady-state packaged throughput at the root
%                         OutboundShipments.flow_bps port, nominal run
%     TimeToFirstOut_s    cold-start time until packaged flow appears
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

    ss = flow.Time >= T_SS;
    r.Variant = plants{v,1};
    r.SimThroughput_bph = trapz(flow.Time(ss), flow.Data(ss)) ...
                          / (flow.Time(end) - T_SS) * 3600;
    firstIdx = find(flow.Data > 1e-3, 1);
    assert(~isempty(firstIdx), '%s produced no output', mdl);
    r.TimeToFirstOut_s = flow.Time(firstIdx);
    bowlsSS  = trapz(flow.Time(ss), flow.Data(ss));
    pw = tele.totalPower_kW;
    energySS = trapz(pw.Time(pw.Time >= T_SS), pw.Data(pw.Time >= T_SS)) / 3600;
    r.Energy_kWh_per_bowl = energySS / bowlsSS;
    r.MeanPower_kW = mean(pw.Data(pw.Time >= T_SS));
    r.PeakPower_kW = max(pw.Data);
    assert(tele.plantMode.Data(end) == 1, '%s not Nominal at end of clean run', mdl);

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

fprintf('Behavioral analysis complete (architecture-level simulation):\n');
disp(struct2table(beh));
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
