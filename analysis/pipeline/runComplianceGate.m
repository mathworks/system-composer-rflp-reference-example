function gate = runComplianceGate()
%RUNCOMPLIANCEGATE Formally verify each variant against the SR gates.
%   Simulates the GalacticSoupComplianceGate Requirements Table model once
%   per variant, feeding the rolled-up metrics from variantMetrics.mat into
%   the gate's design-output inputs. Each formal requirement row logs a
%   status signal (0 = satisfied, 1 = violated at that timestep).
%
%   Returns a table (variant x gate) of logical pass flags and writes
%   complianceGate.csv. Errors if the formal results disagree with the
%   procedurally computed OK_* flags from runVariantAnalysis, so the two
%   compliance paths cross-check each other.

mdl = 'GalacticSoupComplianceGate';
proj = currentProject;
anaDir = char(fullfile(proj.RootFolder, 'analysis', 'results'));
S = load(fullfile(anaDir, 'variantMetrics.mat'));
R = S.results;

% Gate order must match the build script's gates list
gateNames = {'Mass','Power','Cost','Volume','Throughput','Automation', ...
             'Operators','Gravity'};
% Map gate -> (metric field, procedural flag field)
metricFields = {'Mass_kg','Power_kW','Cost_kCredits','Volume_m3', ...
                'Throughput_bph','AutomationAvg','OperatorsRequired','GravityMin'};
okFields = {'OK_Mass','OK_Power','OK_Cost','OK_Volume','OK_Throughput', ...
            'OK_Automation','OK_Operators','OK_Gravity'};
% Constant block names in the gate model, in input-port order
constNames = {'mass_kg','power_kW','cost_kCr','volume_m3','throughput_bph', ...
              'automationAvg','operators','gravityMin_g'};

load_system(mdl);
nV = numel(R);
pass = false(nV, numel(gateNames));

for v = 1:nV
    in = Simulink.SimulationInput(mdl);
    for k = 1:numel(constNames)
        in = in.setBlockParameter([mdl '/' constNames{k}], 'Value', ...
            num2str(R(v).(metricFields{k}), 17));
    end
    Simulink.sdi.clear;
    warning('off', 'Stateflow:Runtime:TestVerificationFailed');
    out = sim(in);
    warning('on', 'Stateflow:Runtime:TestVerificationFailed');

    % Collect R:<id> status signals; sorted numeric id = row creation order
    run = Simulink.sdi.getRun(Simulink.sdi.getAllRunIDs);
    ids = zeros(run.SignalCount, 1);
    vals = zeros(run.SignalCount, 1);
    for k = 1:run.SignalCount
        s = run.getSignalByIndex(k);
        tok = regexp(s.Name, '^R:(\d+)', 'tokens', 'once');
        assert(~isempty(tok), 'Unexpected SDI signal: %s', s.Name);
        ids(k) = str2double(tok{1});
        vals(k) = double(any(s.Values.Data));  % violated at any timestep
    end
    assert(numel(ids) == numel(gateNames), ...
        'Gate model logged %d rows, expected %d', numel(ids), numel(gateNames));
    [~, order] = sort(ids);
    pass(v,:) = vals(order)' == 0;

    % Cross-check against the procedural flags from runVariantAnalysis
    for k = 1:numel(okFields)
        assert(pass(v,k) == logical(R(v).(okFields{k})), ...
            '%s / %s: formal gate says %d, procedural flag says %d', ...
            R(v).Variant, gateNames{k}, pass(v,k), R(v).(okFields{k}));
    end
end

% close the gate model: its embedded requirement set blocks slreq.clear
% for any downstream code while the model remains loaded
close_system(mdl, 0);

gate = array2table(pass, 'VariableNames', gateNames, ...
    'RowNames', {R.Variant}');
gate.AllGatesPass = all(pass, 2);
writetable(gate, fullfile(anaDir, 'complianceGate.csv'), 'WriteRowNames', true);
fprintf('Formal compliance gate: %d/%d variant-gate checks pass, cross-check vs procedural flags OK\n', ...
    nnz(pass), numel(pass));
end
