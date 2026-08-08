function regroupPhysicalBays(varargin)
%REGROUPPHYSICALBAYS Group flat top-level physical components into bays.
%   REGROUPPHYSICALBAYS() regroups all three physical variant models.
%   REGROUPPHYSICALBAYS(variantName) regroups a single variant
%   ('HyperCook', 'LeanBroth' or 'EverSimmer').
%
%   Motivation (ADR-036). The physical models were built flat: HyperCook
%   carried 19 top-level components and 53 top-level connections, and the
%   root diagram bore no resemblance to the variant schematics in
%   docs/figures. This script introduces one layer of "bay" hierarchy so
%   the root of each model reads as the schematic does - intake, then
%   production, then finishing, then launch logistics - with intra-bay
%   material flow hidden inside the bay.
%
%   The regrouping is METRICS-NEUTRAL by construction:
%
%     * Grouping is performed with Simulink.BlockDiagram.createSubsystem,
%       which MOVES the existing component blocks. Their SIDs and their
%       System Composer UUIDs are preserved, so requirement links (which
%       resolve by SID) and the LogicalTo* allocation sets (which resolve
%       by UUID) survive untouched.
%
%     * Every new bay is given the PhysicalProperties stereotype so that
%       gsRollup's PostOrder pass fills it with the sum of its children.
%       The top-level budget sums in runVariantAnalysis therefore total
%       the same mass/power/cost/volume/operators as before.
%
%     * No component is added or removed, so the leaf set is unchanged and
%       AutomationAvg, GravityMin, LeafCount, the stage capacities and the
%       availability product are all unchanged.
%
%   runVariantAnalysis resolves stage-table members with gsFindComponent,
%   which searches the instance tree recursively, so the stage tables did
%   not need to change when components moved into bays.
%
%   See also gsFindComponent, runVariantAnalysis, layoutPhysicalBays.

groups = bayDefinitions();

if nargin > 0
    want = string(varargin{1});
    names = string(fieldnames(groups));
    assert(any(names == want), 'Unknown variant "%s".', want);
    sel = want;
else
    sel = string(fieldnames(groups))';
end

for vname = sel
    spec = groups.(vname);
    mdl = spec.Model;
    fprintf('\n=== %s (%s) ===\n', vname, mdl);
    arch = systemcomposer.loadModel(mdl);

    before = numel(arch.Architecture.Components);
    logged = captureLoggedSignals(mdl);

    for g = 1:numel(spec.Bays)
        bay = spec.Bays(g);
        makeBay(arch, mdl, bay.Name, bay.Members);
    end

    after = numel(arch.Architecture.Components);
    fprintf('  top-level components: %d -> %d\n', before, after);

    % Save FIRST, then restore logging, then save again. The flags do not
    % survive createSubsystem's edit being written out: they are still set
    % in memory after the regrouping and are dropped by the save itself,
    % for signals inside components that moved. Restoring before the save
    % therefore looks like it worked and silently loses them anyway.
    arch.save();
    restoreLoggedSignals(mdl, logged);
    arch.save();

    persisted = captureLoggedSignals(mdl);
    lost = setdiff(logged, persisted);
    assert(isempty(lost), 'Signal logging did not survive save for: %s', ...
        strjoin(lost, ', '));
end
end

% ----------------------------------------------------------------------
function names = captureLoggedSignals(mdl)
%CAPTURELOGGEDSIGNALS Names of the signals currently marked for logging.
%
%   createSubsystem re-creates the lines it moves and silently drops the
%   DataLogging flag on most of them - on HyperCook it kept 2 of 6. The
%   analysis and the Simulink Test criteria fetch these by name out of
%   logsout (lg.get('loadedFlow_bps')), so a dropped flag does not fail
%   the regrouping, it fails the test suite several steps later with an
%   unrelated-looking error. Capture before, restore after.

names = strings(0);
ports = find_system(mdl, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
    'FindAll', 'on', 'Type', 'port', 'DataLogging', 'on');
for k = 1:numel(ports)
    ln = get_param(ports(k), 'Line');
    if ln > 0
        nm = get_param(ln, 'Name');
        if ~isempty(nm), names(end+1) = string(nm); end %#ok<AGROW>
    end
end
names = unique(names);
end

% ----------------------------------------------------------------------
function restoreLoggedSignals(mdl, names)
%RESTORELOGGEDSIGNALS Re-mark NAMES for logging, by signal name.
%
%   Signal names are unique per model here, and unlike block paths they
%   are exactly what survives a component moving into a bay - which makes
%   them the right key for putting the flags back.

drawnow;
restored = 0;
for k = 1:numel(names)
    lines = find_system(mdl, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
        'FindAll', 'on', 'Type', 'line', 'Name', char(names(k)));
    for L = 1:numel(lines)
        src = get_param(lines(L), 'SrcPortHandle');
        if src > 0 && ~strcmp(get_param(src, 'DataLogging'), 'on')
            set_param(src, 'DataLogging', 'on');
            restored = restored + 1;
        end
    end
end
drawnow;

after = captureLoggedSignals(mdl);
missing = setdiff(names, after);
assert(isempty(missing), 'Lost signal logging for: %s', strjoin(missing, ', '));
fprintf('  signal logging: %d names intact (%d flags restored)\n', ...
    numel(names), restored);
end

% ----------------------------------------------------------------------
function makeBay(arch, mdl, bayName, members)
%MAKEBAY Group MEMBERS (top-level component names) into a composite
%   component named BAYNAME, then repair the auto-generated boundary
%   port names and apply the PhysicalProperties stereotype.

existing = find_system(mdl, 'SearchDepth', 1, 'BlockType', 'SubSystem');
paths = strcat(mdl, '/', members);
missing = setdiff(paths, existing);
assert(isempty(missing), 'Missing component(s) in %s: %s', ...
    mdl, strjoin(missing, ', '));

h = cellfun(@(p) get_param(p, 'Handle'), paths);
Simulink.BlockDiagram.createSubsystem(h);

% createSubsystem always names the new block "Component" in a System
% Composer model; claim it before anything else can collide.
newBlk = setdiff(find_system(mdl, 'SearchDepth', 1, 'BlockType', 'SubSystem'), ...
                 existing);
assert(isscalar(newBlk), 'Expected exactly one new subsystem in %s.', mdl);
set_param(newBlk{1}, 'Name', bayName);

bayPath = [mdl '/' bayName];
set_param(bayPath, 'ContentPreviewEnabled', 'off');
bayHandle = get_param(bayPath, 'Handle');

% System Composer rebuilds its element cache from a queued event, so a
% component created by a raw Simulink edit is invisible to lookup() until
% the queue is flushed. Without this drawnow the lookups below silently
% return [] (as a double) rather than erroring. Same reason for the
% drawnow calls inside renameBoundaryPorts.
drawnow;

renameBoundaryPorts(arch, bayHandle);

% Look the bay up by Simulink handle rather than by path: the path index
% is rebuilt lazily and is still stale here even after the flush.
bay = arch.lookup('SimulinkHandle', bayHandle);
bay.applyStereotype('GalacticSoupProfile.PhysicalProperties');

fprintf('  %-18s <- %s (%d ports)\n', bayName, strjoin(members, ', '), ...
    numel(bay.Ports));
end

% ----------------------------------------------------------------------
function renameBoundaryPorts(arch, bayHandle)
%RENAMEBOUNDARYPORTS Give the bay's boundary ports the name of the inner
%   component port they carry.
%
%   createSubsystem derives boundary port names from the inner port names
%   but disambiguates with a running index, which produces actively
%   misleading names: grouping four cook lines yields cookedSoup1,
%   cookedSoup3, cookedSoup5, cookedSoup7 for inner ports cookedSoup1..4.
%   Every boundary port traces to inner component port(s); when those all
%   share one name, that name is the correct boundary name.
%
%   Renaming happens in two passes through temporary names so that a
%   target name still held by another port cannot cause a collision.

bay = arch.lookup('SimulinkHandle', bayHandle);
sub = bay.Architecture;

wanted = strings(0);
ports = sub.Ports;
keep = false(1, numel(ports));

taken = strings(0);
for k = 1:numel(ports)
    inner = innerPortNames(ports(k));
    if isscalar(unique(inner)) && strlength(inner(1)) > 0
        cand = inner(1);
    else
        cand = string(ports(k).Name);
    end
    % Ports that could not be merged (different external sources feeding
    % the same inner port name) must still end up uniquely named.
    if any(taken == cand)
        n = 2;
        while any(taken == cand + string(n)), n = n + 1; end
        cand = cand + string(n);
    end
    taken(end+1) = cand; %#ok<AGROW>
    wanted(k) = cand;
    keep(k) = ~strcmp(cand, ports(k).Name);
end

if ~any(keep), return; end

% Park every boundary port BLOCK on a collision-proof temporary name
% before assigning any final name.
%
% Two separate namespaces are in play and createSubsystem leaves them out
% of step: the System Composer port name (what the diagram shows) and the
% name of the Inport/Outport block that backs it. In a freshly created bay
% the SC port can read 'preppedBatch1' while its block is still
% 'preppedBatch2'. setName validates against the BLOCK namespace, so
% renaming SC ports alone still trips "name already exists" on a name no
% visible port appears to hold. Clearing the block names first removes
% every collision. The captured port objects stay valid across the block
% renames, so they can be renamed by index afterwards.

bayPath = getfullname(bayHandle);
portBlocks = [ ...
    find_system(bayPath, 'SearchDepth', 1, 'BlockType', 'Inport'); ...
    find_system(bayPath, 'SearchDepth', 1, 'BlockType', 'Outport')];
for b = 1:numel(portBlocks)
    set_param(portBlocks{b}, 'Name', sprintf('gsTmpBlk%d', b));
end
drawnow;

for k = 1:numel(ports)
    ports(k).setName(char(wanted(k)));
end
drawnow;

% Finally, give the parked blocks the same generic names the project's
% hand-built composites use ('Bus Element In1', 'Bus Element Out1', ...),
% so a regrouped bay is indistinguishable from one built by hand.
%
% The port block name is NOT the port name. System Composer keeps the two
% decoupled: renaming the block does not rename the port, and renaming a
% block TO its own port's name is rejected as a duplicate. The port names
% set above are what the diagram shows and what the API reports; the block
% names underneath are free-form, and every hand-built composite in this
% project leaves them generic.
inBlocks = find_system(bayPath, 'SearchDepth', 1, 'BlockType', 'Inport');
outBlocks = find_system(bayPath, 'SearchDepth', 1, 'BlockType', 'Outport');
for b = 1:numel(inBlocks)
    set_param(inBlocks{b}, 'Name', sprintf('Bus Element In%d', b));
end
for b = 1:numel(outBlocks)
    set_param(outBlocks{b}, 'Name', sprintf('Bus Element Out%d', b));
end
drawnow;
end

% ----------------------------------------------------------------------
function names = innerPortNames(archPort)
%INNERPORTNAMES Names of the component ports an architecture (boundary)
%   port connects to inside the bay.
names = strings(0);
for c = archPort.Connectors
    for e = [c.SourcePort, c.DestinationPort]
        if ~isa(e, 'systemcomposer.arch.ArchitecturePort')
            names(end+1) = string(e.Name); %#ok<AGROW>
        end
    end
end
if isempty(names), names = ""; end
end

% ----------------------------------------------------------------------
function groups = bayDefinitions()
%BAYDEFINITIONS Bay membership per variant.
%
%   Grouping follows the variant schematics in docs/figures, so that the
%   root diagram reads left-to-right as intake -> production -> finishing
%   -> launch, with the plant controller and shared services off the
%   material path. The controller is deliberately left at the root of each
%   model: it is the one component every bay talks to, and burying it in a
%   bay would hide the plant's control topology rather than clarify it.

groups.HyperCook.Model = 'PhysicalHyperCook';
groups.HyperCook.Bays = struct( ...
    'Name', {'IntakeAndStorage', 'PrepBay', 'CookBay', 'FinishingLine', 'LaunchLogistics', 'PlantServices'}, ...
    'Members', { ...
        {'CargoGantryDock', 'ColdStorageVault', 'AmbientStorageSilo', 'InventorySensorGrid'}, ...
        {'RoboticPrepLine1', 'RoboticPrepLine2'}, ...
        {'ContinuousCookLine1', 'ContinuousCookLine2', 'ContinuousCookLine3', 'ContinuousCookLine4'}, ...
        {'InlineQCScanner', 'HighSpeedPackagingLine'}, ...
        {'CargoLoaderGantry', 'LaunchPadComplex', 'RefuelingStation'}, ...
        {'FusionPowerPlant', 'GravityCompensatorArray', 'ConveyorNetwork'}});

groups.LeanBroth.Model = 'PhysicalLeanBroth';
groups.LeanBroth.Bays = struct( ...
    'Name', {'IntakeAndStorage', 'ProductionLine', 'LaunchLogistics', 'PlantServices'}, ...
    'Members', { ...
        {'ManualReceivingBay', 'ColdStoreLocker', 'DryGoodsRack', 'BarcodeInventorySystem'}, ...
        {'PrepWorkstation', 'BatchKettle1', 'BatchKettle2', 'QCBench', 'SemiAutoPackager'}, ...
        {'SharedCraneDock', 'TriPadLandingField', 'RefuelSkid'}, ...
        {'CompactFissionReactor', 'GravityCompUnit', 'AGVCartPool'}});

% EverSimmer already carries the production-cell layer that the other two
% variants lacked; only the intake, launch and services components around
% the cells are regrouped here.
groups.EverSimmer.Model = 'PhysicalEverSimmer';
groups.EverSimmer.Bays = struct( ...
    'Name', {'IntakeAndStorage', 'LaunchLogistics', 'PlantServices'}, ...
    'Members', { ...
        {'AutoDock', 'DualZoneStore', 'SmartInventoryNet'}, ...
        {'AutoCargoLoader', 'TriplePadPort', 'AutoRefuelCell'}, ...
        {'RedundantReactorPair', 'GravityCompMesh', 'RoboTransportSwarm'}});
end
