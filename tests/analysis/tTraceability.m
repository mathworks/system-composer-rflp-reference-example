classdef (TestTags = {'traceability'}) tTraceability < sltest.TestCase
    % Traceability integrity: every requirement link resolves to a live
    % architecture element, and the allocation sets carry their full
    % complement. These are the artifacts that silently rot during
    % structural rework (see ADR-019/ADR-020 war stories).

    properties (TestParameter)
        % counts include the 4 root-architecture Implement links per model
        % for the emergent budget SRs, SR-GS-011..014 (ADR-024). All three
        % candidate architectures carry Implement links symmetrically
        % (ADR-035): no variant is committed as baseline, so each variant's
        % trace must stand on its own; per-variant attribution happens at
        % reporting time, not by demoting link types.
        linkSet = struct( ...
            'HyperCook',  struct('mdl','PhysicalHyperCook',  'n',14), ...
            'LeanBroth',  struct('mdl','PhysicalLeanBroth',  'n',14), ...
            'EverSimmer', struct('mdl','PhysicalEverSimmer', 'n',20));
    end

    methods (TestClassSetup)
        function closeGateModel(~)
            % the gate model's embedded requirement set blocks slreq.clear
            if bdIsLoaded('GalacticSoupComplianceGate')
                close_system('GalacticSoupComplianceGate', 0);
            end
        end
    end

    methods (Test)
        function linksResolve(testCase, linkSet)
            slreq.clear();
            load_system(linkSet.mdl);
            ls = slreq.load(linkSet.mdl);
            links = getLinks(ls);
            testCase.verifyNumElements(links, linkSet.n, ...
                sprintf('%s link inventory changed', linkSet.mdl));
            for L = links
                src = slreq.structToObj(source(L));
                q = src.getQualifiedName();
                testCase.verifyTrue(startsWith(q, linkSet.mdl), ...
                    sprintf('link source outside model: %s', q));
                dst = slreq.structToObj(destination(L));
                testCase.verifyMatches(dst.Id, '^SR-GS-\d+$');
            end
            types = arrayfun(@(L) string(L.Type), links);
            testCase.verifyTrue(all(types == "Implement"), sprintf( ...
                '%s: all candidate architectures carry Implement links (ADR-035)', ...
                linkSet.mdl));
        end

        function allocationSets(testCase)
            as = systemcomposer.allocation.load('LogicalToEverSimmer');
            testCase.verifyNumElements(as.Scenarios(1).Allocations, 24);
            testCase.verifyEqual(as.Scenarios(1).Name, 'VariantC');
            for nm = {'LogicalToHyperCook','LogicalToLeanBroth','FuncToLogical'}
                a2 = systemcomposer.allocation.load(nm{1});
                testCase.verifyGreaterThan(numel(a2.Scenarios(1).Allocations), 0, nm{1});
            end
        end
    end
end
