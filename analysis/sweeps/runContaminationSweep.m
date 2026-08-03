function contam = runContaminationSweep()
%RUNCONTAMINATIONSWEEP Contamination detection across the design space.
%   Sweeps contamination incidence over [0.5% 1% 2% 5%] for all three
%   architecture models (SR-GS-007: detect contamination before sealing
%   with >= 99% sensitivity), plus one boundary case with the detector
%   derated to the requirement floor itself (sensitivity 0.99, EverSimmer).
%   Measured sensitivity comes from the logged QC signals:
%   detected/(detected+escaped) integrated over the run.
%
%   Produces contaminationResults.mat / contaminationSweep.csv and
%   docs/figures/contamination_sensitivity.png.

INC = [0.005 0.01 0.02 0.05];
T_STOP = 14400; T_SS = 7200;

proj = currentProject;
anaDir = char(fullfile(proj.RootFolder, 'analysis', 'results'));
figDir = char(fullfile(proj.RootFolder, 'docs', 'figures'));
M = load(fullfile(anaDir, 'variantMetrics.mat'));
floorBph = M.caps.Throughput_bph;

models = {'HyperCook','PhysicalHyperCook'; 'LeanBroth','PhysicalLeanBroth'; ...
          'EverSimmer','PhysicalEverSimmer'};
nV = size(models,1); nI = numel(INC);

sens = zeros(nV, nI); thr = zeros(nV, nI); escppm = zeros(nV, nI);
for v = 1:nV
    clear in
    in(nI) = Simulink.SimulationInput(models{v,2}); %#ok<AGROW>
    for k = 1:nI
        s = Simulink.SimulationInput(models{v,2});
        s = s.setModelParameter('StopTime', num2str(T_STOP), ...
            'SaveOutput','on', 'SaveFormat','Dataset');
        s = s.setVariable('QC_ContamIncidence', INC(k), 'Workspace', models{v,2});
        in(k) = s;
    end
    out = parsim(in, 'ShowProgress', 'off', 'ShowSimulationManager', 'off');
    for k = 1:nI
        assert(isempty(out(k).ErrorMessage), '%s inc %g: %s', ...
            models{v,1}, INC(k), out(k).ErrorMessage);
        [sens(v,k), thr(v,k), escppm(v,k)] = harvest(out(k), T_SS);
    end
    fprintf('%s swept\n', models{v,1});
end

% boundary case: detector AT the requirement floor (EverSimmer, 2% incidence)
in = Simulink.SimulationInput('PhysicalEverSimmer');
in = in.setModelParameter('StopTime', num2str(T_STOP), 'SaveOutput','on', 'SaveFormat','Dataset');
in = in.setVariable('QC_ContamIncidence', 0.02, 'Workspace', 'PhysicalEverSimmer');
in = in.setVariable('QC_DetectSensitivity', 0.99, 'Workspace', 'PhysicalEverSimmer');
out = sim(in);
[sensFloor, ~, ~] = harvest(out, T_SS);

contam.incidence = INC;
contam.variants = models(:,1)';
contam.sensitivity = sens;
contam.thr_bph = thr;
contam.escaped_ppm = escppm;
contam.floorCaseSensitivity = sensFloor;
contam.designSensitivity = 0.995;
contam.reqFloor = 0.99;
save(fullfile(anaDir, 'contaminationResults.mat'), 'contam');
T = table; T.Incidence = INC';
for v = 1:nV
    T.([models{v,1} '_sens']) = sens(v,:)';
    T.([models{v,1} '_bph'])  = thr(v,:)';
end
writetable(T, fullfile(anaDir, 'contaminationSweep.csv'));

% ---- figure ----
th = gsPlotTheme();   % dark house style; colors by variant name
palette = th.palette;
surf_ = th.surface; inkP = th.inkP; inkS = th.inkS; gridC = th.grid;
f = figure('Visible','off','Color',surf_,'Position',[100 100 900 400]);
ax = axes(f); hold(ax,'on');
for v = 1:nV
    c = palette(models{v,1});
    plot(ax, INC*100, sens(v,:)*100, '-o', 'Color', c, 'LineWidth', 2, ...
        'MarkerFaceColor', c, 'MarkerEdgeColor', surf_, 'MarkerSize', 6);
end
yline(ax, 99, '--', 'SR-GS-007 floor (99%)', 'Color', th.limit, ...
    'LineWidth', 1.2, 'FontSize', 9, 'LabelHorizontalAlignment','left');
% all three variants share the 0.995 design sensitivity, so the three
% lines coincide exactly - say so, or the chart reads as one series
text(ax, 2.75, 99.56, 'all three variants coincide (0.995 design sensitivity)', ...
    'Color', inkS, 'FontSize', 9, 'HorizontalAlignment','center');
set(ax,'YGrid','on','GridColor',gridC,'GridAlpha',1,'Box','off','Color',surf_, ...
    'XColor',inkS,'YColor',inkS,'FontSize',10);
ylim(ax, [98.5 100]);
xlabel(ax,'Contamination incidence (% of cooked flow)','Color',inkP);
ylabel(ax,'Measured detection sensitivity (%)','Color',inkP);
legend(ax, models(:,1)', 'Location','southeast','Box','off','TextColor',inkP);
title(ax,'QC contamination detection sensitivity across the incidence sweep', ...
    'Color',inkP,'FontWeight','normal','FontSize',12);
exportgraphics(f, fullfile(figDir,'contamination_sensitivity.png'), 'Resolution', 200);
close(f);

fprintf('Contamination sweep (design sensitivity %.3f, floor %.2f):\n', 0.995, 0.99);
disp(array2table(sens, 'VariableNames', compose('inc%.1f%%',INC*100), 'RowNames', models(:,1)'));
fprintf('floor-boundary case (ES, sens 0.99, 2%% inc): measured %.4f\n', sensFloor);
fprintf('throughput at 5%% incidence: %s (floor %g)\n', ...
    strjoin(compose('%s %.1f', string(models(:,1)), thr(:,end)), ', '), floorBph);
end

function [sens, thr, escppm] = harvest(out, T_SS)
lg = out.logsout;
det = lg.get('contamDetected_bps').Values;
esc = lg.get('contamEscaped_bps').Values;
dTot = trapz(det.Time, det.Data);
eTot = trapz(esc.Time, esc.Data);
sens = dTot / (dTot + eTot);
flow = [];
for i = 1:out.yout.numElements
    y = out.yout{i}.Values;
    if isstruct(y) && isfield(y,'flow_bps'), flow = y.flow_bps; end
end
ss = flow.Time >= T_SS;
thr = trapz(flow.Time(ss), flow.Data(ss)) / (flow.Time(end)-T_SS) * 3600;
packTot = trapz(flow.Time, flow.Data);
escppm = eTot / packTot * 1e6;
end
