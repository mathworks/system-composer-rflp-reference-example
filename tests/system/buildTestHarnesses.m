function buildTestHarnesses()
%BUILDTESTHARNESSES Create the external Simulink Test harnesses (ADR-033).
%   One externally-saved harness per physical architecture model, used by
%   every simulation test case in GalacticSoupSystemTests.mldatx. The
%   harness makes the root interface explicitly observable: the CUT's
%   root inports (AmbientGravity, CustomerOrders, InboundSupplies - which
%   direct simulation silently grounded) become explicit Constant-0
%   sources, and the root outports become harness outports. The virtual
%   Telemetry bus flattens at the model-reference boundary into named
%   scalar outports (Telemetry_totalPower_kW, Telemetry_plantMode);
%   this generator names the feeding lines so yout carries the names
%   the test criteria harvest by.
%
%   Destructive and idempotent: existing harnesses are deleted and
%   recreated. Run before buildSystemTestFile after any root-interface
%   change.

proj = currentProject;
models = {'PhysicalHyperCook','HyperCookSystemHarness','HyperCook'; ...
          'PhysicalLeanBroth','LeanBrothSystemHarness','LeanBroth'; ...
          'PhysicalEverSimmer','EverSimmerSystemHarness','EverSimmer'};

% external harness files are created in the CURRENT FOLDER - work from
% each variant's folder (architecture/physical/<Variant>/) so the harness
% lands beside the model and *_harnessInfo.xml it belongs to
oldDir = pwd;
restoreDir = onCleanup(@() cd(oldDir));

for m = 1:size(models,1)
    mdl = models{m,1}; hn = models{m,2};
    cd(char(fullfile(proj.RootFolder, 'architecture', 'physical', models{m,3})));
    load_system(mdl);
    try
        sltest.harness.delete(mdl, hn);
    catch
    end
    sltest.harness.create(mdl, 'Name', hn, 'SaveExternally', true, ...
        'Source', 'Constant', 'Sink', 'Outport');
    sltest.harness.load(mdl, hn);
    set_param(hn, 'SaveOutput', 'on', 'SaveFormat', 'Dataset');
    % name the outport feed lines so yout elements are harvestable by name
    outs = find_system(hn, 'SearchDepth', 1, 'BlockType', 'Outport');
    for k = 1:numel(outs)
        [~, nm] = fileparts(outs{k});
        nm = get_param(outs{k}, 'Name');
        if startsWith(nm, 'Telemetry_')
            sig = extractAfter(nm, 'Telemetry_');
        else
            sig = nm;
        end
        ph = get_param(outs{k}, 'PortHandles');
        set_param(get_param(ph.Inport(1), 'Line'), 'Name', sig);
    end
    % the AmbientGravity source resolves from the SAME dictionary entry
    % that drives the gravity physics (ADR-034): one source of truth, and
    % a Gravity_g override moves the signal and the physics coherently
    % the port is bus-typed (GravityData): a bus-typed Constant takes a
    % struct expression matching the bus elements
    set_param([hn '/AmbientGravity'], 'Value', ...
        'struct(''gravity_g'', Gravity_g, ''compensation_pct'', 100)');
    save_system(hn);
    sltest.harness.close(mdl, hn);
    fprintf('%s: harness %s built (external)\n', mdl, hn);
end

% register harness files with the project
pf = {proj.Files.Path};
for m = 1:size(models,1)
    f = fullfile(char(proj.RootFolder), 'architecture', 'physical', ...
        models{m,3}, [models{m,2} '.slx']);
    if isfile(f) && ~any(strcmpi(pf, f)), addFile(proj, f); end
end
end
