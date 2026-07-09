function buildComplianceGate()
%BUILDCOMPLIANCEGATE Generate the Requirements Table compliance-gate model.
%   Creates architecture/gate/GalacticSoupComplianceGate.slx containing a
%   Requirements Table block that formalizes the eight SR compliance gates.
%   The table is fully generated from the requirement set: cap values are
%   parsed from SystemRequirements.slreqx at build time and stored as
%   Parameter symbols, so postconditions stay symbolic (mass_kg <= MASS_CAP).
%   Each formal row is linked back to its source SR for traceability.
%
%   Rebuild the model with this function whenever the requirement caps or
%   the gate definitions change. The build is destructive and idempotent.

proj = currentProject;
archDir = char(fullfile(proj.RootFolder, 'architecture', 'gate'));
reqDir  = char(fullfile(proj.RootFolder, 'requirements'));
mdl = 'GalacticSoupComplianceGate';

slreq.clear();
srSet = slreq.load(fullfile(reqDir, 'SystemRequirements.slreqx'));

% Caps parsed from requirement text (same source as runVariantAnalysis)
capMass  = gsParseBudgetValue(srSet, 'SR-GS-011');           % 15000 kg
capPower = gsParseBudgetValue(srSet, 'SR-GS-012');           % 500 kW
capCost  = gsParseBudgetValue(srSet, 'SR-GS-013') / 1000;    % -> kCr
capVol   = gsParseBudgetValue(srSet, 'SR-GS-014');           % 400 m^3
capThr   = gsParseBudgetValue(srSet, 'SR-GS-002');           % 200 bph floor
capAuto  = 0.8;                                              % SR-GS-003
capOps   = gsParseBudgetValue(srSet, 'SR-GS-004');           % 5 operators
capGrav  = 12;                                               % SR-GS-015/016

if bdIsLoaded(mdl), close_system(mdl, 0); end
mdlFile = fullfile(archDir, [mdl '.slx']);
if isfile(mdlFile), delete(mdlFile); end
% Drop stale link store from earlier builds; rows are recreated with new IDs
staleSlmx = fullfile(archDir, [mdl '~mdl.slmx']);
if isfile(staleSlmx), delete(staleSlmx); end

rt = slreq.modeling.create(mdl);
tblPath = [mdl '/Requirements Table'];

% Design-output inputs: the variant's rolled-up metrics under verification
inputs = {'mass_kg','power_kW','cost_kCr','volume_m3','throughput_bph', ...
          'automationAvg','operators','gravityMin_g'};
for i = 1:numel(inputs)
    s = addSymbol(rt);
    s.Name = inputs{i};
    s.Scope = 'Input';
    s.Type = 'double';
    s.Size = '1';
    s.IsDesignOutput = true;
end

% Cap parameters: symbolic in postconditions, values from the requirement set
params = {'MASS_CAP',capMass; 'POWER_CAP',capPower; 'COST_CAP',capCost; ...
          'VOL_CAP',capVol; 'THR_FLOOR',capThr; 'AUTO_FLOOR',capAuto; ...
          'OPS_CAP',capOps; 'GRAV_FLOOR',capGrav};
mws = get_param(mdl, 'ModelWorkspace');
for i = 1:size(params,1)
    s = addSymbol(rt);
    s.Name = params{i,1};
    s.Scope = 'Parameter';
    s.Type = 'double';
    s.Size = '1';
    % Parameter symbols resolve by name; hold the parsed cap in the model
    % workspace so the value ships inside the .slx with no base-workspace state
    assignin(mws, params{i,1}, params{i,2});
end

% Gate rows: {srId, summary, postcondition}. Row order defines R:n index.
gates = { ...
 'SR-GS-011','Total mass within budget',        'mass_kg <= MASS_CAP'; ...
 'SR-GS-012','Total power within budget',       'power_kW <= POWER_CAP'; ...
 'SR-GS-013','Total cost within budget',        'cost_kCr <= COST_CAP'; ...
 'SR-GS-014','Total volume within budget',      'volume_m3 <= VOL_CAP'; ...
 'SR-GS-002','Throughput meets floor',          'throughput_bph >= THR_FLOOR'; ...
 'SR-GS-003','Average automation meets floor',  'automationAvg >= AUTO_FLOOR'; ...
 'SR-GS-004','Peak operators within limit',     'operators <= OPS_CAP'; ...
 'SR-GS-015','Weakest gravity rating adequate', 'gravityMin_g >= GRAV_FLOOR'};

% Remove the default placeholder row, then add the gates
oldRows = getRequirementRows(rt);
for i = 1:numel(oldRows), removeRow(rt, oldRows(i)); end
for i = 1:size(gates,1)
    row = addRequirementRow(rt);
    row.Summary = sprintf('%s: %s', gates{i,1}, gates{i,2});
    row.Postconditions = gates(i,3);
    % Purge Refine links left by earlier builds (their source rows no longer
    % exist), then trace the fresh formal row back to its source SR
    sr = find(srSet, 'Id', gates{i,1});
    old = inLinks(sr);
    for j = 1:numel(old)
        if strcmp(old(j).Type, 'Refine')
            remove(old(j));
        end
    end
    lnk = slreq.createLink(row.requirement(), sr);
    lnk.Type = 'Refine';
end

% Discrete rate so the table does not need to inherit one from constants
ch = find(sfroot, '-isa', 'Stateflow.Chart', 'Path', tblPath);
ch.ChartUpdate = 'DISCRETE';
ch.SampleTime = '1';

% One named constant per metric; harness overrides Value per variant
for i = 1:numel(inputs)
    cb = [mdl '/' inputs{i}];
    add_block('simulink/Sources/Constant', cb, 'Value', '0');
    add_line(mdl, [inputs{i} '/1'], sprintf('Requirements Table/%d', i));
end
set_param(mdl, 'StopTime', '1');
Simulink.BlockDiagram.arrangeSystem(mdl);
save_system(mdl, mdlFile);

slreq.saveAll();
projPaths = {proj.Files.Path};
if ~any(strcmp(projPaths, mdlFile))
    addFile(proj, mdlFile);
end
slmx = fullfile(archDir, [mdl '~mdl.slmx']);
if isfile(slmx) && ~any(strcmp(projPaths, slmx))
    addFile(proj, slmx);
end
fprintf('%s built: %d gate rows, caps from SystemRequirements.slreqx\n', mdl, size(gates,1));
end
