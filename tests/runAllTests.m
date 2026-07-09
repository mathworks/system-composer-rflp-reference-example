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
%   A full run ends with a REQUIREMENTS COVERAGE summary over all 28
%   system requirements: implementation status (Implement links from the
%   architectures), formal gate coverage (Refine links from the
%   Requirements Table rows), and verification status (Verify links from
%   the simulation test cases, with pass/fail from the run just executed).
%   The two test-verified SRs are asserted verified-passed. For the
%   formal document version, see analysis/reporting/makeRequirementsReport.

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
    % ---- requirements coverage summary (fresh set state, then update) ----
    slreq.clear();
    srSet = slreq.load(fullfile(char(proj.RootFolder), ...
        'requirements','SystemRequirements.slreqx'));
    updateImplementationStatus(srSet);
    updateVerificationStatus(srSet);
    reqs = find(srSet, 'Type', 'Requirement');
    nImpl = 0; nGate = 0; nVerPass = 0; nVerFail = 0; verIds = {};
    for r = reqs
        si = getImplementationStatus(r);
        if si.implemented > 0, nImpl = nImpl + 1; end
        for L = inLinks(r)
            try
                if strcmp(L.Type,'Refine') && ...
                        contains(char(source(L).artifact), 'ComplianceGate')
                    nGate = nGate + 1; break;
                end
            catch
            end
        end
        sv = getVerificationStatus(r);
        % unlinked requirements report total=1 with none=1; only count
        % requirements that actually have executed-test coverage
        if (sv.passed + sv.failed + sv.unexecuted) > 0
            verIds{end+1} = r.Id; %#ok<AGROW>
            if sv.failed > 0 || sv.unexecuted > 0
                nVerFail = nVerFail + 1;
            else
                nVerPass = nVerPass + 1;
            end
        end
    end
    fprintf('\n=== Requirements coverage (%d system requirements) ===\n', numel(reqs));
    fprintf('  implemented by architecture (Implement links): %d/%d\n', nImpl, numel(reqs));
    fprintf('  checked by the formal gate (Refine links):     %d/%d\n', nGate, numel(reqs));
    fprintf('  verified by executed tests (Verify links):     %d passed, %d not passed (%s)\n', ...
        nVerPass, nVerFail, strjoin(verIds, ', '));
    for id = {'SR-GS-001','SR-GS-002','SR-GS-006','SR-GS-007','SR-GS-008','SR-GS-015','SR-GS-018','SR-GS-021','SR-GS-025','SR-GS-026'}
        st = getVerificationStatus(find(srSet, 'Id', id{1}));
        assert(st.failed == 0 && st.unexecuted == 0, '%s not verified', id{1});
    end
    fprintf('  formal report: run analysis/reporting/makeRequirementsReport\n');
end
end
