function addStatusAggregators(varargin)
%ADDSTATUSAGGREGATORS Give each bay a status concentrator (ADR-037).
%   ADDSTATUSAGGREGATORS() processes all three physical variant models.
%   ADDSTATUSAGGREGATORS(variantName) processes one.
%
%   Run AFTER regroupPhysicalBays. For every bay, this adds one
%   <Bay>Controller component that:
%
%     * receives the plant controller's directive once and fans it out to
%       the bay's members, replacing the duplicate directive boundary
%       ports createSubsystem left behind (CookBay had four);
%     * collects each member's StatusBus and emits a single rolled-up
%       bayStatus, replacing one boundary status port per member.
%
%   The plant controller therefore drops from one status input per unit
%   (19 / 16 / 13) to one per bay, which is the whole point: that star was
%   what made the root diagrams unreadable after the bays went in.
%
%   Unlike the bay grouping, this is NOT metrics-neutral - the
%   concentrators are real hardware and carry PhysicalProperties. That is
%   the intended outcome; see ADR-037 for the sizing and its consequences.
%
%   Ports whose interface is not StatusBus are left alone: the gravity
%   compensator's envStatus (GravityData) and the inventory grid's
%   inventoryStatus / reorderRequest (StockData) keep their own paths to
%   the controller, because they are not status and the controller reads
%   them differently.
%
%   See also regroupPhysicalBays, layoutPhysicalBays, buildInlineBehaviors.

% Concentrator sizing (ADR-037): a bay concentrator aggregates telemetry
% and fans out a directive. It does not sequence a production chain the
% way EverSimmer's CellController does, so it is sized well below one.
% This sizing is load-bearing: at much above 10.8 kCredits per unit
% EverSimmer loses its cost margin and the compliant set goes empty.
AGG = struct( ...
    'Mass_kg', 15, 'Power_kW', 0.4, 'Cost_kCredits', 6, 'Volume_m3', 0.15, ...
    'OperatorsRequired', 0, 'AutomationLevel', 0.99, 'MTBF_hr', 40000, ...
    'GravityRating_g', 12, 'Throughput_bph', 0, 'IsProductionPath', 0, ...
    'UseParallelThroughput', 0);

spec = aggregatorSpec();
if nargin > 0
    names = string(fieldnames(spec));
    want = string(varargin{1});
    assert(any(names == want), 'Unknown variant "%s".', want);
    sel = want;
else
    sel = string(fieldnames(spec))';
end

for vname = sel
    s = spec.(vname);
    mdl = s.Model;
    fprintf('\n=== %s (%s) ===\n', vname, mdl);
    arch = systemcomposer.loadModel(mdl);
    drawnow;

    logged = loggedSignalNames(mdl);
    ctrl = arch.lookup('SimulinkHandle', get_param([mdl '/' s.Controller], 'Handle'));

    for b = 1:numel(s.Bays)
        addAggregatorToBay(arch, mdl, s.Bays(b), ctrl, AGG);
    end

    arch.save();
    restoreLoggedSignals(mdl, logged);
    arch.save();

    ctrlNow = arch.lookup('SimulinkHandle', get_param([mdl '/' s.Controller], 'Handle'));
    fprintf('  %s: %d input ports\n', s.Controller, ...
        nnz(strcmp({ctrlNow.Ports.Direction}, 'Input')));
end
end

% ----------------------------------------------------------------------
function addAggregatorToBay(arch, mdl, bay, ctrl, AGG)
bayPath = [mdl '/' bay.Name];
bayH = get_param(bayPath, 'Handle');
bayComp = arch.lookup('SimulinkHandle', bayH);
sub = bayComp.Architecture;

% --- discover what the aggregator has to absorb -----------------------
members = sub.Components;
statusSrc = cell(0, 2);        % {componentName, portName}
directiveDst = cell(0, 1);     % componentName
for k = 1:numel(members)
    for p = members(k).Ports
        if strcmp(p.Direction, 'Output') && startsWith(p.Name, 'status')
            statusSrc(end+1, :) = {members(k).Name, p.Name}; %#ok<AGROW>
        elseif strcmp(p.Direction, 'Input') && strcmp(p.Name, 'directive')
            directiveDst{end+1, 1} = members(k).Name; %#ok<AGROW>
        end
    end
end

if isempty(statusSrc) && isempty(directiveDst)
    fprintf('  %-18s nothing to aggregate, skipped\n', bay.Name);
    return
end

% Order the status inputs so the production bay presents its members in
% the order the supervisor expects to count them.
if ~isempty(bay.HealthOrder)
    ordered = cell(0, 2);
    for h = 1:numel(bay.HealthOrder)
        hit = find(strcmp(statusSrc(:,2), bay.HealthOrder{h}), 1);
        assert(~isempty(hit), 'Bay %s has no status port %s.', ...
            bay.Name, bay.HealthOrder{h});
        ordered(end+1, :) = statusSrc(hit, :); %#ok<AGROW>
    end
    rest = setdiff(1:size(statusSrc,1), ...
        cellfun(@(n) find(strcmp(statusSrc(:,2), n), 1), bay.HealthOrder));
    statusSrc = [ordered; statusSrc(rest, :)];
end

% --- create the concentrator ------------------------------------------
inPorts = [{'directive'}, statusSrc(:,2)'];
gsAddComponents(sub, systemcomposer.openDictionary('PhysicalInterfaces.sldd'), ...
    {bay.Aggregator, inPorts, {'bayDirective', 'bayStatus'}});
drawnow;

bayComp = arch.lookup('SimulinkHandle', bayH);
sub = bayComp.Architecture;
agg = findByName(sub.Components, bay.Aggregator);
agg.applyStereotype('GalacticSoupProfile.PhysicalProperties');
pfx = 'GalacticSoupProfile.PhysicalProperties.';
for f = string(fieldnames(AGG))'
    agg.setProperty([pfx char(f)], num2str(AGG.(f), 12));
end

% --- re-point member status into the concentrator ----------------------
retired = strings(0);
for k = 1:size(statusSrc, 1)
    [comp, port] = deal(statusSrc{k,1}, statusSrc{k,2});
    boundary = boundaryPortFedBy(sub, comp, port);
    if ~isempty(boundary), retired(end+1) = string(boundary); end %#ok<AGROW>
    dropConnectorsOf(sub, comp, port);
    sub = refresh(arch, bayH);
    connectPorts(bayPath, sub, comp, port, bay.Aggregator, port);
    sub = refresh(arch, bayH);
end

% --- re-point member directive out of the concentrator -----------------
dirBoundaries = strings(0);
for k = 1:numel(directiveDst)
    comp = directiveDst{k};
    b = boundaryPortFeeding(sub, comp, 'directive');
    if ~isempty(b), dirBoundaries(end+1) = string(b); end %#ok<AGROW>
    dropConnectorsOf(sub, comp, 'directive');
    sub = refresh(arch, bayH);
    connectPorts(bayPath, sub, bay.Aggregator, 'bayDirective', comp, 'directive');
    sub = refresh(arch, bayH);
end

% Keep exactly one directive boundary port and feed the concentrator.
dirBoundaries = unique(dirBoundaries, 'stable');
keepDirective = 'directive';
if ~any(dirBoundaries == keepDirective) && ~isempty(dirBoundaries)
    keepDirective = char(dirBoundaries(1));
end
connectBoundaryToComponent(bayPath, sub, keepDirective, bay.Aggregator, 'directive');
sub = refresh(arch, bayH);

% --- expose the rolled-up status --------------------------------------
newPort = addPort(sub, 'bayStatus', 'out');
newPort.setInterface(systemcomposer.openDictionary('PhysicalInterfaces.sldd') ...
    .getInterface('BayStatusBus'));
drawnow;
sub = refresh(arch, bayH);
connectComponentToBoundary(bayPath, sub, bay.Aggregator, 'bayStatus', 'bayStatus');

% --- retire the boundary ports the concentrator replaced ---------------
retire = unique([retired, setdiff(dirBoundaries, string(keepDirective))]);
for k = 1:numel(retire)
    destroyBoundaryPort(arch, bayH, char(retire(k)));
end

% --- give the plant controller its single bay status input -------------
ctrlPortName = ['bayStatus' bay.Short];
cp = addPort(ctrl.Architecture, ctrlPortName, 'in');
cp.setInterface(systemcomposer.openDictionary('PhysicalInterfaces.sldd') ...
    .getInterface('BayStatusBus'));
drawnow;

root = arch.Architecture;
connectComponents(mdl, root, bay.Name, 'bayStatus', ctrl.Name, ctrlPortName);
drawnow;

% the controller's now-orphaned per-unit status inputs
for k = 1:numel(retired)
    destroyControllerPort(arch, ctrl, char(retired(k)));
end
drawnow;

fprintf('  %-18s %-20s absorbs %d status + %d directive\n', ...
    bay.Name, bay.Aggregator, size(statusSrc,1), numel(directiveDst));
end

% ======================================================================
%  small architecture helpers
% ======================================================================
function sub = refresh(arch, bayH)
drawnow;
sub = arch.lookup('SimulinkHandle', bayH).Architecture;
end

function c = findByName(list, name)
c = [];
for k = 1:numel(list)
    if strcmp(list(k).Name, name), c = list(k); return; end
end
end

function p = portByName(ports, name)
p = [];
for k = 1:numel(ports)
    if strcmp(ports(k).Name, name), p = ports(k); return; end
end
end

function name = boundaryPortFedBy(sub, compName, portName)
%BOUNDARYPORTFEDBY Boundary port driven by COMPNAME.PORTNAME, if any.
name = '';
c = findByName(sub.Components, compName);
p = portByName(c.Ports, portName);
for con = p.Connectors
    for e = [con.SourcePort, con.DestinationPort]
        if isa(e, 'systemcomposer.arch.ArchitecturePort'), name = e.Name; return; end
    end
end
end

function name = boundaryPortFeeding(sub, compName, portName)
name = boundaryPortFedBy(sub, compName, portName);
end

function dropConnectorsOf(sub, compName, portName)
%DROPCONNECTORSOF Free a component port so it can be rewired.
%
%   Deletes the underlying Simulink LINE rather than calling destroy() on
%   the architecture connector. Connector.destroy leaves the port in a
%   state System Composer will not reconnect - connect() then returns an
%   empty connector with no diagnostic, and even reconnecting the port to
%   exactly where it came from fails. Deleting the line leaves the port
%   genuinely free.
c = findByName(sub.Components, compName);
p = portByName(c.Ports, portName);
if isempty(p), return; end
h = p.SimulinkHandle;
L = get_param(h, 'Line');
if L > 0
    delete_line(L);
end
drawnow;
end

function h = simulinkPortHandle(p)
%SIMULINKPORTHANDLE The Simulink port handle to wire to.
%
%   A ComponentPort's SimulinkHandle is already a port handle. An
%   ArchitecturePort's is the backing Inport/Outport BLOCK, so take the
%   side of that block which faces the diagram it lives in: a boundary
%   INPUT sources signal inward (its block's outport), a boundary OUTPUT
%   sinks it (its block's inport).
if isa(p, 'systemcomposer.arch.ArchitecturePort')
    ph = get_param(p.SimulinkHandle, 'PortHandles');
    if strcmp(p.Direction, 'Input')
        h = ph.Outport(1);
    else
        h = ph.Inport(1);
    end
else
    h = p.SimulinkHandle;
end
end

function wire(parentPath, src, dst, label)
%WIRE Connect two ports with add_line, and prove it took.
%
%   add_line succeeds in cases where the architecture API's connect()
%   silently declines, and System Composer picks the resulting line up as
%   a connector. This is the only reliable way found to rewire an existing
%   System Composer model in R2026a.
sh = simulinkPortHandle(src);
dh = simulinkPortHandle(dst);
try
    add_line(parentPath, sh, dh, 'autorouting', 'on');
catch ME
    error('wire: %s failed (%s)', label, ME.message);
end
drawnow;
assert(get_param(dh, 'Line') > 0, 'wire: %s produced no line', label);
end

function connectPorts(parentPath, sub, srcComp, srcPort, dstComp, dstPort)
s = portByName(findByName(sub.Components, srcComp).Ports, srcPort);
d = portByName(findByName(sub.Components, dstComp).Ports, dstPort);
assert(~isempty(s) && ~isempty(d), 'connectPorts: %s.%s -> %s.%s missing', ...
    srcComp, srcPort, dstComp, dstPort);
wire(parentPath, s, d, sprintf('%s.%s -> %s.%s', srcComp, srcPort, dstComp, dstPort));
end

function connectBoundaryToComponent(parentPath, sub, boundaryName, compName, portName)
b = portByName(sub.Ports, boundaryName);
d = portByName(findByName(sub.Components, compName).Ports, portName);
assert(~isempty(b) && ~isempty(d), 'connectBoundaryToComponent: %s -> %s.%s missing', ...
    boundaryName, compName, portName);
wire(parentPath, b, d, sprintf('<%s> -> %s.%s', boundaryName, compName, portName));
end

function connectComponentToBoundary(parentPath, sub, compName, portName, boundaryName)
s = portByName(findByName(sub.Components, compName).Ports, portName);
b = portByName(sub.Ports, boundaryName);
assert(~isempty(s) && ~isempty(b), 'connectComponentToBoundary: %s.%s -> %s missing', ...
    compName, portName, boundaryName);
wire(parentPath, s, b, sprintf('%s.%s -> <%s>', compName, portName, boundaryName));
end

function connectComponents(parentPath, root, srcComp, srcPort, dstComp, dstPort)
s = portByName(findByName(root.Components, srcComp).Ports, srcPort);
d = portByName(findByName(root.Components, dstComp).Ports, dstPort);
assert(~isempty(s) && ~isempty(d), 'connectComponents: %s.%s -> %s.%s missing', ...
    srcComp, srcPort, dstComp, dstPort);
wire(parentPath, s, d, sprintf('%s.%s -> %s.%s', srcComp, srcPort, dstComp, dstPort));
end

function destroyBoundaryPort(arch, bayH, portName)
%DESTROYBOUNDARYPORT Remove a bay boundary port and everything hanging off
%   it, at BOTH levels. Destroying the architecture port also removes the
%   matching component port at the parent and the root connector into it,
%   but it can leave the underlying Simulink line behind, which then
%   blocks any later add_line on that port - so sweep for orphans.
sub = refresh(arch, bayH);
p = portByName(sub.Ports, portName);
if isempty(p), return; end
for con = p.Connectors
    con.destroy();
end
drawnow;
p.destroy();
drawnow;
sweepDanglingLines(getfullname(bayH));
sweepDanglingLines(get_param(bayH, 'Parent'));
end

function destroyControllerPort(arch, ctrl, portName) %#ok<INUSL>
%DESTROYCONTROLLERPORT Remove one of the plant controller's inputs.
%
%   Destroy the ARCHITECTURE port inside the controller, not the component
%   port on its outside: the component port is a projection of the inner
%   one, and calling destroy on it errors with "Method should not be
%   called". Killing the inner port takes the outer one and its root
%   connector with it.
outer = portByName(ctrl.Ports, portName);
if ~isempty(outer)
    for con = outer.Connectors
        con.destroy();
    end
    drawnow;
end
inner = portByName(ctrl.Architecture.Ports, portName);
if isempty(inner), return; end
for con = inner.Connectors
    con.destroy();
end
drawnow;
inner.destroy();
drawnow;
sweepDanglingLines(getfullname(ctrl.SimulinkHandle));
sweepDanglingLines(get_param(ctrl.SimulinkHandle, 'Parent'));
end

function sweepDanglingLines(sysPath)
%SWEEPDANGLINGLINES Delete lines left without a source or a destination.
lines = find_system(sysPath, 'SearchDepth', 1, 'FindAll', 'on', 'Type', 'line');
for L = lines'
    try
        if get_param(L, 'SrcPortHandle') < 0 || isempty(get_param(L, 'DstPortHandle')) ...
                || all(get_param(L, 'DstPortHandle') < 0)
            delete_line(L);
        end
    catch
        % already gone with its port
    end
end
drawnow;
end

function names = loggedSignalNames(mdl)
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

function restoreLoggedSignals(mdl, names)
% Same trap as the bay regrouping: the flags are dropped by the SAVE, not
% by the edit, so this has to run after arch.save() and be followed by
% another save.
drawnow;
for k = 1:numel(names)
    lines = find_system(mdl, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
        'FindAll', 'on', 'Type', 'line', 'Name', char(names(k)));
    for L = 1:numel(lines)
        src = get_param(lines(L), 'SrcPortHandle');
        if src > 0 && ~strcmp(get_param(src, 'DataLogging'), 'on')
            set_param(src, 'DataLogging', 'on');
        end
    end
end
drawnow;
lost = setdiff(names, loggedSignalNames(mdl));
assert(isempty(lost), 'Signal logging lost for: %s', strjoin(lost, ', '));
end

% ======================================================================
function spec = aggregatorSpec()
%AGGREGATORSPEC Which bays get a concentrator, and what it is called.
%
%   HealthOrder names the status ports whose health the plant supervisor
%   counts, in the order it expects them. Only the production bay needs
%   it; the concentrator packs those into bayStatus.lineHealth so the
%   supervisor keeps seeing one health per production unit. EverSimmer's
%   production cells stay at the model root, so its supervisor path is
%   untouched and no bay carries a HealthOrder.

spec.HyperCook.Model = 'PhysicalHyperCook';
spec.HyperCook.Controller = 'CentralControlComputer';
spec.HyperCook.Bays = struct( ...
    'Name',       {'IntakeAndStorage', 'PrepBay', 'CookBay', 'FinishingLine', 'LaunchLogistics', 'PlantServices'}, ...
    'Aggregator', {'IntakeController', 'PrepController', 'CookController', 'FinishingController', 'LaunchController', 'ServicesController'}, ...
    'Short',      {'Intake', 'Prep', 'Cook', 'Finishing', 'Launch', 'Services'}, ...
    'HealthOrder', {{}, {}, {'statusCook1','statusCook2','statusCook3','statusCook4'}, {}, {}, {}});

spec.LeanBroth.Model = 'PhysicalLeanBroth';
spec.LeanBroth.Controller = 'OpsConsole';
spec.LeanBroth.Bays = struct( ...
    'Name',       {'IntakeAndStorage', 'ProductionLine', 'LaunchLogistics', 'PlantServices'}, ...
    'Aggregator', {'IntakeController', 'LineController', 'LaunchController', 'ServicesController'}, ...
    'Short',      {'Intake', 'Line', 'Launch', 'Services'}, ...
    'HealthOrder', {{}, {'statusCook1','statusCook2'}, {}, {}});

spec.EverSimmer.Model = 'PhysicalEverSimmer';
spec.EverSimmer.Controller = 'ControlTriad';
spec.EverSimmer.Bays = struct( ...
    'Name',       {'IntakeAndStorage', 'LaunchLogistics', 'PlantServices'}, ...
    'Aggregator', {'IntakeController', 'LaunchController', 'ServicesController'}, ...
    'Short',      {'Intake', 'Launch', 'Services'}, ...
    'HealthOrder', {{}, {}, {}});
end
