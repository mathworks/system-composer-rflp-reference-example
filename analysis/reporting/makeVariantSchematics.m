function makeVariantSchematics()
%MAKEVARIANTSCHEMATICS Simple conceptual diagrams of the three variants.
%   One schematic per physical architecture, sharing a visual language:
%   material flows left to right, stacked boxes are parallel units, the
%   variant's fixed palette color marks production equipment, gray marks
%   shared/single-string infrastructure, and a one-line caption carries
%   the takeaway stats. Written for blog/doc readers who need the
%   differences at a glance, not the full architecture diagrams.
%
%   Outputs docs/figures/variant_schematic_*.png (copy to blog/images).

proj = currentProject;
figDir = char(fullfile(proj.RootFolder, 'docs', 'figures'));

th = gsPlotTheme();   % dark house style; variant colors by name
surf_ = th.surface;
inkP  = th.inkP;
inkS  = th.inkS;
gray_ = th.muted;     % single-string/shared infrastructure

% --- HyperCook: blue, parallel everywhere until it isn't -------------
c = th.palette('HyperCook');
f = newCanvas(surf_);
flowArrow(2, 17, 7, inkS); text(2, 20.5, 'supply', 'FontSize', 9, 'Color', inkS);
stack(10, 17, 2, 'Storage', c, inkP);           % 2 stores
stack(27, 17, 2, 'Prep', c, inkP);              % 2 robotic prep lines
stack(44, 17, 4, 'Cook', c, inkP);              % 4 continuous lines
onebox(61, 17, 'QC', gray_, inkP, 'single string');
onebox(76, 17, 'Pack', gray_, inkP, 'single string');
flowArrow(88, 17, 9, inkS); text(89.5, 20.5, 'ship', 'FontSize', 9, 'Color', inkS);
linkAll([10 27 44 61 76], 17, inkS);
title('HyperCook - throughput first', 'FontSize', 13, 'Color', inkP, 'FontWeight','normal');
caption('4 parallel continuous cook lines  \cdot  QC and packaging are single-string  \cdot  308 bph simulated, budgets near their caps', inkS);
exportgraphics(f, fullfile(figDir,'variant_schematic_hypercook.png'), 'Resolution', 200);
close(f);

% --- LeanBroth: aqua, minimal everything -----------------------------
c = th.palette('LeanBroth');
f = newCanvas(surf_);
flowArrow(2, 17, 7, inkS); text(2, 20.5, 'supply', 'FontSize', 9, 'Color', inkS);
stack(10, 17, 2, 'Storage', c, inkP);
onebox(27, 17, 'Prep', c, inkP, 'single string');
stack(44, 17, 2, 'Batch kettle', c, inkP);
onebox(61, 17, 'Manual QC', gray_, inkP, 'single string');
onebox(76, 17, 'Pack', gray_, inkP, 'single string');
flowArrow(88, 17, 9, inkS); text(89.5, 20.5, 'ship', 'FontSize', 9, 'Color', inkS);
linkAll([10 27 44 61 76], 17, inkS);
title('LeanBroth - budget first', 'FontSize', 13, 'Color', inkP, 'FontWeight','normal');
caption('2 batch kettles, humans in the loop  \cdot  roughly half of every budget  \cdot  197 bph simulated - below the 200 bph floor', inkS);
exportgraphics(f, fullfile(figDir,'variant_schematic_leanbroth.png'), 'Resolution', 200);
close(f);

% --- EverSimmer: yellow, three independent cells ---------------------
c = th.palette('EverSimmer');
f = newCanvas(surf_);
flowArrow(2, 17, 7, inkS); text(2, 20.5, 'supply', 'FontSize', 9, 'Color', inkS);
onebox(10, 17, 'Store', c, inkP);
ys = [27 17 7];
for k = 1:3
    cellbox(27, ys(k), sprintf('Cell %d', k), c, inkP, inkS);
    connectLine(19.5, 17, 26, ys(k)+2.5, inkS);
    connectLine(69, ys(k)+2.5, 76, 17, inkS);
end
flowArrow(77, 17, 9, inkS); text(78.5, 20.5, 'ship', 'FontSize', 9, 'Color', inkS);
title('EverSimmer - resilience first', 'FontSize', 13, 'Color', inkP, 'FontWeight','normal');
caption('3 independent production cells, each a complete prep\rightarrowcook\rightarrowQC\rightarrowpack chain  \cdot  lose any one, keep two-thirds  \cdot  232 bph simulated', inkS);
exportgraphics(f, fullfile(figDir,'variant_schematic_eversimmer.png'), 'Resolution', 200);
close(f);

fprintf('3 variant schematics written to docs/figures\n');
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
% blend col toward the chart surface (k = strength of col); on the dark
% surface this shades the fill down instead of washing it toward white
th = gsPlotTheme();
t = th.surface + (col - th.surface) * k;
end

function onebox(x, yMid, label, col, ink, note)
w = 9.5; h = 6;
rectangle('Position',[x yMid-h/2 w h], 'Curvature',0.18, ...
    'FaceColor',tint(col,0.18), 'EdgeColor',col, 'LineWidth',1.6);
text(x+w/2, yMid, label, 'HorizontalAlignment','center', ...
    'FontSize',9.5, 'Color',ink);
if nargin > 5
    thn = gsPlotTheme();
    text(x+w/2, yMid-h/2-2.2, note, 'HorizontalAlignment','center', ...
        'FontSize',8, 'Color',thn.muted, 'FontAngle','italic');
end
end

function stack(x, yMid, n, label, col, ink)
w = 9.5; h = 4.2; gap = 1.4;
tot = n*h + (n-1)*gap;
y0 = yMid + tot/2 - h;
for i = 1:n
    y = y0 - (i-1)*(h+gap);
    rectangle('Position',[x y w h], 'Curvature',0.22, ...
        'FaceColor',tint(col,0.18), 'EdgeColor',col, 'LineWidth',1.6);
end
text(x+w/2, yMid+tot/2+2.0, sprintf('%s \\times%d', label, n), ...
    'HorizontalAlignment','center', 'FontSize',9.5, 'Color',ink);
end

function cellbox(x, yMid, label, col, ink, inkS)
w = 42; h = 8.5;
rectangle('Position',[x yMid-h/2+2.5 w h], 'Curvature',0.12, ...
    'FaceColor',tint(col,0.10), 'EdgeColor',col, 'LineWidth',1.8);
text(x+2.2, yMid+5.2, label, 'FontSize',9, 'Color',ink, 'FontWeight','bold');
sub = {'prep','cook','QC','pack'};
sw = 7.4; sy = yMid+0.4; sx = x + 8;
for i = 1:4
    rectangle('Position',[sx sy sw 4.2], 'Curvature',0.25, ...
        'FaceColor',tint(col,0.35), 'EdgeColor',col, 'LineWidth',1.1);
    text(sx+sw/2, sy+2.1, sub{i}, 'HorizontalAlignment','center', ...
        'FontSize',8.2, 'Color',ink);
    if i < 4
        plot([sx+sw sx+sw+1.2], [sy+2.1 sy+2.1], '-', 'Color',inkS, 'LineWidth',1);
    end
    sx = sx + sw + 1.2;
end
end

function flowArrow(x, y, len, ink)
plot([x x+len-1.6], [y y], '-', 'Color',ink, 'LineWidth',1.4);
patch([x+len-1.6 x+len x+len-1.6], [y-0.9 y y+0.9], ink, 'EdgeColor','none');
end

function linkAll(xs, y, ink)
w = 9.5;
for i = 1:numel(xs)-1
    plot([xs(i)+w xs(i+1)-0.4], [y y], '-', 'Color',ink, 'LineWidth',1.2);
end
end

function connectLine(x1, y1, x2, y2, ink)
plot([x1 x2], [y1 y2], '-', 'Color',ink, 'LineWidth',1.1);
end
