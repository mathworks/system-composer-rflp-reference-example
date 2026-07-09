classdef (TestTags = {'analysis'}) tRecipes < sltest.TestCase
    % Recipe-rotation conclusions (ADR-029): regression baselines for the
    % SR-GS-001 story. The flush-pricing sweep lives in
    % analysis/sweeps/runRecipeSweep; these tests baseline what it published:
    % every production run produces all 8 recipes, the continuous-line flush
    % cost is linear and never threatens compliance across the swept
    % range, and the neutral default is exactly neutral.

    methods (Test)
        function sweepBaselines(tc)
            S = load(fullfile(char(currentProject().RootFolder), ...
                'analysis', 'results', 'recipeResults.mat'));
            r = S.rec;
            tc.verifyEqual(r.flush_s, [0 60 120 300]);
            tc.verifyEqual(r.hc_recipes, 8*ones(1,4), ...
                'a production run failed to produce all 8 recipes');
            tc.verifyEqual(r.hc_thr_bph, [308.4 298.7 289.0 259.0], 'AbsTol', 3, ...
                'HyperCook flush pricing moved off its baselines');
            % zero flush is exactly the pre-recipe baseline (neutrality)
            tc.verifyEqual(r.hc_thr_bph(1), 308.4, 'AbsTol', 0.5);
            % compliance holds across the whole swept range
            tc.verifyTrue(all(r.hc_thr_bph >= 200));
        end

        function flushCostIsLinear(tc)
            % changeover pricing: ~one line-minute of output per flush-minute
            % per switch; the swept points must stay collinear within band
            S = load(fullfile(char(currentProject().RootFolder), ...
                'analysis', 'results', 'recipeResults.mat'));
            r = S.rec;
            fit = polyfit(r.flush_s, r.hc_thr_bph, 1);
            resid = r.hc_thr_bph - polyval(fit, r.flush_s);
            tc.verifyLessThan(max(abs(resid)), 2, 'flush cost is no longer linear');
            tc.verifyEqual(fit(1)*60, -9.9, 'AbsTol', 1.5, ...
                'flush price (bph per flush-minute) moved');
        end
    end
end
