classdef (TestTags = {'analysis'}) tGravity < sltest.TestCase
    % Gravity-sweep conclusions (ADR-026): regression baselines for the
    % SR-GS-015 story. The 24-simulation sweep itself is too heavy for the
    % suite (analysis/sweeps/runGravitySweep regenerates it); these tests baseline
    % what it published and pin the 1 g neutrality contract - the gravity
    % physics must be exactly inert at Gravity_g = 1 so every pre-gravity
    % baseline in this suite remains authoritative.

    methods (Test)
        function sweepBaselines(tc)
            S = load(fullfile(char(currentProject().RootFolder), ...
                'analysis', 'results', 'gravityResults.mat'));
            g = S.grav;
            tc.verifyEqual(g.g, [0.1 0.25 0.5 1 2 4 8 12]);
            tc.verifyEqual(g.variants, {'HyperCook','LeanBroth','EverSimmer'});
            % compliance pattern: HC everywhere, LB nowhere, ES all but 0.1 g
            tc.verifyTrue(all(g.compliant(1,:)), 'HyperCook must hold the full range');
            tc.verifyFalse(any(g.compliant(2,:)), 'LeanBroth compliant somewhere: story changed');
            tc.verifyEqual(g.compliant(3,:), logical([0 1 1 1 1 1 1 1]), ...
                'EverSimmer gravity hole moved off 0.1 g');
        end

        function oneGNeutrality(tc)
            % the g = 1 sweep column must equal the nominal baselines:
            % gravity physics is required to be inert at 1 g
            S = load(fullfile(char(currentProject().RootFolder), ...
                'analysis', 'results', 'gravityResults.mat'));
            gi = S.grav.g == 1;
            tc.verifyEqual(S.grav.thr_bph(:,gi), [308.4; 196.8; 231.9], ...
                'AbsTol', 0.5, 'gravity scaling is not neutral at 1 g');
        end

        function extremesMatchTestCases(tc)
            % the sltest GravityExtremes baselines must agree with the sweep
            S = load(fullfile(char(currentProject().RootFolder), ...
                'analysis', 'results', 'gravityResults.mat'));
            g = S.grav;
            tc.verifyEqual(g.thr_bph(1, g.g==0.1), 308.4, 'AbsTol', 3);  % HC at 0.1 g
            tc.verifyEqual(g.thr_bph(1, g.g==12),  271.0, 'AbsTol', 3);  % HC at 12 g
            tc.verifyEqual(g.thr_bph(3, g.g==0.1), 189.3, 'AbsTol', 3);  % ES at 0.1 g
        end
    end
end
