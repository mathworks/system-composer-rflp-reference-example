function trans = runTransportSweep()
%RUNTRANSPORTSWEEP Loading latency vs transport pickup capacity (SR-GS-006).
%   The requirement: packaged soup loaded onto transport within 10 minutes
%   (600 s). Loading latency = dock-queue wait + transit time. At nominal
%   pickup capacity every variant's queue is empty and latency equals its
%   transit time; this sweep derates the pickup rate to find where the
%   dock backlog pushes latency through the requirement ceiling - the
%   design-space margin question, analogous to the gravity sweep.
%
%   Produces transportResults.mat / transportSweep.csv and
%   docs/figures/transport_latency.png.

MULT = [1 0.8 0.6 0.4];
T_STOP = 14400; T_SS = 7200;
LIMIT_S = 600;

proj = currentProject;
anaDir = char(fullfile(proj.RootFolder, 'analysis', 'results'));
figDir = char(fullfile(proj.RootFolder, 'docs', 'figures'));

% nominal pickup rates from the behavior dictionaries (setupBehaviorData)
models = {'HyperCook','PhysicalHyperCook',400; 'LeanBroth','PhysicalLeanBroth',250; ...
          'EverSimmer','PhysicalEverSimmer',300};
nV = size(models,1); nM = numel(MULT);

lat = zeros(nV, nM);
for v = 1:nV
    clear in
    in(nM) = Simulink.SimulationInput(models{v,2}); %#ok<AGROW>
    for k = 1:nM
        s = Simulink.SimulationInput(models{v,2});
        s = s.setModelParameter('StopTime', num2str(T_STOP), ...
            'SaveOutput','on', 'SaveFormat','Dataset');
        s = s.setVariable('Transport_Rate_bph', models{v,3}*MULT(k), ...
            'Workspace', models{v,2});
        in(k) = s;
    end
    out = parsim(in, 'ShowProgress', 'off', 'ShowSimulationManager', 'off');
    for k = 1:nM
        assert(isempty(out(k).ErrorMessage), '%s x%g: %s', ...
            models{v,1}, MULT(k), out(k).ErrorMessage);
        lat(v,k) = loadLatency(out(k));
    end
    fprintf('%s swept\n', models{v,1});
end

trans.mult = MULT;
trans.variants = models(:,1)';
trans.nominalRate_bph = [models{:,3}];
trans.latency_s = lat;
trans.limit_s = LIMIT_S;
save(fullfile(anaDir, 'transportResults.mat'), 'trans');
T = array2table(lat', 'VariableNames', models(:,1)');
T = addvars(T, MULT', 'Before', 1, 'NewVariableNames', 'RateMultiplier');
writetable(T, fullfile(anaDir, 'transportSweep.csv'));

% ---- figure ----
palette = containers.Map({'HyperCook','LeanBroth','EverSimmer'}, ...
    {[42 120 214]/255, [27 175 122]/255, [237 161 0]/255});
surf_ = [252 252 251]/255; inkP = [11 11 11]/255; inkS = [82 81 78]/255;
gridC = [0.88 0.88 0.87];
f = figure('Visible','off','Color',surf_,'Position',[100 100 900 400]);
ax = axes(f); hold(ax,'on');
for v = 1:nV
    c = palette(models{v,1});
    plot(ax, MULT*100, lat(v,:)/60, '-o', 'Color', c, 'LineWidth', 2, ...
        'MarkerFaceColor', c, 'MarkerSize', 5);
end
yline(ax, LIMIT_S/60, '--', 'SR-GS-006 limit (10 min)', 'Color', [0.35 0.35 0.35], ...
    'LineWidth', 1.2, 'FontSize', 9, 'LabelHorizontalAlignment','left');
set(ax,'YScale','log','YGrid','on','GridColor',gridC,'GridAlpha',1,'Box','off', ...
    'Color',surf_,'XColor',inkS,'YColor',inkS,'FontSize',10,'XDir','reverse');
xlabel(ax,'Transport pickup capacity (% of nominal)','Color',inkP);
ylabel(ax,'Median loading latency (min, log)','Color',inkP);
legend(ax, models(:,1)', 'Location','northwest','Box','off','TextColor',inkP);
title(ax,'Loading latency as transport capacity derates', ...
    'Color',inkP,'FontWeight','normal','FontSize',12);
exportgraphics(f, fullfile(figDir,'transport_latency.png'), 'Resolution', 200);
close(f);

fprintf('Transport sweep (limit %d s):\n', LIMIT_S);
disp(array2table(lat, 'VariableNames', compose('x%.1f',MULT), 'RowNames', models(:,1)'));
end

function lagS = loadLatency(out)
% median mass-threshold lag between packed and loaded cumulative curves
lg = out.logsout;
pk = lg.get('packedFlow_bps').Values;
ld = lg.get('loadedFlow_bps').Values;
cumP = cumtrapz(pk.Time, pk.Data);
cumL = cumtrapz(ld.Time, ld.Data);
Xs = linspace(0.2, 0.8, 13) * min(cumP(end), cumL(end));
lag = zeros(size(Xs));
for k = 1:numel(Xs)
    tP = interp1(cumP + (1:numel(cumP))'*1e-9, pk.Time, Xs(k));
    tL = interp1(cumL + (1:numel(cumL))'*1e-9, ld.Time, Xs(k));
    lag(k) = tL - tP;
end
lagS = median(lag);
end
