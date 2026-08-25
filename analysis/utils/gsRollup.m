function gsRollup(instance, varargin)
%GSROLLUP PostOrder roll-up of additive PhysicalProperties through the hierarchy.
%   Composites receive the sum of their children for each additive property.
%   Use with: iterate(instance, 'PostOrder', @gsRollup)

prefix = 'GalacticSoupProfile.PhysicalProperties.';
additive = {'Mass_kg', 'Power_kW', 'Cost_kCredits', 'Volume_m3', 'OperatorsRequired'};

for j = 1:numel(additive)
    prop = [prefix additive{j}];
    if instance.isComponent() && ~isempty(instance.Components) && instance.hasValue(prop)
        total = 0;
        for child = instance.Components
            if child.hasValue(prop)
                total = total + child.getValue(prop);
            end
        end
        instance.setValue(prop, total);
    end
end
end
