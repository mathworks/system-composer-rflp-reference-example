function comp = gsFindComponent(instance, name)
%GSFINDCOMPONENT Find a component instance by name anywhere in the tree.
%   COMP = GSFINDCOMPONENT(INSTANCE, NAME) searches INSTANCE's descendants
%   breadth-first and returns the first component instance whose Name
%   matches NAME. Returns [] when there is no match.
%
%   Breadth-first matters: it keeps a bay named like one of its members
%   from shadowing the member, and it means a name present at the top
%   level still resolves to the top-level component.
%
%   This exists so that the stage tables in runVariantAnalysis can go on
%   naming leaf components ('RoboticPrepLine1') after those components
%   were moved into bays by regroupPhysicalBays (ADR-036). The stage
%   tables describe the plant's process stages, which are a property of
%   the design rather than of where a component happens to sit in the
%   model tree, so they should not have to track the model hierarchy.
%
%   See also gsCollectLeaves, gsRollup, regroupPhysicalBays.

comp = [];
frontier = instance.Components;

while ~isempty(frontier)
    next = [];
    for k = 1:numel(frontier)
        if strcmp(frontier(k).Name, name)
            comp = frontier(k);
            return
        end
    end
    for k = 1:numel(frontier)
        next = [next, frontier(k).Components]; %#ok<AGROW>
    end
    frontier = next;
end
end
