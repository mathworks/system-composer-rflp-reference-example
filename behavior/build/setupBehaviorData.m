function setupBehaviorData()
%SETUPBEHAVIORDATA Create/refresh the behavioral-layer data dictionaries.
%   Builds the dictionary chain
%       BehaviorInterfaces.sldd  (shared mode/state codes)
%         <- BehParamsCommon.sldd   (soup & thermal physics constants)
%              <- BehParamsHyperCook.sldd / BehParamsLeanBroth.sldd /
%                 BehParamsEverSimmer.sldd  (variant instance parameters)
%   and registers the behavior folders on the project path. Destructive and
%   idempotent: existing dictionaries are recreated from scratch.
%
%   Component models link BehParamsCommon (and see Interfaces through the
%   reference); variant plant models link their variant dictionary. Variant
%   entries are plain design-data values bound to model-reference instance
%   arguments in the plant models (see docs/09_behavioral_models.md #3).

proj = currentProject;
root = char(proj.RootFolder);
dataDir = fullfile(root, 'behavior', 'data');

% --- Project path: every folder whose artifacts resolve by filename ---
folders = {'behavior/components','behavior/subsystems','behavior/data', ...
           'behavior/build','behavior/tests'};   % plants retired (ADR-020)
projPathFolders = {proj.ProjectPath.File};
for i = 1:numel(folders)
    f = fullfile(root, folders{i});
    if ~any(strcmpi(projPathFolders, f))
        addPath(proj, f);
    end
end

% --- Recreate dictionaries (close all first so deletes succeed) ---
Simulink.data.dictionary.closeAll('-discard');
names = {'BehaviorInterfaces','BehParamsCommon','BehParamsHyperCook', ...
         'BehParamsLeanBroth','BehParamsEverSimmer'};
for i = 1:numel(names)
    f = fullfile(dataDir, [names{i} '.sldd']);
    if isfile(f), delete(f); end
end

% Interfaces: shared mode/state codes (uint8; enum classes deliberately
% avoided - see ADR-016 discussion in docs/09_behavioral_models.md)
dIf = Simulink.data.dictionary.create(fullfile(dataDir, 'BehaviorInterfaces.sldd'));
sIf = getSection(dIf, 'Design Data');
modes = {'PLANT_STARTUP',uint8(0); 'PLANT_NOMINAL',uint8(1); ...
         'PLANT_DEGRADED',uint8(2); 'PLANT_HALTED',uint8(3); ...
         'VAT_IDLE',uint8(0); 'VAT_FILL',uint8(1); 'VAT_HEAT',uint8(2); ...
         'VAT_SIMMER',uint8(3); 'VAT_DRAIN',uint8(4); 'VAT_CLEAN',uint8(5)};
for i = 1:size(modes,1), addEntry(sIf, modes{i,1}, modes{i,2}); end
saveChanges(dIf);

% Common physics: one source of truth for soup/thermal constants
dCo = Simulink.data.dictionary.create(fullfile(dataDir, 'BehParamsCommon.sldd'));
addDataSource(dCo, 'BehaviorInterfaces.sldd');   % filename only (path-resolved)
sCo = getSection(dCo, 'Design Data');
common = { ...
 'Bowl_kg',        0.55;   ... % soup mass per bowl-equivalent
 'Soup_cp_JpkgK',  3900;   ... % specific heat of vegan soup
 'FillTemp_C',     12;     ... % chilled ingredient inlet temperature
 'Ambient_C',      25;     ... % habitat ambient
 'SimmerTemp_C',   94;     ... % target cook temperature: SR-GS-008 band is
 ...                           % 70-95 C SERVED; bang-bang ripple is +-0.5 C,
 ...                           % so targeting the band edge (95) serves at up
 ...                           % to 95.2 C - caught by the SR-GS-008 criterion
 ...                           % (ADR-026); 94 leaves control-ripple margin
 'VatLoss_WpK',    15;     ... % convective loss coefficient (h*A)
 'Gravity_g',      1;      ... % ambient gravity (g); overridden per run for SR-GS-015
 'QC_ContamIncidence', 0;     ... % contaminated fraction of cooked flow; 0 nominal,
 ...                           % overridden per run for SR-GS-007 (ADR-027)
 'QC_DetectSensitivity', 0.995; ... % QC contamination detection sensitivity
 ...                                % (requirement floor is 0.99; 0.995 leaves margin)
 'Recipe_Count',   8;      ... % distinct recipes in the runtime rotation (SR-GS-001)
 'Recipe_Block_s', 1800;   ... % rotation block length: 8 recipes per 4 h production run
 'Recipe_Flush_s', 0;      ... % continuous-line changeover flush; 0 nominal
 ...                           % (neutral), overridden per run for ADR-029 sweeps
 'Rocket_Load_bowls', 60;  ... % shipment size per delivery rocket (estimate,
 ...                           % swept in ADR-031 - SR-GS-018 turnaround)
 'Rocket_Handling_s', 120; ... % dock/undock overhead per rocket (estimate)
 'Resupply_Cutoff_T', 1e9};    % resupply cutoff time (s); 1e9 = never.
 ...                           % Dictionary-resolved (not model workspace) so
 ...                           % Test Manager overrides reach it through the
 ...                           % external test harnesses (ADR-033)
for i = 1:size(common,1), addEntry(sCo, common{i,1}, common{i,2}); end
saveChanges(dCo);

% --- Variant parameter sets ---
% Values trace to the PhysicalProperties stereotype values on the physical
% architecture components (see docs/04, docs/06 #1); batch vat cycle
% parameters are derived so the nominal batch cycle reproduces the
% stereotype throughput: cycle = BatchSize/Throughput.
variants = struct( ...
  'HyperCook', {{ ...
    'HC_PrepRate_bph',160; 'HC_NumPrep',2; ...
    'HC_CookRate_bph',90;  'HC_CookPowerFull_kW',50; 'HC_CookPowerIdle_kW',8; ...
    'HC_CookTau_s',180; ...
    'HC_QCRate_bph',400;   'HC_QCReject',0.02; 'HC_QCCalibPeriod_s',3600; 'HC_QCCalibTime_s',60; ...
    'HC_PackRate_bph',340; ...
    'Transport_Rate_bph',400; 'Transport_Latency_s',30; ...
    'HC_StorageCap_bowls',22300;  ... % 72 h at 308.4 bph (ADR-032)
     'HC_StorageInit_bowls',1500; ...
    'HC_Resupply_bph',330; 'HC_NumLines',4; ...
    'HC_StaticPower_kW',298; ...
    'Fault_T_Prep1',1e9; 'Fault_T_Prep2',1e9; 'Fault_T_Cook1',1e9; 'Fault_T_Cook2',1e9; 'Fault_T_Cook3',1e9; 'Fault_T_Cook4',1e9; 'Fault_T_QC',1e9; 'Fault_T_Pack',1e9}}, ...   % stereotype power sum minus dynamic cook lines
  'LeanBroth', {{ ...
    'LB_PrepRate_bph',210; ...
    'LB_BatchSize_bowls',55; 'LB_HeaterPower_kW',45; 'LB_VatThermalMass_JpK',130000; ...
    'LB_FillRate_bps',0.5; 'LB_SimmerTime_s',1130; 'LB_DrainTime_s',200; 'LB_CleanTime_s',120; ...
    'LB_QCRate_bph',230;   'LB_QCReject',0.03; 'LB_QCCalibPeriod_s',7200; 'LB_QCCalibTime_s',300; ...
    'LB_PackRate_bph',220; ...
    'Transport_Rate_bph',250; 'Transport_Latency_s',120; ...
    'LB_StorageCap_bowls',14300;  ... % 72 h at 196.8 bph (ADR-032)
     'LB_StorageInit_bowls',600; ...
    'LB_Resupply_bph',215; 'LB_NumLines',2; ...
    'LB_StaticPower_kW',149; ...
    'Fault_T_Prep',1e9; 'Fault_T_Kettle1',1e9; 'Fault_T_Kettle2',1e9; 'Fault_T_QC',1e9; 'Fault_T_Pack',1e9}}, ...   % stereotype power sum minus kettle heaters
  'EverSimmer', {{ ...
    'ES_PrepRate_bph',80; ...
    'ES_BatchSize_bowls',40; 'ES_HeaterPower_kW',32; 'ES_VatThermalMass_JpK',96000; ...
    'ES_FillRate_bps',0.4; 'ES_SimmerTime_s',1182; 'ES_DrainTime_s',150; 'ES_CleanTime_s',120; ...
    'ES_QCRate_bph',90;    'ES_QCReject',0.02; 'ES_QCCalibPeriod_s',5400; 'ES_QCCalibTime_s',90; ...
    'ES_PackRate_bph',85; ...
    'Transport_Rate_bph',300; 'Transport_Latency_s',60; ...
    'ES_StorageCap_bowls',16800;  ... % 72 h at 231.9 bph (ADR-032)
     'ES_StorageInit_bowls',900; ...
    'ES_Resupply_bph',245; 'ES_NumLines',3; ...
    'ES_StaticPower_kW',267; ...
    'Fault_T_Cell1',1e9; 'Fault_T_Cell2',1e9; 'Fault_T_Cell3',1e9}});      % stereotype power sum minus cell vat heaters

vNames = fieldnames(variants);
for v = 1:numel(vNames)
    d = Simulink.data.dictionary.create( ...
        fullfile(dataDir, ['BehParams' vNames{v} '.sldd']));
    addDataSource(d, 'BehParamsCommon.sldd');
    s = getSection(d, 'Design Data');
    entries = variants.(vNames{v});
    for i = 1:size(entries,1)
        addEntry(s, entries{i,1}, entries{i,2});
    end
    saveChanges(d);
end
Simulink.data.dictionary.closeAll();

% --- Register dictionaries with the project ---
projFiles = {proj.Files.Path};
for i = 1:numel(names)
    f = fullfile(dataDir, [names{i} '.sldd']);
    if ~any(strcmpi(projFiles, f)), addFile(proj, f); end
end
fprintf('Behavior data ready: %d dictionaries in behavior/data, folders on path\n', numel(names));
end
