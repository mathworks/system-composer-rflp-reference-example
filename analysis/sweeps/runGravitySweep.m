function grav = runGravitySweep()
%RUNGRAVITYSWEEP Throughput vs ambient gravity across SR-GS-015's range.
%   Simulates all three architecture models at gravity points spanning the
%   required 0.1 g..12 g operating range (SR-GS-015), with the gravity
%   physics built into the inline behaviors (ADR-026): batch vat drain
%   rate scales with sqrt(g) (Torricelli), robotic prep derates gently
%   above 4 g, and LeanBroth's human-paced prep derates from 2 g.
%   Continuous pumped cook lines are gravity-insensitive by design.
%
%   Produces gravityResults.mat / gravitySweep.csv and
%   docs/figures/gravity_throughput.png, and prints each variant's
%   compliant gravity range against the requirement-parsed floor.

G_PTS = [0.1 0.25 0.5 1 2 4 8 12];
T_STOP = 14400; T_SS = 7200;

proj = currentProject;
anaDir = char(fullfile(proj.RootFolder, 'analysis', 'results'));
figDir = char(fullfile(proj.RootFolder, 'docs', 'figures'));

M = load(fullfile(anaDir, 'variantMetrics.mat'));
floorBph = M.caps.Throughput_bph;

models = {'HyperCook','PhysicalHyperCook'; 'LeanBroth','PhysicalLeanBroth'; ...
          'EverSimmer','PhysicalEverSimmer'};
nV = size(models,1); nG = numel(G_PTS);

% parsim requires a single model per input array: one batch per variant
thr = zeros(nV, nG);
for v = 1:nV
    clear in
    in(nG) = Simulink.SimulationInput(models{v,2}); %#ok<AGROW>
    for gi = 1:nG
        s = Simulink.SimulationInput(models{v,2});
        s = s.setModelParameter('StopTime', num2str(T_STOP), ...
            'SaveOutput','on', 'SaveFormat','Dataset');
        s = s.setVariable('Gravity_g', G_PTS(gi), 'Workspace', models{v,2});
        in(gi) = s;
    end
    out = parsim(in, 'ShowProgress', 'off', 'ShowSimulationManager', 'off');
    for gi = 1:nG
        assert(isempty(out(gi).ErrorMessage), '%s at %g g: %s', ...
            models{v,1}, G_PTS(gi), out(gi).ErrorMessage);
        flow = [];
        for i = 1:out(gi).yout.numElements
            y = out(gi).yout{i}.Values;
            if isstruct(y) && isfield(y,'flow_bps'), flow = y.flow_bps; end
        end
        ss = flow.Time >= T_SS;
        thr(v,gi) = trapz(flow.Time(ss), flow.Data(ss)) / (flow.Time(end)-T_SS) * 3600;
    end
    fprintf('%s swept\n', models{v,1});
end

grav.g = G_PTS;
grav.variants = models(:,1)';
grav.thr_bph = thr;
grav.floor_bph = floorBph;
grav.compliant = thr >= floorBph;
save(fullfile(anaDir, 'gravityResults.mat'), 'grav');
T = array2table(thr', 'VariableNames', models(:,1)');
T = addvars(T, G_PTS', 'Before', 1, 'NewVariableNames', 'Gravity_g');
writetable(T, fullfile(anaDir, 'gravitySweep.csv'));

% ---- figure (house style) ----
palette = containers.Map( ...
    {'HyperCook','LeanBroth','EverSimmer'}, ...
    {[42 120 214]/255, [27 175 122]/255, [237 161 0]/255});
surf_ = [252 252 251]/255; inkP = [11 11 11]/255; inkS = [82 81 78]/255;
gridC = [0.88 0.88 0.87];

f = figure('Visible','off','Color',surf_,'Position',[100 100 900 420]);
ax = axes(f); hold(ax,'on');
for v = 1:nV
    c = palette(models{v,1});
    plot(ax, G_PTS, thr(v,:), '-o', 'Color', c, 'LineWidth', 2, ...
        'MarkerFaceColor', c, 'MarkerSize', 5);
end
yline(ax, floorBph, '--', 'SR-GS-002 floor (200 bph)', 'Color', [0.35 0.35 0.35], ...
    'LineWidth', 1.2, 'FontSize', 9, 'LabelHorizontalAlignment','left');
set(ax,'XScale','log','XTick',G_PTS, 'XTickLabel',compose('%.2g',G_PTS), ...
    'YGrid','on','GridColor',gridC,'GridAlpha',1,'Box','off','Color',surf_, ...
    'XColor',inkS,'YColor',inkS,'FontSize',10);
xlabel(ax,'Ambient gravity (g, log scale)','Color',inkP);
ylabel(ax,'Steady-state packaged throughput (bph)','Color',inkP);
legend(ax, models(:,1)', 'Location','southeast','Box','off','TextColor',inkP);
title(ax,'Throughput across the SR-GS-015 gravity range (0.1 g to 12 g)', ...
    'Color',inkP,'FontWeight','normal','FontSize',12);
exportgraphics(f, fullfile(figDir,'gravity_throughput.png'), 'Resolution', 200);
close(f);

fprintf('Gravity sweep (floor %.0f bph):\n', floorBph);
for v = 1:nV
    ok = grav.compliant(v,:);
    if all(ok), rng_ = 'compliant across the full 0.1-12 g range';
    else
        rng_ = sprintf('compliant at [%s] g, NOT at [%s] g', ...
            strjoin(compose('%.2g', G_PTS(ok)), ' '), ...
            strjoin(compose('%.2g', G_PTS(~ok)), ' '));
    end
    fprintf('  %-10s %s\n', models{v,1}, rng_);
end
end
