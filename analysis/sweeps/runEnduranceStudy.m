function endr = runEnduranceStudy()
%RUNENDURANCESTUDY Ingredient-storage endurance vs SR-GS-021 (72 hours).
%   Post-ADR-032: stores are sized for 72 h at each variant's nominal rate
%   (22300 / 14300 / 16800 bowls) and consumables are excluded from the
%   SR-GS-011 mass budget. This study fills the stores, cuts resupply at
%   t = 3600 s (Resupply_Cutoff_T), observes 12 h of unsupplied production,
%   and verifies: (a) production never starves inside the window, and
%   (b) projected endurance = capacity / measured unsupplied rate >= 72 h.
%   (Simulating the full 72 h drain-down would cost ~20x the wall time for
%   no additional information: the drain rate IS the production rate.)
%
%   The pre-ADR-032 FINDING this study originally recorded: 6.41/4.66/5.44 h
%   endurance on buffer-sized stores, and a requirements conflict with the
%   mass budget - see docs/18 and ADR-030/-032.
%
%   Produces enduranceResults.mat / enduranceSummary.csv.

CUTOFF = 3600; T_STOP = 46800;   % 12 h of post-cutoff observation

proj = currentProject;
anaDir = char(fullfile(proj.RootFolder, 'analysis', 'results'));

% {variant, model, init var, cap bowls, nominal bph}
models = {'HyperCook','PhysicalHyperCook','HC_StorageInit_bowls',22300,308.4; ...
          'LeanBroth','PhysicalLeanBroth','LB_StorageInit_bowls',14300,196.8; ...
          'EverSimmer','PhysicalEverSimmer','ES_StorageInit_bowls',16800,231.9};
nV = size(models,1);

projected_h = zeros(nV,1); stillProducing = false(nV,1); rate_bph = zeros(nV,1);
for v = 1:nV
    s = Simulink.SimulationInput(models{v,2});
    s = s.setModelParameter('StopTime', num2str(T_STOP), ...
        'SaveOutput','on', 'SaveFormat','Dataset');
    s = s.setVariable('Resupply_Cutoff_T', CUTOFF, 'Workspace', models{v,2});
    s = s.setVariable(models{v,3}, models{v,4}, 'Workspace', models{v,2});
    out = sim(s);
    flow = [];
    for i = 1:out.yout.numElements
        y = out.yout{i}.Values;
        if isstruct(y) && isfield(y,'flow_bps'), flow = y.flow_bps; end
    end
    % still producing at window end? (last productive instant near T_STOP;
    % batch gaps make an exact-end check flaky, allow one batch period)
    lastIdx = find(flow.Data*3600 > 20, 1, 'last');
    stillProducing(v) = flow.Time(lastIdx) > T_STOP - 2400;
    post = flow.Time > CUTOFF;
    rate_bph(v) = trapz(flow.Time(post), flow.Data(post)) / (T_STOP - CUTOFF) * 3600;
    projected_h(v) = models{v,4} / rate_bph(v);
    fprintf('%s: unsupplied rate %.1f bph, projected endurance %.1f h (req 72)\n', ...
        models{v,1}, rate_bph(v), projected_h(v));
end

endr.variants = models(:,1)';
endr.storageCap_bowls = cell2mat(models(:,4))';
endr.unsuppliedRate_bph = rate_bph';
endr.projected_h = projected_h';
endr.stillProducingAtWindowEnd = stillProducing';
endr.required_h = 72;
endr.compliant = projected_h' >= 72 & stillProducing';
save(fullfile(anaDir, 'enduranceResults.mat'), 'endr');
writetable(table(models(:,1), cell2mat(models(:,4)), projected_h, stillProducing, ...
    'VariableNames', {'Variant','StorageCap_bowls','ProjectedEndurance_h','StillProducing'}), ...
    fullfile(anaDir, 'enduranceSummary.csv'));
end
