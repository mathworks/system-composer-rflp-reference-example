function conns = gsFlattenConnections(mdl)
%GSFLATTENCONNECTIONS Leaf-to-leaf signal set of an architecture model.
%   CONNS = GSFLATTENCONNECTIONS(MDL) returns a sorted string array of
%   "Source.port -> Dest.port" entries covering every signal path between
%   LEAF components, with intermediate composite (bay) boundary ports
%   traversed rather than reported.
%
%   The point is hierarchy-invariance: moving components into bays changes
%   the connector list at every level but must not change which leaf port
%   ends up driving which. Diffing this set before and after a regrouping
%   is what proves the regrouping was signal-preserving.
%
%   Root-level architecture ports are reported as "<root>.portName" so
%   that connections to the model boundary are covered too.
%
%   Components are identified as "Name#uuid8" rather than by name alone.
%   EverSimmer's three production cells hold identically named components
%   (CellController, CellCookVat, ...), so a name-keyed set silently
%   collapses the three cells into one and would not notice a signal
%   rerouted from one cell to another. UUIDs survive regrouping, so they
%   give an identity that is both unique and hierarchy-invariant.
%
%   See also regroupPhysicalBays, verifyBayRegrouping.

arch = systemcomposer.loadModel(mdl);
drawnow;

leaves = collectLeafComponents(arch.Architecture);
conns = strings(0);

for k = 1:numel(leaves)
    comp = leaves(k);
    for p = comp.Ports
        if ~strcmp(p.Direction, 'Output'), continue; end
        dests = resolveDownstream(p);
        for d = 1:numel(dests)
            conns(end+1) = sprintf('%s.%s -> %s', ...
                compId(comp), p.Name, dests(d)); %#ok<AGROW>
        end
    end
end

% Root inputs feeding into the design are not covered by the leaf-output
% sweep above, so walk them separately.
for ap = arch.Architecture.Ports
    if ~strcmp(ap.Direction, 'Input'), continue; end
    dests = resolveDownstream(ap);
    for d = 1:numel(dests)
        conns(end+1) = sprintf('<root>.%s -> %s', ap.Name, dests(d)); %#ok<AGROW>
    end
end

conns = unique(sort(conns));
end

% ----------------------------------------------------------------------
function leaves = collectLeafComponents(architecture)
leaves = systemcomposer.arch.Component.empty;
for c = architecture.Components
    if isempty(c.Architecture.Components)
        leaves(end+1) = c; %#ok<AGROW>
    else
        leaves = [leaves, collectLeafComponents(c.Architecture)]; %#ok<AGROW>
    end
end
end

% ----------------------------------------------------------------------
function dests = resolveDownstream(startPort)
%RESOLVEDOWNSTREAM Follow a signal from STARTPORT to every leaf input port
%   it reaches, hopping through composite boundaries.
%
%   Three kinds of hop are possible at each step:
%     * into a composite   - a bay's component port continues on the
%                            same-named architecture port inside it
%     * out of a composite - an architecture port continues on the
%                            same-named component port of the owning bay
%     * onto a leaf        - terminal; recorded

dests = strings(0);
queue = {startPort};
seen = strings(0);

while ~isempty(queue)
    p = queue{1};
    queue(1) = [];

    for c = p.Connectors
        for other = [c.SourcePort, c.DestinationPort]
            if other == p, continue; end

            key = portKey(other);
            if any(seen == key), continue; end
            seen(end+1) = key; %#ok<AGROW>

            if isa(other, 'systemcomposer.arch.ArchitecturePort')
                owner = ownerComponent(other);
                if isempty(owner)
                    % model boundary
                    dests(end+1) = sprintf('<root>.%s', other.Name); %#ok<AGROW>
                else
                    twin = matchingPort(owner.Ports, other.Name);
                    if ~isempty(twin), queue{end+1} = twin; end %#ok<AGROW>
                end
            else
                parent = other.Parent;
                if isempty(parent.Architecture.Components)
                    dests(end+1) = sprintf('%s.%s', compId(parent), other.Name); %#ok<AGROW>
                else
                    twin = matchingPort(parent.Architecture.Ports, other.Name);
                    if ~isempty(twin), queue{end+1} = twin; end %#ok<AGROW>
                end
            end
        end
    end
end
end

% ----------------------------------------------------------------------
function owner = ownerComponent(archPort)
%OWNERCOMPONENT Component owning the architecture that ARCHPORT sits on,
%   or [] when that architecture is the model root.
owner = [];
a = archPort.Parent;
if isprop(a, 'Parent') && ~isempty(a.Parent) && ...
        isa(a.Parent, 'systemcomposer.arch.Component')
    owner = a.Parent;
end
end

% ----------------------------------------------------------------------
function p = matchingPort(ports, name)
p = [];
for k = 1:numel(ports)
    if strcmp(ports(k).Name, name), p = ports(k); return; end
end
end

% ----------------------------------------------------------------------
function id = compId(comp)
%COMPID Name plus a UUID prefix, so replicated components stay distinct.
u = char(comp.UUID);
id = sprintf('%s#%s', comp.Name, u(1:8));
end

% ----------------------------------------------------------------------
function k = portKey(p)
k = string(class(p)) + "|" + string(p.UUID);
end
