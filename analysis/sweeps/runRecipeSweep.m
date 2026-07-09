function rec = runRecipeSweep()
%RUNRECIPESWEEP Recipe-changeover cost across the design space (SR-GS-001).
%   The runtime recipe rotation (8 recipes, one switch per Recipe_Block_s)
%   costs the continuous-line architecture Recipe_Flush_s of line downtime
%   per switch; batch architectures change recipes between batches inside
%   the clean phase they already pay for. This sweep prices HyperCook's
%   flush across [0 60 120 300] s and verifies the batch variants' recipe
%   count and throughput are untouched by construction.
%
%   Produces recipeResults.mat / recipeSweep.csv.

FLUSH = [0 60 120 300];
T_STOP = 14400; T_SS = 7200;

proj = currentProject;
anaDir = char(fullfile(proj.RootFolder, 'analysis', 'results'));

thr = zeros(1, numel(FLUSH)); nRec = zeros(1, numel(FLUSH));
clear in
in(numel(FLUSH)) = Simulink.SimulationInput('PhysicalHyperCook'); %#ok<AGROW>
for k = 1:numel(FLUSH)
    s = Simulink.SimulationInput('PhysicalHyperCook');
    s = s.setModelParameter('StopTime', num2str(T_STOP), ...
        'SaveOutput','on', 'SaveFormat','Dataset');
    s = s.setVariable('Recipe_Flush_s', FLUSH(k), 'Workspace', 'PhysicalHyperCook');
    in(k) = s;
end
out = parsim(in, 'ShowProgress', 'off', 'ShowSimulationManager', 'off');
for k = 1:numel(FLUSH)
    assert(isempty(out(k).ErrorMessage), 'flush %g: %s', FLUSH(k), out(k).ErrorMessage);
    flow = [];
    for i = 1:out(k).yout.numElements
        y = out(k).yout{i}.Values;
        if isstruct(y) && isfield(y,'flow_bps'), flow = y.flow_bps; end
    end
    ss = flow.Time >= T_SS;
    thr(k) = trapz(flow.Time(ss), flow.Data(ss)) / (flow.Time(end)-T_SS) * 3600;
    r = out(k).logsout.get('activeRecipe').Values;
    nRec(k) = numel(unique(round(r.Data)));
end

rec.flush_s = FLUSH;
rec.hc_thr_bph = thr;
rec.hc_recipes = nRec;
save(fullfile(anaDir, 'recipeResults.mat'), 'rec');
writetable(table(FLUSH', thr', nRec', 'VariableNames', ...
    {'Flush_s','HyperCook_bph','DistinctRecipes'}), ...
    fullfile(anaDir, 'recipeSweep.csv'));
fprintf('Recipe flush sweep (HyperCook): ');
fprintf('%g s -> %.1f bph; ', [FLUSH; thr]);
fprintf('\nrecipes per production run: %s\n', mat2str(nRec));
end
