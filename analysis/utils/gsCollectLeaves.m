function leaves = gsCollectLeaves(instance)
%GSCOLLECTLEAVES Collect leaf component instances (no children) from an
%   analysis instance tree, returned as a cell array.

leaves = {};
for child = instance.Components
    if isempty(child.Components)
        leaves{end+1} = child; %#ok<AGROW>
    else
        sub = gsCollectLeaves(child);
        leaves = [leaves, sub]; %#ok<AGROW>
    end
end
end
