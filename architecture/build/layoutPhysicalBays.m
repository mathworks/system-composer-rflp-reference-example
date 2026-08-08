function layoutPhysicalBays(varargin)
%LAYOUTPHYSICALBAYS Re-arrange the physical models after bay regrouping.
%   LAYOUTPHYSICALBAYS() lays out all three physical variant models.
%   LAYOUTPHYSICALBAYS(modelName) lays out one.
%
%   Runs arrangeSystem over every diagram level of each model - the root
%   plus every bay and component interior - because regrouping moved
%   blocks into new parents and left both the root and the new bay
%   interiors unarranged.
%
%   Model reference and Chart blocks keep their tiny default size through
%   arrangeSystem, so four or more port labels render as overlapping mush
%   (see the simulink-diagram-layout notes). Those blocks are given a
%   minimum size first, then their parent gets a plain arrange to open up
%   space around the resized blocks.
%
%   Content preview is switched off on composite components: at root-diagram
%   scale the interior preview renders as grey noise behind the port labels,
%   which is a large part of why the pre-regrouping diagrams were unreadable.
%
%   See also regroupPhysicalBays, verifyBayRegrouping.

if nargin > 0
    mdls = cellstr(varargin{1});
else
    mdls = {'PhysicalHyperCook', 'PhysicalLeanBroth', 'PhysicalEverSimmer'};
end

MIN_W = 220;
MIN_H = 150;

for k = 1:numel(mdls)
    mdl = mdls{k};
    load_system(mdl);
    fprintf('\n=== %s ===\n', mdl);

    % Layout is meant to be position-only, but arrangeSystem re-routes
    % lines and the DataLogging flag rides on the line's source port.
    % Assert it survived rather than trusting that it did - a dropped flag
    % surfaces as an unrelated-looking test failure much later.
    loggedBefore = loggedSignalNames(mdl);

    % 1. Silence interior previews on every composite component.
    composites = find_system(mdl, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
        'BlockType', 'SubSystem');
    for b = 1:numel(composites)
        try %#ok<TRYNC>
            set_param(composites{b}, 'ContentPreviewEnabled', 'off');
        end
    end
    fprintf('  content preview off on %d composites\n', numel(composites));

    % 2. Enforce a minimum size on multi-port reference blocks, and collect
    %    their parents for a follow-up plain arrange.
    refs = find_system(mdl, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
        'BlockType', 'ModelReference');
    touched = {};
    for b = 1:numel(refs)
        p = get_param(refs{b}, 'Position');
        w = max(MIN_W, p(3) - p(1));
        h = max(MIN_H, p(4) - p(2));
        if w > (p(3) - p(1)) || h > (p(4) - p(2))
            set_param(refs{b}, 'Position', [p(1) p(2) p(1)+w p(2)+h]);
            touched{end+1} = get_param(refs{b}, 'Parent'); %#ok<AGROW>
        end
    end
    fprintf('  resized %d of %d reference blocks\n', numel(touched), numel(refs));

    % 3. Full arrange at every level. Root last, so it settles against
    %    interiors that have already taken their final shape.
    levels = [composites; {mdl}];
    for b = 1:numel(levels)
        try
            Simulink.BlockDiagram.arrangeSystem(levels{b}, 'FullLayout', 'true');
        catch ME
            fprintf('  arrange skipped %s (%s)\n', levels{b}, ME.identifier);
        end
    end
    fprintf('  arranged %d diagram levels\n', numel(levels));

    % 4. Plain arrange around the blocks whose size we forced, to clear the
    %    overlaps the resize created without discarding the new sizes.
    u = unique(touched);
    for b = 1:numel(u)
        try %#ok<TRYNC>
            Simulink.BlockDiagram.arrangeSystem(u{b});
        end
    end

    % 5. Place the root bays in process order. This is LAST on purpose:
    %    arrangeSystem with FullLayout discards manual placement, so any
    %    future re-arrange has to re-run this function to get it back.
    placeRootBays(mdl);

    lost = setdiff(loggedBefore, loggedSignalNames(mdl));
    assert(isempty(lost), 'Layout dropped signal logging for: %s', ...
        strjoin(lost, ', '));
    fprintf('  signal logging intact (%d names)\n', numel(loggedBefore));

    save_system(mdl);
    fprintf('  saved\n');
end
end

% ----------------------------------------------------------------------
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

% ----------------------------------------------------------------------
function placeRootBays(mdl)
%PLACEROOTBAYS Lay the root diagram out as the variant schematic reads.
%
%   arrangeSystem optimises for short edges, not for process meaning, so
%   it scatters the bays and the material path zig-zags. The schematics in
%   docs/figures read left to right - supply, storage, prep, cook, finish,
%   ship - and the whole point of the regrouping was to make the model
%   read the same way. That ordering has to be asserted; it cannot be
%   derived from edge lengths.
%
%   The material path occupies one row. Shared services and the plant
%   controller sit in a band below it: they talk to every bay, so placing
%   them on the material row would put crossing lines through it.

ROW_Y = 120;      % material-flow row
COL_W = 380;      % horizontal pitch
BAY_W = 260;
BAY_H = 300;

flowOrder = {'IntakeAndStorage', 'PrepBay', 'CookBay', 'ProductionLine', ...
             'ProductionCell1', 'ProductionCell2', 'ProductionCell3', ...
             'FinishingLine', 'LaunchLogistics'};
bandOrder = {'PlantServices', 'CentralControlComputer', 'OpsConsole', 'ControlTriad'};

% EverSimmer's three cells are peers on the material path and belong in a
% vertical stack at one column, the way the schematic draws them, rather
% than strung out along the row.
cellStack = {'ProductionCell1', 'ProductionCell2', 'ProductionCell3'};

present = @(n) ~isempty(find_system(mdl, 'SearchDepth', 1, 'BlockType', 'SubSystem', 'Name', n));

col = 0;
placedCells = false;
rowBottom = ROW_Y + BAY_H;
for k = 1:numel(flowOrder)
    name = flowOrder{k};
    if ~present(name), continue; end

    if any(strcmp(name, cellStack))
        if placedCells, continue; end
        stackCol = col;
        for c = 1:numel(cellStack)
            if ~present(cellStack{c}), continue; end
            y = ROW_Y + (c-1) * (BAY_H + 40);
            setPos(mdl, cellStack{c}, stackCol, y, COL_W, BAY_W, BAY_H);
            rowBottom = max(rowBottom, y + BAY_H);
        end
        placedCells = true;
        col = col + 1;
        continue
    end

    setPos(mdl, name, col, ROW_Y, COL_W, BAY_W, BAY_H);
    col = col + 1;
end

% Derive the band position from how far the flow row actually reaches. A
% fixed offset works for the two single-row variants but drives the band
% straight through EverSimmer's three stacked production cells.
bandY = rowBottom + 200;

bandCol = 0;
for k = 1:numel(bandOrder)
    name = bandOrder{k};
    if ~present(name), continue; end
    h = BAY_H;
    if ~strcmp(name, 'PlantServices')
        h = 700;   % the plant controller carries one status port per unit
    end
    setPos(mdl, name, bandCol, bandY, COL_W * 1.6, BAY_W * 1.4, h);
    bandCol = bandCol + 1;
end

placeRootPorts(mdl, col, COL_W, ROW_Y);

% Re-route every root line around the new positions.
lines = find_system(mdl, 'SearchDepth', 1, 'FindAll', 'on', 'Type', 'line');
for L = lines'
    try %#ok<TRYNC>
        set_param(L, 'Router', 'auto');
    end
end
fprintf('  placed %d root bays in process order\n', col + bandCol);
end

% ----------------------------------------------------------------------
function placeRootPorts(mdl, nCols, pitch, rowY)
%PLACEROOTPORTS Pin the model's own inports and outports to the canvas
%   edges of the material row.
%
%   arrangeSystem leaves these wherever it finds room, which for these
%   models is far below the bays - stretching the canvas to twice the
%   height it needs and dragging long lines across the whole diagram. The
%   supply side belongs left of the first bay and the ship side right of
%   the last, matching the "supply ->" and "-> ship" arrows on the
%   schematics.

W = 30;
H = 14;
GAP = 60;

ins = find_system(mdl, 'SearchDepth', 1, 'BlockType', 'Inport');
outs = find_system(mdl, 'SearchDepth', 1, 'BlockType', 'Outport');

leftX = 120 - GAP - W;
rightX = 120 + nCols * pitch - pitch + 260 + GAP;

for k = 1:numel(ins)
    y = rowY + (k-1) * 70;
    set_param(ins{k}, 'Position', round([leftX y leftX+W y+H]));
end
for k = 1:numel(outs)
    y = rowY + (k-1) * 70;
    set_param(outs{k}, 'Position', round([rightX y rightX+W y+H]));
end
end

% ----------------------------------------------------------------------
function setPos(mdl, name, col, y, pitch, w, h)
x = 120 + col * pitch;
set_param([mdl '/' name], 'Position', round([x y x+w y+h]));
end
