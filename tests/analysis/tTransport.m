classdef (TestTags = {'analysis'}) tTransport < sltest.TestCase
    % Transport-sweep conclusions (ADR-028): regression baselines for the
    % SR-GS-006 story. The 12-simulation capacity-derate sweep lives in
    % analysis/sweeps/runTransportSweep; these tests baseline what it published:
    % nominal loading latency equals transit time exactly (empty dock
    % queues - the fluid queue's pass-through neutrality), everyone holds
    % the 600 s ceiling down to 80% pickup capacity, and everyone loses it
    % by 60%.

    methods (Test)
        function sweepBaselines(tc)
            S = load(fullfile(char(currentProject().RootFolder), ...
                'analysis', 'results', 'transportResults.mat'));
            t = S.trans;
            tc.verifyEqual(t.mult, [1 0.8 0.6 0.4]);
            tc.verifyEqual(t.variants, {'HyperCook','LeanBroth','EverSimmer'});
            % nominal latency == transit time (30/120/60 s), queues empty
            tc.verifyEqual(t.latency_s(:,1), [30; 120; 60], 'AbsTol', 1, ...
                'nominal latency is not pure transit time - queue not empty?');
            % the margin cliff: fine at 80%, blown by 60% for every variant
            tc.verifyTrue(all(t.latency_s(:,2) <= t.limit_s), ...
                'someone lost the 10-minute limit at 80% capacity');
            tc.verifyTrue(all(t.latency_s(:,3) > t.limit_s), ...
                'someone still held the limit at 60% capacity');
        end

        function leanBrothMarginIsThinnest(tc)
            % LeanBroth's 80% pickup (200 bph) nearly matches its 196.8 bph
            % production - the thinnest margin in the fleet, baselined
            S = load(fullfile(char(currentProject().RootFolder), ...
                'analysis', 'results', 'transportResults.mat'));
            lat80 = S.trans.latency_s(:,2);
            tc.verifyEqual(lat80, [30.5; 196.6; 86.1], 'AbsTol', 10, ...
                '80%-capacity latencies moved off their baselines');
            [~, worst] = max(lat80);
            tc.verifyEqual(worst, 2, 'the thinnest transport margin moved off LeanBroth');
        end
    end
end
