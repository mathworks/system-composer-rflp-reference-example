function runUncertaintySims(variantName)
%RUNUNCERTAINTYSIMS Simulate one variant's parameter-uncertainty batch.
%   runUncertaintySims('LeanBroth') runs the N draws from uncertaintySpec
%   through the variant's architecture model with parsim, harvesting
%   steady-state throughput and energy per bowl, and saves
%   uncertaintySims_<Variant>.mat. Run once per variant, then
%   runUncertaintyStudy assembles and post-processes.
%
%   Parameter overrides go into the MODEL workspace, which shadows the
%   attached data dictionary entry of the same name, so the dictionaries
%   on disk are never touched.

spec = uncertaintySpec();
v = spec.variants.(variantName);
proj = currentProject;
anaDir = char(fullfile(proj.RootFolder, 'analysis', 'results'));

in(spec.N) = Simulink.SimulationInput(v.model); %#ok<AGROW>
for i = 1:spec.N
    s = Simulink.SimulationInput(v.model);
    s = s.setModelParameter('StopTime', num2str(spec.T_STOP), ...
        'SaveOutput','on', 'SaveFormat','Dataset');
    for j = 1:size(v.params,1)
        s = s.setVariable(v.params{j,1}, v.values(i,j), 'Workspace', v.model);
    end
    in(i) = s;
end

out = parsim(in, 'ShowProgress', 'on', 'ShowSimulationManager', 'off');

thr = nan(spec.N,1); energy = nan(spec.N,1);
for i = 1:spec.N
    assert(isempty(out(i).ErrorMessage), 'draw %d: %s', i, out(i).ErrorMessage);
    flow = []; tele = [];
    for k = 1:out(i).yout.numElements
        y = out(i).yout{k}.Values;
        if isstruct(y) && isfield(y,'flow_bps'), flow = y.flow_bps; end
        if isstruct(y) && isfield(y,'totalPower_kW'), tele = y; end
    end
    ss = flow.Time >= spec.T_SS;
    thr(i) = trapz(flow.Time(ss), flow.Data(ss)) / (flow.Time(end)-spec.T_SS) * 3600;
    bowls = trapz(flow.Time(ss), flow.Data(ss));
    pw = tele.totalPower_kW;
    pss = pw.Time >= spec.T_SS;
    energy(i) = (trapz(pw.Time(pss), pw.Data(pss))/3600) / bowls;
end

sims.variant = variantName;
sims.values = v.values;
sims.paramNames = v.params(:,1)';
sims.thr_bph = thr;
sims.energy_kWh_per_bowl = energy;
save(fullfile(anaDir, ['uncertaintySims_' variantName '.mat']), 'sims');
fprintf('%s: %d draws, throughput %.1f..%.1f bph (median %.1f)\n', ...
    variantName, spec.N, min(thr), max(thr), median(thr));
end
