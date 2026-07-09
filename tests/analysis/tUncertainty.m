classdef (TestTags = {'analysis'}) tUncertainty < sltest.TestCase
    % Parameter-uncertainty study invariants (ADR-025). The 600-simulation
    % study itself is too heavy for the suite; these tests baseline its
    % published conclusions and guard the reproducibility contract between
    % the spec, the saved simulation batches, and the post-processing.

    properties (Constant)
        VariantOrder = {'HyperCook','LeanBroth','EverSimmer'};
    end

    methods (Test)
        function specIsDeterministic(tc)
            % same seed, same hypercube: the spec must regenerate its own draws
            s1 = uncertaintySpec();
            s2 = uncertaintySpec();
            tc.verifyEqual(s1.U, s2.U, ...
                'LHS draws are not reproducible from the seed');
            tc.verifyEqual(s1.N, 200);
        end

        function savedSimsMatchSpec(tc)
            % guards editing uncertaintySpec without re-running the simulations:
            % the parameter values stored with each simulation batch must be
            % exactly what today's spec generates
            spec = uncertaintySpec();
            proj = currentProject;
            for vn = tc.VariantOrder
                f = fullfile(char(proj.RootFolder), 'analysis', 'results', ...
                    ['uncertaintySims_' vn{1} '.mat']);
                tc.assertTrue(isfile(f), sprintf('%s missing', f));
                S = load(f);
                tc.verifyEqual(S.sims.values, spec.variants.(vn{1}).values, ...
                    'AbsTol', 1e-12, sprintf( ...
                    '%s: saved draws differ from spec (spec edited without rerun?)', vn{1}));
            end
        end

        function baselinedConclusions(tc)
            % regression baselines for the published study results
            proj = currentProject;
            S = load(fullfile(char(proj.RootFolder), 'analysis', 'results', 'uncertaintyResults.mat'));
            unc = S.unc;
            tc.verifyEqual(unc.variants(:)', tc.VariantOrder);
            tc.verifyEqual(unc.pPass, [1 0.04 1], 'AbsTol', 1e-12, ...
                'compliance probabilities moved off their baselines');
            % ADR-032 rebaseline: the double-MC's six static criteria read
            % live variantMetrics, and the 72 h rack hardware shifted the
            % cost/volume margins (was [0.0164 0.0056 0.9780]). Post-032
            % the HyperCook share is also a what-if - it fails the static
            % volume/cost gates the per-draw rule does not re-check.
            tc.verifyEqual(unc.winShare2, [0.0164 0.0052 0.9784], 'AbsTol', 1e-12, ...
                'double-uncertainty win share moved off its baseline');
            tc.verifyEqual(size(unc.thr_bph), [200 3]);
            % every draw keeps at least one compliant variant
            tc.verifyTrue(all(any(unc.thr_bph >= unc.floor_bph, 2)));
        end

        function postProcessingIsReproducible(tc)
            % rerunning the seeded post-processing over the saved batches
            % must land on the identical published numbers
            S = load(fullfile(char(currentProject().RootFolder), ...
                'analysis', 'results', 'uncertaintyResults.mat'));
            unc2 = runUncertaintyStudy();
            tc.verifyEqual(unc2.pPass, S.unc.pPass, 'AbsTol', 1e-12);
            tc.verifyEqual(unc2.winShare2, S.unc.winShare2, 'AbsTol', 1e-12);
        end
    end
end
