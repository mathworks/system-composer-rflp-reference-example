function results = runAllTests(tier)
%RUNALLTESTS Run the project's complete verification stack as ONE suite.
%   results = runAllTests()          the full suite: MATLAB-based tiers
%                                    (component/analysis/traceability)
%                                    and the Simulink Test simulation
%                                    cases, one runner, equal citizens
%   results = runAllTests("analysis")     one MATLAB tier by tag
%   results = runAllTests("system")       just the simulation cases
%
%   The suite assembles from project metadata: MATLAB test classes carry
%   the Test classification label, and TestSuite.fromProject also adapts
%   the Simulink Test file's cases into the same suite, so both kinds run
%   through the same matlab.unittest runner, appear in the same results
%   table, and register their outcomes identically - including for
%   requirement verification.
%
%   A full run ends with a PER-VARIANT REQUIREMENTS COVERAGE summary
%   over all 28 system requirements (ADR-035): no variant is committed
%   as baseline, so status is attributed per candidate architecture -
%   Implement links by their source model, Verify links by the variant
%   each test case simulates (case names lead with the variant), with
%   pass/fail taken from the run just executed. Each variant's
%   verified-SR set is asserted exactly, so a link added or dropped
%   anywhere is a conscious edit. Requirements Toolbox's own status
%   rollup cannot provide this view: link sets auto-load with the
%   requirement set and cannot be selectively unloaded, so the
%   Requirements Editor columns aggregate all three mutually exclusive
%   candidates. Per-variant trace documents for design review come from
%   analysis/reporting/makeVariantTraceMatrix; the slreq PDF
%   (makeRequirementsReport) remains the any-variant aggregate.

import matlab.unittest.TestRunner

proj = currentProject;
suite = matlab.unittest.TestSuite.fromProject(proj);
isSim = contains({suite.Name}, 'GalacticSoupSystemTests');
fullRun = nargin == 0 || isempty(tier);
if ~fullRun
    if strcmpi(char(tier), 'system')
        suite = suite(isSim);   % simulation cases carry no TestTags
    else
        suite = suite.selectIf(matlab.unittest.selectors.HasTag(char(tier)));
    end
end
fprintf('suite: %d tests (%d simulation cases)\n', numel(suite), ...
    nnz(contains({suite.Name}, 'GalacticSoupSystemTests')));

runner = TestRunner.withTextOutput('OutputDetail', 1);

bdclose('all');
sltest.testmanager.clearResults;
results = runner.run(suite);
disp(table(results));
assertSuccess(results);

if fullRun
    % ---- per-variant requirements coverage (ADR-035) ----
    % attribute Verify links to the variant each case simulates and
    % Implement links to their source artifact; pass/fail comes from the
    % run just executed (this block only runs after assertSuccess)
    slreq.clear();
    srSet = slreq.load(fullfile(char(proj.RootFolder), ...
        'requirements','SystemRequirements.slreqx'));
    reqs = find(srSet, 'Type', 'Requirement');
    nGate = 0;
    for r = reqs
        for L = inLinks(r)
            try
                if strcmp(L.Type,'Refine') && ...
                        contains(char(source(L).artifact), 'ComplianceGate')
                    nGate = nGate + 1; break;
                end
            catch
            end
        end
    end

    simRes = results(contains({results.Name}, 'GalacticSoupSystemTests'));
    casePassed = containers.Map(extractAfter({simRes.Name}, '/'), ...
        num2cell([simRes.Passed]));
    tfile = sltest.testmanager.load(fullfile(char(proj.RootFolder), ...
        'tests','system','GalacticSoupSystemTests.mldatx'));
    variants = {'HyperCook','LeanBroth','EverSimmer'};
    verified = repmat({string.empty}, 1, numel(variants));
    for s = getTestSuites(tfile)
        for tc = getTestCases(s)
            v = find(cellfun(@(p) startsWith(tc.Name, p), variants), 1);
            assert(~isempty(v), 'case name does not lead with a variant: %s', tc.Name);
            for L = slreq.outLinks(tc)
                assert(casePassed.isKey(tc.Name) && casePassed(tc.Name), ...
                    'linked case did not pass: %s', tc.Name);
                verified{v}(end+1) = string(destination(L).id); %#ok<AGROW>
            end
        end
    end

    % each variant's verified-SR set is a contract: a Verify link added
    % or dropped anywhere must be a conscious edit here
    expected = { ...
        ["SR-GS-001","SR-GS-002","SR-GS-006","SR-GS-007","SR-GS-015","SR-GS-018","SR-GS-021","SR-GS-025"], ...
        ["SR-GS-006","SR-GS-021"], ...
        ["SR-GS-001","SR-GS-002","SR-GS-006","SR-GS-007","SR-GS-008","SR-GS-018","SR-GS-021","SR-GS-025","SR-GS-026"]};
    gaps = { ...
        'fails SR-GS-026 (single-string collapse, 0% retention)', ...
        'fails SR-GS-002 (196.8 bph), SR-GS-018 (+41.5 s), SR-GS-026 (0% retention)', ...
        'fails SR-GS-015 at 0.1 g (189.3 bph; pump-assisted drain redesign, ADR-026)'};
    fprintf('\n=== Requirements coverage per candidate architecture (%d SRs, ADR-035) ===\n', numel(reqs));
    fprintf('  formal gate coverage (Refine links): %d/%d; per-variant verdicts in analysis/results/complianceGate.csv\n', ...
        nGate, numel(reqs));
    for v = 1:numel(variants)
        nDirect = 0; nImpl = 0;
        for r = reqs
            direct = false; shared = false;
            for L = inLinks(r)
                try
                    if strcmp(L.Type,'Implement')
                        art = char(source(L).artifact);
                        direct = direct || contains(art, ['Physical' variants{v}]);
                        shared = shared || contains(art, 'Functional');
                    end
                catch
                end
            end
            nDirect = nDirect + direct;
            nImpl = nImpl + (direct || shared);
        end
        ids = unique(verified{v});
        fprintf('  %-10s implemented %d/%d (%d variant-direct + functional); verified by executed tests: %d (%s)\n', ...
            variants{v}, nImpl, numel(reqs), nDirect, numel(ids), strjoin(ids, ', '));
        fprintf('             known non-compliances: %s\n', gaps{v});
        assert(isequal(sort(ids), sort(expected{v})), ...
            '%s verified-SR set changed', variants{v});
    end
    fprintf('  per-variant trace documents: run analysis/reporting/makeVariantTraceMatrix\n');
    fprintf('  formal slreq report (any-variant aggregate): analysis/reporting/makeRequirementsReport\n');
end
end
