function th = gsPlotTheme()
%GSPLOTTHEME House chart theme: the validated dark-mode reference palette.
%   Single source of truth for every generated figure (trade study,
%   behavioral traces, sweeps, schematics). Values are the dark-mode
%   column of the data-viz reference palette, validated as a set against
%   the dark surface (#1A1A19) - do not eyeball-adjust individual hues;
%   swap the whole set and re-validate if the house style changes.
%
%   Series slots are assigned to variants by NAME in fixed order
%   (identity, never cycled - an excluded variant must not repaint the
%   survivors):
%     1  HyperCook   blue    #3987E5
%     2  LeanBroth   aqua    #199E70
%     3  EverSimmer  yellow  #C98500
%
%   Rules the tokens encode: text wears ink tokens, never series colors;
%   requirement cap/floor reference lines use the reserved limit color
%   (with a text label, never color alone); event markers (fault
%   injection etc.) use muted, not limit; grid is a hairline against the
%   surface; bar edges use the surface color to keep a visible gap
%   between adjacent fills.

th.names   = {'HyperCook','LeanBroth','EverSimmer'};
th.series  = [ 57 135 229;    % HyperCook  blue   #3987E5
               25 158 112;    % LeanBroth  aqua   #199E70
              201 133   0 ] / 255;   % EverSimmer yellow #C98500
th.palette = containers.Map(th.names, num2cell(th.series, 2)');

th.surface = [ 26  26  25] / 255;   % chart surface  #1A1A19
th.inkP    = [255 255 255] / 255;   % primary ink
th.inkS    = [195 194 183] / 255;   % secondary ink  #C3C2B7
th.muted   = [137 135 129] / 255;   % axis/labels, event markers #898781
th.grid    = [ 44  44  42] / 255;   % hairline gridline #2C2C2A
th.axisC   = [ 56  56  53] / 255;   % baseline/axis  #383835
th.limit   = [208  59  59] / 255;   % SR cap/floor lines (status-critical) #D03B3B
th.good    = [ 12 163  12] / 255;   % status-good    #0CA30C
end
