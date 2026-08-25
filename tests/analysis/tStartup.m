classdef (TestTags = {'analysis'}) tStartup < sltest.TestCase
    % Startup-transient conclusions (ADR-040/-037/-038): regression
    % baselines for the SR-GS-025 story. Three times per run - first soup
    % at the cook stage, first packaged bowl, and sustained nominal rate -
    % swept against stock at activation.
    %
    % The findings these baselines guard: the batch variants spend
    % essentially all of startup on the first cook cycle rather than
    % downstream of it, and stock at activation barely moves any of it.

    methods (Static, Access = private)
        function st = load()
            S = load(fullfile(char(currentProject().RootFolder), ...
                'analysis', 'results', 'startupResults.mat'));
            st = S.st;
        end
    end

    methods (Test)
        function sweepBaselines(tc)
            st = tStartup.load();
            tc.verifyEqual(st.frac, [0 0.5 1 2]);
            tc.verifyEqual(st.variants, {'HyperCook','LeanBroth','EverSimmer'});
            k1 = find(st.frac == 1, 1);
            % nominal-stock design point
            tc.verifyEqual(st.firstSoup_s(:,k1), [17; 3421; 3390], ...
                'AbsTol', 30, 'first-soup times moved off their baselines');
            tc.verifyEqual(st.nominal_s(:,k1), [817; 3757; 3758], ...
                'AbsTol', 60, 'time-to-nominal moved off its baselines');
            tc.verifyTrue(all(st.compliant(:)), ...
                'a sweep point now violates SR-GS-025 - retire or revisit consciously');
        end

        function firstSoupPrecedesFirstOutput(tc)
            % ordering is definitional: soup cannot be packaged before it
            % is cooked. A violation means the logged cook-stage signal is
            % wired downstream of where it should be.
            st = tStartup.load();
            tc.verifyTrue(all(st.firstSoup_s(:) <= st.firstOut_s(:)), ...
                'first packaged output precedes first soup - check soupFlow_* wiring');
            tc.verifyTrue(all(st.firstOut_s(:) <= st.nominal_s(:)), ...
                'nominal rate reached before the first bowl was packaged');
        end

        function batchStartupIsTheCookCycle(tc)
            % Finding 1: for the batch variants the cook-to-pack pipeline is
            % a rounding error against the first cook cycle. This is the
            % number that says where startup effort should NOT go.
            st = tStartup.load();
            k1 = find(st.frac == 1, 1);
            pipeline = st.firstOut_s(:,k1) - st.firstSoup_s(:,k1);
            tc.verifyLessThan(pipeline(2:3), 120, ...
                'batch variants pipeline lag grew - Finding 1 needs revisiting');
            tc.verifyGreaterThan(st.firstSoup_s(2:3,k1), 20 * pipeline(2:3), ...
                'first cook cycle no longer dominates batch startup');
        end

        function stockAtActivationBarelyMatters(tc)
            % Finding 2 of the sweep (ADR-042), and the reason it was run:
            % the stocked-larder assumption underneath the headline numbers
            % does not flatter them. The claim is an ABSOLUTE one - under a
            % minute - not a proportional one: 36 s is 0.9% of LeanBroth's
            % hour-long startup but 4.4% of HyperCook's 13.6 minutes, and
            % the proportion says more about how short HyperCook's startup
            % is than about the larder.
            st = tStartup.load();
            k1 = find(st.frac == 1, 1);
            emptyCost = st.nominal_s(:,1) - st.nominal_s(:,k1);
            tc.verifyLessThan(emptyCost, 60, ...
                'an empty larder now costs more than a minute of startup');
            tc.verifyLessThan(emptyCost ./ st.nominal_s(:,k1), 0.05, ...
                'an empty larder now costs more than 5% of startup');
            above = st.nominal_s(:, st.frac >= 0.5);
            tc.verifyEqual(max(above,[],2) - min(above,[],2), zeros(3,1), ...
                'AbsTol', 5, 'startup became sensitive to stock above half');
        end

        function agreesWithBehavioralPipeline(tc)
            % The sweep at 1x stock and runBehavioralAnalysis simulate the
            % same models under the same conditions through the same shared
            % extractor, so they must report the same startup times. A
            % mismatch means gsStartupMetrics is being called with
            % different options from the two call sites - the exact drift
            % the shared extractor exists to prevent.
            st = tStartup.load();
            B = load(fullfile(char(currentProject().RootFolder), ...
                'analysis', 'results', 'behavioralMetrics.mat'));
            k1 = find(st.frac == 1, 1);
            tc.verifyEqual(st.firstSoup_s(:,k1)', [B.beh.TimeToFirstSoup_s], ...
                'AbsTol', 1, 'sweep and pipeline disagree on first soup');
            tc.verifyEqual(st.nominal_s(:,k1)', [B.beh.TimeToNominal_s], ...
                'AbsTol', 1, 'sweep and pipeline disagree on time to nominal');
        end

        function runningModeIsNotRateReadiness(tc)
            % Post-ADR-043 the supervisor's mode is named for what it is:
            % RUNNING means all lines healthy and material flowing. This
            % test pins the gap between that event and the measured
            % time-to-nominal-rate, so nobody re-reads the mode signal as a
            % readiness indicator: all three enter RUNNING within 2 s of
            % activation, EverSimmer 62 minutes before it holds its
            % nominal rate.
            B = load(fullfile(char(currentProject().RootFolder), ...
                'analysis', 'results', 'behavioralMetrics.mat'));
            lead = [B.beh.TimeToNominal_s] - [B.beh.TimeToModeRunning_s];
            tc.verifyGreaterThan(lead, 600, ...
                'mode now tracks rate readiness - the two metrics have converged');
            tc.verifyEqual(lead, [815 3755 3756], 'AbsTol', 90, ...
                'mode-lead baselines moved');
        end
    end
end
