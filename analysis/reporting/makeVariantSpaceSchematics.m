function makeVariantSpaceSchematics()
%MAKEVARIANTSPACESCHEMATICS Concept sketches of 24 unmodeled variants.
%   Illustrates how much of the physical design space lies beyond the
%   three modeled variants. Same visual language as makeVariantSchematics:
%   material flows left to right, stacked boxes are parallel units, gray
%   marks shared/single-string infrastructure, and a one-line caption
%   carries the takeaway. Each sketch borrows the palette color of the
%   baseline philosophy it leans toward (blue throughput, aqua budget,
%   yellow resilience). Concepts only - nothing here is modeled, rolled
%   up or simulated, so captions carry no metrics.
%
%   Outputs docs/figures/variant_space/variant_schematic_*.png, described
%   in docs/figures/variant_space/variant_design_space.md.

proj = currentProject;
figDir = char(fullfile(proj.RootFolder, 'docs', 'figures', 'variant_space'));
if ~isfolder(figDir)
    mkdir(figDir);
end

variants = variantCatalog();
for k = 1:numel(variants)
    f = drawVariant(variants(k));
    fileName = sprintf('variant_schematic_%s.png', lower(variants(k).name));
    exportStable(f, fullfile(figDir, fileName));
    close(f);
end

fprintf('%d variant schematics written to %s\n', numel(variants), figDir);
end

% ----------------------------------------------------------------------
function exportStable(f, filePath)
% exportgraphics on hidden figures intermittently crops at a ~10% larger
% scale; export a few times and keep the smallest (the correct) render
bestHeight = inf;
tmp = [tempname '.png'];
for attempt = 1:3
    exportgraphics(f, tmp, 'Resolution', 200);
    info = imfinfo(tmp);
    if info.Height < bestHeight
        bestHeight = info.Height;
        copyfile(tmp, filePath);
    end
end
delete(tmp);
end

function v = variantCatalog()
% lean: HyperCook = throughput, LeanBroth = budget, EverSimmer = resilience
cellSubs = {'prep','cook','QC','pack'};
ss = 'single string';

v = [ ...
    variant('MegaLadle', 'HyperCook', 'throughput without the weak link', ...
        ['6 continuous cook lines  \cdot  QC and packaging doubled so the back end is no longer single-string' ...
         '  \cdot  every budget cap under even more pressure'], ...
        [stk('Storage',3), stk('Prep',3), stk('Cook',6), stk('QC',2), stk('Pack',2)])
    variant('FlashBoil', 'HyperCook', 'cook fast, not wide', ...
        ['many small high-pressure cookers on minute-scale cycles  \cdot  each unit lost costs little capacity' ...
         '  \cdot  pressure vessels drive mass and safety cost'], ...
        [stk('Storage',2), stk('Prep',2), stk('Flash cooker',8), one('QC','gray',true,'note',ss), stk('Pack',2)])
    variant('SoupStream', 'HyperCook', 'one big river', ...
        'one continuous high-capacity cook tower  \cdot  simplest control problem of any variant  \cdot  every stage is a single point of failure', ...
        [one('Storage'), one('Prep','note',ss), one('Cook tower','h',16), one('Inline QC','gray',true,'note',ss), one('Pack','gray',true,'note',ss)])
    variant('BufferLine', 'HyperCook', 'decouple the stages', ...
        'HyperCook with surge tanks between stages  \cdot  a short upstream stoppage no longer starves the cook lines  \cdot  tanks add mass, not output', ...
        [stk('Storage',2), stk('Prep',2), one('Buffer','gray',true,'note','surge tank'), stk('Cook',4), ...
         one('Buffer','gray',true,'note','surge tank'), one('QC','gray',true,'note',ss), one('Pack','gray',true)])
    variant('ConcentrateCo', 'HyperCook', 'cook once, dilute late', ...
        'cook a concentrated base, add water at packaging  \cdot  cooking capacity decoupled from bowl count  \cdot  water becomes a supply item', ...
        [stk('Storage',2), stk('Prep',2), stk('Reducer',2), one('QC','gray',true,'note',ss), stk('Dilute + pack',4)])
    variant('TwinTrack', 'HyperCook', 'two fat lines', ...
        '2 high-rate independent lines  \cdot  cheaper than 3 cells  \cdot  losing one line halves output instead of keeping two-thirds', ...
        [one('Store'), cells({'Line 1','Line 2'}, cellSubs)])
    variant('BatchFlex', 'HyperCook', 'continuous and batch side by side', ...
        'continuous lines carry the base load, batch kettles run specials and absorb peaks  \cdot  two cook technologies to maintain', ...
        [stk('Storage',2), stk('Prep',2), split('Continuous',2,'Batch kettle',2), one('QC','gray',true,'note',ss), stk('Pack',2)])
    variant('PadPush', 'HyperCook', 'logistics first', ...
        'modest production, oversized launch field  \cdot  rockets never wait for a pad  \cdot  optimizes turnaround, not bowls per hour', ...
        [stk('Storage',2), one('Prep','note',ss), stk('Kettle',2), one('QC','gray',true,'note',ss), stk('Pack',2), stk('Launch pad',6)])

    variant('OnePot', 'LeanBroth', 'the cheapest soup possible', ...
        'one large batch kettle, one of everything  \cdot  the smallest plant that makes soup at all  \cdot  no fault tolerance, no headroom', ...
        [one('Storage'), one('Prep','note',ss), one('Kettle','h',10), one('Manual QC','gray',true,'note',ss), one('Pack','gray',true,'note',ss)])
    variant('Crockworks', 'LeanBroth', 'many tiny pots', ...
        '12 small low-power slow cookers  \cdot  long cook times, tiny power draw  \cdot  degrades gracefully almost by accident', ...
        [one('Storage'), one('Prep','note','manual'), stk('Slow cooker',12), one('Manual QC','gray',true,'note',ss), one('Pack','gray',true,'note',ss)])
    variant('KitSoup', 'LeanBroth', 'let the customer cook', ...
        'ship dried soup kits, the customer adds hot water  \cdot  no cook step in the plant at all  \cdot  may not satisfy the need for ready-to-eat soup', ...
        [one('Storage'), one('Blend','note',ss), stk('Dehydrator',2), one('Pack','gray',true,'note',ss)])
    variant('GalleyShip', 'LeanBroth', 'cook in transit', ...
        'pack raw ingredient kits and cook them aboard the rockets  \cdot  the plant shrinks, every rocket gets heavier', ...
        [one('Storage'), one('Prep','note',ss), one('Kit pack','gray',true,'note',ss), stk('Rocket galley',3,'note','cooks in flight')])
    variant('SolarSimmer', 'LeanBroth', 'power from the sun', ...
        'solar-thermal kettles replace the reactor  \cdot  power budget nearly free  \cdot  output follows the orbit - nothing cooks in eclipse', ...
        [stk('Storage',2), one('Prep','note',ss), stk('Solar kettle',3), one('Manual QC','gray',true,'note',ss), one('Pack','gray',true,'note',ss)])
    variant('NightPot', 'LeanBroth', 'cook off-peak, hold hot', ...
        'cook only in off-peak power windows, hold soup hot, pack around the clock  \cdot  lower peak power  \cdot  hot-hold quality is a new risk', ...
        [one('Storage'), one('Prep','note',ss), stk('Kettle',2), one('Hot hold','gray',true,'note','insulated tank'), ...
         one('QC','gray',true,'note',ss), one('Pack','gray',true,'note',ss)])
    variant('CameraQC', 'LeanBroth', 'LeanBroth with fewer humans', ...
        'LeanBroth with the manual inspectors replaced by camera QC  \cdot  closes the automation gap  \cdot  does nothing for throughput', ...
        [stk('Storage',2), one('Prep','note',ss), stk('Batch kettle',2), one('Vision QC','gray',true,'note',ss), one('Pack','gray',true,'note',ss)])
    variant('MultiCook', 'LeanBroth', 'one machine type', ...
        'combined prep-and-cook appliances  \cdot  one machine type, one spares kit  \cdot  each unit is a compromise at both jobs', ...
        [one('Storage'), stk('Multi-cooker',3,'note','prep + cook'), one('Manual QC','gray',true,'note',ss), one('Pack','gray',true,'note',ss)])

    variant('QuadSimmer', 'EverSimmer', 'N+1 cells', ...
        '4 independent cells, each sized so any 3 still meet the floor  \cdot  full output after a fault  \cdot  a fourth copy of everything', ...
        [one('Store'), cells({'Cell 1','Cell 2','Cell 3','Cell 4'}, cellSubs)])
    variant('HotSpare', 'EverSimmer', 'a line in reserve', ...
        'parallel cook lines plus one kept warm on standby, QC and packaging doubled  \cdot  full output after a fault, idle capital otherwise', ...
        [stk('Storage',2), stk('Prep',2), stk('Cook',4,'spare',1,'note','3 run + 1 hot standby'), stk('QC',2), stk('Pack',2)])
    variant('CrossStrap', 'EverSimmer', 'dual string, cross-connected', ...
        'two strings of every stage, cross-connected at each hand-off  \cdot  any single unit can fail without losing a path  \cdot  routing gets complicated', ...
        [stk('Storage',2), stk('Prep',2), stk('Cook',2), stk('QC',2), stk('Pack',2)], 'mesh', true)
    variant('HubSpoke', 'EverSimmer', 'shared hubs, independent cooks', ...
        'shared prep and packaging hubs feed 3 independent cook-and-QC cells  \cdot  cheaper than EverSimmer  \cdot  the hubs are the new single points of failure', ...
        [one('Store'), one('Prep hub','gray',true,'note','shared'), cells({'Cell 1','Cell 2','Cell 3'}, {'cook','QC'}), ...
         one('Pack hub','gray',true,'note','shared')])
    variant('PodSwarm', 'EverSimmer', 'containerized mini-plants', ...
        '10 containerized mini-plants  \cdot  lose one, keep 90%  \cdot  failed pods are swapped by rocket, not repaired on site', ...
        [one('Store'), stk('Soup pod',10,'note','prep, cook, QC, pack in each')])
    variant('SplitSite', 'EverSimmer', 'two plants, two moons', ...
        'two complete plants on different moons  \cdot  survives losing a whole site  \cdot  every fixed cost is paid twice', ...
        cells({'Moon A','Moon B'}, {'store','prep','cook','QC','pack'}))
    variant('DarkFactory', 'EverSimmer', 'no humans at all', ...
        '3 cells tended by maintenance robots, zero operators  \cdot  the robot crew becomes the reliability question', ...
        [one('Store'), cells({'Cell 1','Cell 2','Cell 3'}, cellSubs)], 'extra', 'Robot crew')
    variant('RecipeLines', 'EverSimmer', 'one cell per recipe family', ...
        'one prep-and-cook cell per recipe family, shared QC and packaging  \cdot  no cross-contamination between recipes  \cdot  idle capacity when demand is lopsided', ...
        [one('Store'), cells({'Broth','Chowder','Bisque'}, {'prep','cook'}), one('QC','gray',true,'note','shared'), ...
         one('Pack','gray',true,'note','shared')])
    ];
end

function v = variant(name, lean, tagline, caption, stages, varargin)
opts = struct('mesh', false, 'extra', '');
for i = 1:2:numel(varargin)
    opts.(varargin{i}) = varargin{i+1};
end
v = struct('name', name, 'lean', lean, 'tagline', tagline, 'caption', caption, ...
    'stages', {stages}, 'mesh', opts.mesh, 'extra', opts.extra);
end

% --- stage constructors (all share one field set so they concatenate) --
function s = stage(kind, label, n, varargin)
s = struct('kind', kind, 'label', label, 'n', n, 'gray', false, 'note', '', ...
    'spare', 0, 'h', 6, 'names', {{}}, 'subs', {{}}, 'labelB', '', 'nB', 0);
for i = 1:2:numel(varargin)
    s.(varargin{i}) = varargin{i+1};
end
end

function s = one(label, varargin)
s = stage('one', label, 1, varargin{:});
end

function s = stk(label, n, varargin)
s = stage('stack', label, n, varargin{:});
end

function s = cells(names, subs)
s = stage('cells', '', numel(names), 'names', names, 'subs', subs);
end

function s = split(labelA, nA, labelB, nB)
s = stage('split', labelA, nA, 'labelB', labelB, 'nB', nB);
end

% ----------------------------------------------------------------------
function f = drawVariant(v)
th = gsPlotTheme();
col = th.palette(v.lean);
inkP = th.inkP;
inkS = th.inkS;
yFlow = 17;

f = newCanvas(th.surface);
st = v.stages;
m = numel(st);
isMulti = @(s) any(strcmp(s.kind, {'cells','split'}));

% horizontal layout: equal gaps; narrow the boxes when there are many stages
bw = min(9.5, (75.5 - (m-1)*5) / m);
widths = arrayfun(@(s) stageWidth(s, bw), st);
x0 = 10;
if isMulti(st(1)), x0 = 17; end
x1 = 85.5;
if isMulti(st(end)), x1 = 78; end
% short chains keep a natural gap and are centered instead of stretched
gap = 0;
if m > 1
    gap = min(14, (x1 - x0 - sum(widths)) / (m-1));
end
x0 = x0 + (x1 - x0 - sum(widths) - gap*(m-1)) / 2;
xSupply = x0 - 8;
if isMulti(st(1)), xSupply = x0 - 15; end

flowArrow(xSupply, yFlow, 7, inkS); text(xSupply, yFlow+3.5, 'supply', 'FontSize', 9, 'Color', inkS);

x = x0;
anchors = cell(1, m);
for i = 1:m
    s = st(i);
    c = col;
    if s.gray, c = th.muted; end
    switch s.kind
        case 'one'
            anchors{i} = onebox(x, yFlow, s.label, c, inkP, s.note, bw, s.h);
        case 'stack'
            anchors{i} = stack(x, yFlow, s.n, s.label, c, inkP, bw, 20, s.spare, s.note);
        case 'cells'
            anchors{i} = cellboxes(x, s.names, s.subs, c, inkP, inkS);
        case 'split'
            a = stack(x, 25, s.n, s.label, c, inkP, bw, 10, 0, '');
            b = stack(x, 8.5, s.nB, s.labelB, c, inkP, bw, 10, 0, '');
            anchors{i} = struct('xL', x, 'xR', x+bw, 'y', [25 8.5], 'units', []);
            anchors{i}.units = [a.units b.units];
    end
    x = x + widths(i) + gap;
end

% supply fan-in when the first stage is multi-path
if numel(anchors{1}.y) > 1
    for yi = anchors{1}.y
        connectLine(xSupply+7.5, yFlow, anchors{1}.xL-1, yi, inkS);
    end
end
for i = 1:m-1
    link(anchors{i}, anchors{i+1}, v.mesh, yFlow, inkS);
end

% ship: converge multi-path outputs to a point, otherwise follow the last box
last = anchors{end};
if numel(last.y) > 1
    xc = last.xR + 7;
    for yi = last.y
        connectLine(last.xR, yi, xc, yFlow, inkS);
    end
    xs = xc + 1;
else
    xs = last.xR + 2.5;
end
flowArrow(xs, yFlow, 9, inkS); text(xs+1.5, yFlow+3.5, 'ship', 'FontSize', 9, 'Color', inkS);

if ~isempty(v.extra)
    onebox(10, 6.5, v.extra, th.muted, inkP, '', bw, 6);
end

title(sprintf('%s - %s', v.name, v.tagline), 'FontSize', 13, 'Color', inkP, 'FontWeight', 'normal');
caption(v.caption, inkS);
end

function w = stageWidth(s, bw)
if strcmp(s.kind, 'cells')
    k = numel(s.subs);
    w = 8 + k*7.4 + (k-1)*1.2 + 0.8;
else
    w = bw;
end
end

function link(a, b, mesh, yFlow, ink)
if mesh && numel(a.units) > 1 && numel(b.units) > 1
    for ya = a.units
        for yb = b.units
            connectLine(a.xR, ya, b.xL-0.4, yb, ink);
        end
    end
elseif isscalar(a.y) && isscalar(b.y)
    plot([a.xR b.xL-0.4], [yFlow yFlow], '-', 'Color', ink, 'LineWidth', 1.2);
elseif isscalar(a.y)
    for yb = b.y
        connectLine(a.xR, yFlow, b.xL-1, yb, ink);
    end
elseif isscalar(b.y)
    for ya = a.y
        connectLine(a.xR, ya, b.xL-0.4, yFlow, ink);
    end
else
    for ya = a.y
        for yb = b.y
            connectLine(a.xR, ya, b.xL-1, yb, ink);
        end
    end
end
end

% ----------------------------------------------------------------------
function caption(txt, inkS)
text(50, 1.2, txt, 'HorizontalAlignment','center', 'FontSize',9.5, 'Color',inkS);
end

function f = newCanvas(surf_)
f = figure('Visible','off','Color',surf_,'Position',[100 100 980 330]);
ax = axes(f, 'Position',[0.02 0.10 0.96 0.78]);
hold(ax,'on'); axis(ax,[0 100 0 34]); axis(ax,'off');
set(ax,'Color',surf_);
end

function t = tint(col, k)
% blend col toward the chart surface (k = strength of col)
th = gsPlotTheme();
t = th.surface + (col - th.surface) * k;
end

function a = onebox(x, yMid, label, col, ink, note, w, h)
rectangle('Position',[x yMid-h/2 w h], 'Curvature',0.18, ...
    'FaceColor',tint(col,0.18), 'EdgeColor',col, 'LineWidth',1.6);
text(x+w/2, yMid, label, 'HorizontalAlignment','center', ...
    'FontSize',9.5, 'Color',ink);
if ~isempty(note)
    thn = gsPlotTheme();
    text(x+w/2, yMid-h/2-2.2, note, 'HorizontalAlignment','center', ...
        'FontSize',8, 'Color',thn.muted, 'FontAngle','italic');
end
a = struct('xL', x, 'xR', x+w, 'y', yMid, 'units', yMid);
end

function a = stack(x, yMid, n, label, col, ink, w, maxTot, spare, note)
% n parallel units; shrinks to fit maxTot, last `spare` units drawn dashed
h = 4.2; gap = 1.4;
tot = n*h + (n-1)*gap;
if tot > maxTot
    h = h * maxTot/tot; gap = gap * maxTot/tot; tot = maxTot;
end
y0 = yMid + tot/2 - h;
units = zeros(1, n);
for i = 1:n
    y = y0 - (i-1)*(h+gap);
    style = '-';
    if i > n - spare, style = '--'; end
    rectangle('Position',[x y w h], 'Curvature',0.22, ...
        'FaceColor',tint(col,0.18), 'EdgeColor',col, 'LineWidth',1.6, 'LineStyle',style);
    units(i) = y + h/2;
end
text(x+w/2, yMid+tot/2+2.0, sprintf('%s \\times%d', label, n), ...
    'HorizontalAlignment','center', 'FontSize',9.5, 'Color',ink);
if ~isempty(note)
    thn = gsPlotTheme();
    text(x+w/2, yMid-tot/2-2.2, note, 'HorizontalAlignment','center', ...
        'FontSize',8, 'Color',thn.muted, 'FontAngle','italic');
end
a = struct('xL', x, 'xR', x+w, 'y', yMid, 'units', units);
end

function a = cellboxes(x, names, subs, col, ink, inkS)
% independent cells, each a complete chain of sub-stages
n = numel(names);
k = numel(subs);
pitch = min(10, 29/n);
h = 0.85*pitch;
ys = 18 + ((n-1)/2 - (0:n-1)) * pitch;
sw = 7.4; sh = min(4.2, 0.5*h);
w = 8 + k*sw + (k-1)*1.2 + 0.8;
for c = 1:n
    cy = ys(c);
    rectangle('Position',[x cy-h/2 w h], 'Curvature',0.12, ...
        'FaceColor',tint(col,0.10), 'EdgeColor',col, 'LineWidth',1.8);
    text(x+2.2, cy+0.32*h, names{c}, 'FontSize',9, 'Color',ink, 'FontWeight','bold');
    sx = x + 8;
    for i = 1:k
        rectangle('Position',[sx cy-sh/2 sw sh], 'Curvature',0.25, ...
            'FaceColor',tint(col,0.35), 'EdgeColor',col, 'LineWidth',1.1);
        text(sx+sw/2, cy, subs{i}, 'HorizontalAlignment','center', ...
            'FontSize',8.2, 'Color',ink);
        if i < k
            plot([sx+sw sx+sw+1.2], [cy cy], '-', 'Color',inkS, 'LineWidth',1);
        end
        sx = sx + sw + 1.2;
    end
end
a = struct('xL', x, 'xR', x+w, 'y', ys, 'units', ys);
end

function flowArrow(x, y, len, ink)
plot([x x+len-1.6], [y y], '-', 'Color',ink, 'LineWidth',1.4);
patch([x+len-1.6 x+len x+len-1.6], [y-0.9 y y+0.9], ink, 'EdgeColor','none');
end

function connectLine(x1, y1, x2, y2, ink)
plot([x1 x2], [y1 y2], '-', 'Color',ink, 'LineWidth',1.1);
end
