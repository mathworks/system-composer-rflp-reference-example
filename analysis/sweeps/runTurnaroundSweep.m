function turn = runTurnaroundSweep()
%RUNTURNAROUNDSWEEP Rocket turnaround vs shipment size (SR-GS-018).
%   Turnaround = time to load one rocket (Rocket_Load_bowls drawn from
%   the loaded-shipment flow) + Rocket_Handling_s of dock/undock overhead;
%   the requirement caps it at 20 minutes (1200 s). One nominal simulation
%   per variant supplies the loaded-flow record; fill time for ANY
%   shipment size falls out of the same cumulative curve, so the sweep
%   over R = [40 60 80 120] bowls costs three simulations total.
%
%   Produces turnaroundResults.mat / turnaroundSweep.csv.

R_PTS = [40 60 80 120];
HANDLING = 120; LIMIT = 1200;
T_STOP = 14400; T_SS = 7200;

proj = currentProject;
anaDir = char(fullfile(proj.RootFolder, 'analysis', 'results'));

models = {'HyperCook','PhysicalHyperCook'; 'LeanBroth','PhysicalLeanBroth'; ...
          'EverSimmer','PhysicalEverSimmer'};
nV = size(models,1);

fill_s = zeros(nV, numel(R_PTS));
for v = 1:nV
    in = Simulink.SimulationInput(models{v,2});
    in = in.setModelParameter('StopTime', num2str(T_STOP), ...
        'SaveOutput','on', 'SaveFormat','Dataset');
    out = sim(in);
    ld = out.logsout.get('loadedFlow_bps').Values;
    cumL = cumtrapz(ld.Time, ld.Data) + (1:numel(ld.Time))'*1e-9;
    for k = 1:numel(R_PTS)
        % median fill time over steady-state start points
        starts = linspace(0.3, 0.7, 11) * cumL(end);
        ft = zeros(size(starts));
        for j = 1:numel(starts)
            t0 = interp1(cumL, ld.Time, starts(j));
            t1 = interp1(cumL, ld.Time, starts(j) + R_PTS(k));
            ft(j) = t1 - t0;
        end
        fill_s(v,k) = median(ft);
    end
    fprintf('%s: fill %s s for R=%s\n', models{v,1}, ...
        mat2str(round(fill_s(v,:))), mat2str(R_PTS));
end

turn.R_bowls = R_PTS;
turn.variants = models(:,1)';
turn.fill_s = fill_s;
turn.handling_s = HANDLING;
turn.turnaround_s = fill_s + HANDLING;
turn.limit_s = LIMIT;
save(fullfile(anaDir, 'turnaroundResults.mat'), 'turn');
T = array2table((fill_s + HANDLING)', 'VariableNames', models(:,1)');
T = addvars(T, R_PTS', 'Before', 1, 'NewVariableNames', 'Rocket_Load_bowls');
writetable(T, fullfile(anaDir, 'turnaroundSweep.csv'));

fprintf('Turnaround (fill + %d s handling) vs %d s limit:\n', HANDLING, LIMIT);
disp(array2table(turn.turnaround_s, 'VariableNames', compose('R%d',R_PTS), ...
    'RowNames', models(:,1)'));
end
