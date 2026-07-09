function results = runVariantAnalysis()
%RUNVARIANTANALYSIS Roll up quantitative metrics for all three physical
%   architecture variants and evaluate them against the SR budget caps.
%
%   Returns a struct array (one element per variant) and writes
%   variantMetrics.mat / variantMetrics.csv next to this file.
%
%   Metrics:
%     Mass, Power, Cost, Volume, Operators  - PostOrder roll-up sums
%     Throughput                            - serial-chain min over stage
%                                             capacities (parallel units sum;
%                                             composite cells take interior min)
%     AutomationAvg                         - mean over leaf components (SR-GS-003)
%     Availability                          - production-continuity availability,
%                                             MTTR = 24 h, parallel stages need
%                                             any one unit up
%     N1Retention                           - worst-case single-fault capacity
%                                             retention across processing stages
%     GravityMin                            - min gravity rating over leaves

prefix = 'GalacticSoupProfile.PhysicalProperties.';
MTTR_HR = 24;

proj = currentProject;
reqDir = char(fullfile(proj.RootFolder, 'requirements'));
anaDir = char(fullfile(proj.RootFolder, 'analysis', 'results'));

% Budget caps parsed from requirement text (kept in sync with .slreqx)
slreq.clear();
srSet = slreq.load(fullfile(reqDir, 'SystemRequirements.slreqx'));
caps.Mass_kg        = gsParseBudgetValue(srSet, 'SR-GS-011');          % 15000 kg
caps.Power_kW       = gsParseBudgetValue(srSet, 'SR-GS-012');          % 500 kW
caps.Cost_kCredits  = gsParseBudgetValue(srSet, 'SR-GS-013') / 1000;   % credits -> kCr
caps.Volume_m3      = gsParseBudgetValue(srSet, 'SR-GS-014');          % 400 m^3
caps.Throughput_bph = gsParseBudgetValue(srSet, 'SR-GS-002');          % >= 200 bph
caps.Automation     = 0.8;                                             % SR-GS-003
caps.Operators      = gsParseBudgetValue(srSet, 'SR-GS-004');          % <= 5
caps.Gravity_g      = 12;                                              % SR-GS-015/016

% Stage tables: {stageName, {members}, isParallel, isProcessing}
% Composite members (EverSimmer cells) resolve capacity as interior chain min.
stages.HyperCook = { ...
    'receive',  {'CargoGantryDock'},                        false, false; ...
    'storage',  {'ColdStorageVault','AmbientStorageSilo'},  true,  false; ...
    'prep',     {'RoboticPrepLine1','RoboticPrepLine2'},    true,  true; ...
    'cook',     {'ContinuousCookLine1','ContinuousCookLine2','ContinuousCookLine3','ContinuousCookLine4'}, true, true; ...
    'qc',       {'InlineQCScanner'},                        false, true; ...
    'pack',     {'HighSpeedPackagingLine'},                 false, true; ...
    'transport',{'ConveyorNetwork'},                        false, false; ...
    'dispatch', {'CargoLoaderGantry'},                      false, false; ...
    'fleet',    {'LaunchPadComplex'},                       false, false};
support.HyperCook = {'CentralControlComputer','FusionPowerPlant','GravityCompensatorArray'};

stages.LeanBroth = { ...
    'receive',  {'ManualReceivingBay'},                     false, false; ...
    'storage',  {'ColdStoreLocker','DryGoodsRack'},         true,  false; ...
    'prep',     {'PrepWorkstation'},                        false, true; ...
    'cook',     {'BatchKettle1','BatchKettle2'},            true,  true; ...
    'qc',       {'QCBench'},                                false, true; ...
    'pack',     {'SemiAutoPackager'},                       false, true; ...
    'transport',{'AGVCartPool'},                            false, false; ...
    'dispatch', {'SharedCraneDock'},                        false, false; ...
    'fleet',    {'TriPadLandingField'},                     false, false};
support.LeanBroth = {'OpsConsole','CompactFissionReactor','GravityCompUnit'};

stages.EverSimmer = { ...
    'receive',  {'AutoDock'},                               false, false; ...
    'storage',  {'DualZoneStore'},                          false, false; ...
    'cells',    {'ProductionCell1','ProductionCell2','ProductionCell3'}, true, true; ...
    'transport',{'RoboTransportSwarm'},                     false, false; ...
    'dispatch', {'AutoCargoLoader'},                        false, false; ...
    'fleet',    {'TriplePadPort'},                          false, false};
support.EverSimmer = {'ControlTriad','RedundantReactorPair','GravityCompMesh'};

variants = {'HyperCook','PhysicalHyperCook'; 'LeanBroth','PhysicalLeanBroth'; 'EverSimmer','PhysicalEverSimmer'};
results = struct([]);

for v = 1:size(variants, 1)
    vname = variants{v,1};
    model = systemcomposer.loadModel(variants{v,2});
    instance = instantiate(model.Architecture, 'GalacticSoupProfile', [vname 'Analysis']);
    iterate(instance, 'PostOrder', @gsRollup);

    r.Variant = vname;
    r.Model = variants{v,2};

    % Budget sums from top-level children after roll-up
    for pn = {'Mass_kg','Power_kW','Cost_kCredits','Volume_m3','OperatorsRequired'}
        s = 0;
        for c = instance.Components
            if c.hasValue([prefix pn{1}])
                s = s + c.getValue([prefix pn{1}]);
            end
        end
        r.(pn{1}) = s;
    end

    % Leaf-based metrics
    leaves = gsCollectLeaves(instance);
    autoVals = cellfun(@(L) L.getValue([prefix 'AutomationLevel']), leaves);
    gravVals = cellfun(@(L) L.getValue([prefix 'GravityRating_g']), leaves);
    r.AutomationAvg = mean(autoVals);
    r.GravityMin = min(gravVals);
    r.LeafCount = numel(leaves);

    % Stage capacities, availability, N-1 retention
    st = stages.(vname);
    nStages = size(st, 1);
    stageCap = zeros(nStages, 1);
    stageAvail = zeros(nStages, 1);
    unitCaps = cell(nStages, 1);
    for s = 1:nStages
        members = st{s,2};
        caps_s = zeros(numel(members), 1);
        avail_s = zeros(numel(members), 1);
        for k = 1:numel(members)
            comp = [];
            for c = instance.Components
                if strcmp(c.Name, members{k}), comp = c; break; end
            end
            assert(~isempty(comp), 'Component %s not found in %s', members{k}, vname);
            if isempty(comp.Components)
                caps_s(k) = comp.getValue([prefix 'Throughput_bph']);
                mtbf = comp.getValue([prefix 'MTBF_hr']);
                avail_s(k) = mtbf / (mtbf + MTTR_HR);
            else
                % composite (production cell): capacity = interior chain min
                % over production-path leaves; availability = product (serial)
                subLeaves = gsCollectLeaves(comp);
                thr = []; av = 1;
                for L = 1:numel(subLeaves)
                    if subLeaves{L}.getValue([prefix 'IsProductionPath']) > 0
                        thr(end+1) = subLeaves{L}.getValue([prefix 'Throughput_bph']); %#ok<AGROW>
                    end
                    mtbf = subLeaves{L}.getValue([prefix 'MTBF_hr']);
                    av = av * (mtbf / (mtbf + MTTR_HR));
                end
                caps_s(k) = min(thr);
                avail_s(k) = av;
            end
        end
        unitCaps{s} = caps_s;
        if st{s,3}  % parallel
            stageCap(s) = sum(caps_s);
            stageAvail(s) = 1 - prod(1 - avail_s);
        else
            stageCap(s) = min(caps_s);
            stageAvail(s) = prod(avail_s);
        end
    end
    r.Throughput_bph = min(stageCap);

    % Availability includes support components (control, power, gravity comp)
    availSys = prod(stageAvail);
    for k = 1:numel(support.(vname))
        comp = [];
        for c = instance.Components
            if strcmp(c.Name, support.(vname){k}), comp = c; break; end
        end
        mtbf = comp.getValue([prefix 'MTBF_hr']);
        availSys = availSys * (mtbf / (mtbf + MTTR_HR));
    end
    r.Availability = availSys;

    % N-1 retention: worst single-unit loss across processing stages
    worst = inf;
    for s = 1:nStages
        if ~st{s,4}, continue; end
        degraded = stageCap(s) - max(unitCaps{s});
        worst = min(worst, degraded / r.Throughput_bph);
    end
    r.N1Retention = max(0, min(1, worst));

    % Behavioral override: when simulated plant metrics exist (see
    % runBehavioralAnalysis), they replace the static stage-table
    % throughput and N-1 retention. The static values are kept in
    % Static_* fields for comparison; the OK_* gates and margins below
    % always evaluate whichever values ended up in the primary fields.
    r.Static_Throughput_bph = r.Throughput_bph;
    r.Static_N1Retention    = r.N1Retention;
    r.BehavioralSource      = false;
    r.Energy_kWh_per_bowl   = NaN;
    r.TimeToFirstOut_s      = NaN;
    behFile = fullfile(anaDir, 'behavioralMetrics.mat');
    if isfile(behFile)
        B = load(behFile);
        bi = strcmp({B.beh.Variant}, vname);
        assert(nnz(bi) == 1, 'behavioralMetrics.mat has no entry for %s', vname);
        r.Throughput_bph      = B.beh(bi).SimThroughput_bph;
        r.N1Retention         = B.beh(bi).SimRetention;
        r.Energy_kWh_per_bowl = B.beh(bi).Energy_kWh_per_bowl;
        r.TimeToFirstOut_s    = B.beh(bi).TimeToFirstOut_s;
        r.BehavioralSource    = true;
    end

    % Compliance gates
    r.OK_Mass       = r.Mass_kg <= caps.Mass_kg;
    r.OK_Power      = r.Power_kW <= caps.Power_kW;
    r.OK_Cost       = r.Cost_kCredits <= caps.Cost_kCredits;
    r.OK_Volume     = r.Volume_m3 <= caps.Volume_m3;
    r.OK_Throughput = r.Throughput_bph >= caps.Throughput_bph;
    r.OK_Automation = r.AutomationAvg >= caps.Automation - 1e-9;
    r.OK_Operators  = r.OperatorsRequired <= caps.Operators;
    r.OK_Gravity    = r.GravityMin >= caps.Gravity_g;
    r.Compliant = r.OK_Mass && r.OK_Power && r.OK_Cost && r.OK_Volume && ...
                  r.OK_Throughput && r.OK_Automation && r.OK_Operators && r.OK_Gravity;

    % Margins (fraction of cap remaining; higher is better)
    r.Margin_Mass   = 1 - r.Mass_kg / caps.Mass_kg;
    r.Margin_Power  = 1 - r.Power_kW / caps.Power_kW;
    r.Margin_Cost   = 1 - r.Cost_kCredits / caps.Cost_kCredits;
    r.Margin_Volume = 1 - r.Volume_m3 / caps.Volume_m3;
    r.Margin_Throughput = r.Throughput_bph / caps.Throughput_bph - 1;

    if isempty(results)
        results = r;
    else
        results(end+1) = r; %#ok<AGROW>
    end
end

save(fullfile(anaDir, 'variantMetrics.mat'), 'results', 'caps');
writetable(struct2table(results), fullfile(anaDir, 'variantMetrics.csv'));
fprintf('Variant analysis complete: %d variants -> variantMetrics.mat/.csv\n', numel(results));
end
