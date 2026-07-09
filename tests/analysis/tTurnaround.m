classdef (TestTags = {'analysis'}) tTurnaround < sltest.TestCase
    % Rocket-turnaround conclusions (ADR-031): regression baselines for
    % the SR-GS-018 story. Turnaround = fill time (from the loaded-flow
    % cumulative curve) + 120 s handling, against the 1200 s limit.
    % HyperCook and EverSimmer pass at the 60-bowl design shipment;
    % LeanBroth misses by 41.5 s - a finding these baselines guard.

    methods (Test)
        function sweepBaselines(tc)
            S = load(fullfile(char(currentProject().RootFolder), ...
                'analysis', 'results', 'turnaroundResults.mat'));
            t = S.turn;
            tc.verifyEqual(t.R_bowls, [40 60 80 120]);
            tc.verifyEqual(t.variants, {'HyperCook','LeanBroth','EverSimmer'});
            % design point (R = 60): HC/ES under the limit, LB over it
            at60 = t.turnaround_s(:, t.R_bowls == 60);
            tc.verifyEqual(at60, [808.1; 1241.5; 1086.0], 'AbsTol', 30, ...
                'design-point turnarounds moved off their baselines');
            tc.verifyLessThanOrEqual(at60([1 3]), t.limit_s);
            tc.verifyGreaterThan(at60(2), t.limit_s, ...
                'LeanBroth now meets SR-GS-018 - retire the finding consciously');
        end

        function compliantShipmentEnvelope(tc)
            % every variant complies at small shipments and fails at large
            % ones; the envelope edge is the design-relevant number
            S = load(fullfile(char(currentProject().RootFolder), ...
                'analysis', 'results', 'turnaroundResults.mat'));
            t = S.turn;
            tc.verifyTrue(all(t.turnaround_s(:,1) <= t.limit_s), ...
                'someone fails even at 40-bowl shipments');
            tc.verifyTrue(all(t.turnaround_s(:,end) > t.limit_s), ...
                'someone passes even at 120-bowl shipments');
        end
    end
end
