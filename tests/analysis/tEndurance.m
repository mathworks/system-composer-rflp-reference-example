classdef (TestTags = {'analysis'}) tEndurance < sltest.TestCase
    % Storage-endurance conclusions, post-resolution (ADR-030 finding,
    % ADR-032 resolution). The requirements owner excluded consumables
    % from the SR-GS-011 mass budget and the stores were resized to 72 h
    % at each variant's nominal rate; these tests baseline the resolved
    % state. The finding-era baselines (6.41/4.66/5.44 h, asserting
    % endurance < 72) were retired consciously by the ADR-032 rework -
    % exactly the retirement mechanism they were built with.

    methods (Test)
        function enduranceBaselines(tc)
            S = load(fullfile(char(currentProject().RootFolder), ...
                'analysis', 'results', 'enduranceResults.mat'));
            e = S.endr;
            tc.verifyEqual(e.variants, {'HyperCook','LeanBroth','EverSimmer'});
            tc.verifyEqual(e.storageCap_bowls, [22300 14300 16800]);
            tc.verifyEqual(e.projected_h, [72.3 72.6 72.8], 'AbsTol', 0.5, ...
                'projected endurance moved off its baselines');
            tc.verifyTrue(all(e.compliant), ...
                'a variant lost SR-GS-021 compliance post-ADR-032');
            tc.verifyTrue(all(e.stillProducingAtWindowEnd));
        end

        function capacitySizedForNominalRate(tc)
            % the sizing rule itself: capacity >= 72 h x variant nominal rate
            S = load(fullfile(char(currentProject().RootFolder), ...
                'analysis', 'results', 'enduranceResults.mat'));
            e = S.endr;
            tc.verifyTrue(all(e.storageCap_bowls >= 72 * [308.4 196.8 231.9]), ...
                'store sizing no longer covers 72 h at nominal rate');
        end
    end
end
