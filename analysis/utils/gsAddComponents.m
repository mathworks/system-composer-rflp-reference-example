function gsAddComponents(arch, dict, C)
%GSADDCOMPONENTS Add components with typed in/out ports to an architecture.
%   C is an N-by-3 cell array: {name, {inPorts}, {outPorts}}.
%   Interfaces are resolved from port names via gsIfaceForPort.

for i = 1:size(C, 1)
    c = addComponent(arch, C{i,1});
    for k = 1:numel(C{i,2})
        p = addPort(c.Architecture, C{i,2}{k}, 'in');
        p.setInterface(dict.getInterface(gsIfaceForPort(C{i,2}{k})));
    end
    for k = 1:numel(C{i,3})
        p = addPort(c.Architecture, C{i,3}{k}, 'out');
        p.setInterface(dict.getInterface(gsIfaceForPort(C{i,3}{k})));
    end
end
end
