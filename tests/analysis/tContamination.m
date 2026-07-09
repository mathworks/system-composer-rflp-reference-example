classdef (TestTags = {'analysis'}) tContamination < sltest.TestCase
    % Contamination-sweep conclusions (ADR-027): regression baselines for
    % the SR-GS-007 story. The 13-simulation sweep itself lives in
    % analysis/sweeps/runContaminationSweep; these tests baseline what it
    % published: measured sensitivity equals the 0.995 design value at
    % every incidence for every variant (clearing the 0.99 requirement
    % floor), the boundary case sits exactly at the floor, and detection
    % rejection costs stay small enough that no compliance verdict flips.

    methods (Test)
        function sweepBaselines(tc)
            S = load(fullfile(char(currentProject().RootFolder), ...
                'analysis', 'results', 'contaminationResults.mat'));
            c = S.contam;
            tc.verifyEqual(c.incidence, [0.005 0.01 0.02 0.05]);
            tc.verifyEqual(c.variants, {'HyperCook','LeanBroth','EverSimmer'});
            % measured sensitivity: flat at the design value, above the floor
            tc.verifyEqual(c.sensitivity, 0.995*ones(3,4), 'AbsTol', 1e-3, ...
                'measured sensitivity drifted off the design value');
            tc.verifyTrue(all(c.sensitivity(:) >= c.reqFloor), ...
                'sensitivity below the SR-GS-007 floor somewhere');
            % boundary case: detector AT the floor measures the floor
            tc.verifyEqual(c.floorCaseSensitivity, 0.99, 'AbsTol', 1e-3);
        end

        function complianceUnchangedByDetection(tc)
            % detection rejection cost must not flip any compliance verdict,
            % even at the worst swept incidence (5%)
            S = load(fullfile(char(currentProject().RootFolder), ...
                'analysis', 'results', 'contaminationResults.mat'));
            c = S.contam;
            worst = c.thr_bph(:, end);
            tc.verifyEqual(worst, [293.1; 187.9; 220.4], 'AbsTol', 3, ...
                'throughput at 5% incidence moved off its baselines');
            tc.verifyGreaterThan(worst([1 3]), 200);   % HC, ES still compliant
            tc.verifyLessThan(worst(2), 200);          % LB still not
        end
    end
end
