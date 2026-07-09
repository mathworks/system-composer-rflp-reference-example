classdef (TestTags = {'analysis'}) tRollupInvariants < sltest.TestCase
    % Invariants of the stereotype roll-up: golden totals per variant
    % (mass/power/cost/volume from the architecture models), sane ranges,
    % caps parsed from requirement text, and internal flag consistency.

    properties (ClassSetupParameter)
    end
    properties
        R
        Caps
    end

    methods (TestClassSetup)
        function runRollup(testCase)
            if bdIsLoaded('GalacticSoupComplianceGate')
                close_system('GalacticSoupComplianceGate', 0);   % frees slreq.clear
            end
            results = runVariantAnalysis();   % also refreshes variantMetrics.mat
            testCase.R = results;
            S = load(fullfile(char(currentProject().RootFolder),'analysis','results', 'variantMetrics.mat'));
            testCase.Caps = S.caps;
        end
    end

    methods (Test)
        function goldenTotals(testCase)
            % NOTE: LeanBroth goldens were once recorded as 6170/880/200 from
            % a session dump taken while the kettles' stereotype values were
            % missing (the ADR-017 linkToModel incident) - this test caught it.
            % ADR-032 rebaseline: 72 h ingredient stores added rack hardware
            % (0.025 kg / 0.0010 m3 / 0.004 kCr per added bowl of capacity)
            % to every storage component. Pre-resolution totals were
            % 14320/498/1980/397, 7570/239/1070/240, 11120/363/1905/297.
            golden = { ... % Variant, Mass_kg, Power_kW, Cost_kCredits, Volume_m3
                'HyperCook',  14827.5, 498, 2061.2, 417.3; ...
                'LeanBroth',   7907.5, 239, 1124.0, 253.5; ...
                'EverSimmer', 11510.0, 363, 1967.4, 312.6};
            for i = 1:size(golden,1)
                r = testCase.R(strcmp({testCase.R.Variant}, golden{i,1}));
                testCase.assertNotEmpty(r, golden{i,1});
                testCase.verifyEqual(r.Mass_kg,       golden{i,2}, 'AbsTol', 1e-6);
                testCase.verifyEqual(r.Power_kW,      golden{i,3}, 'AbsTol', 1e-6);
                testCase.verifyEqual(r.Cost_kCredits, golden{i,4}, 'AbsTol', 1e-6);
                testCase.verifyEqual(r.Volume_m3,     golden{i,5}, 'AbsTol', 1e-6);
            end
        end

        function capsParsedFromRequirements(testCase)
            c = testCase.Caps;
            testCase.verifyEqual(c.Mass_kg, 15000);
            testCase.verifyEqual(c.Power_kW, 500);
            testCase.verifyEqual(c.Throughput_bph, 200);
            testCase.verifyEqual(c.Operators, 5);
        end

        function flagConsistency(testCase)
            for r = testCase.R
                allOk = r.OK_Mass && r.OK_Power && r.OK_Cost && r.OK_Volume && ...
                        r.OK_Throughput && r.OK_Automation && r.OK_Operators && r.OK_Gravity;
                testCase.verifyEqual(logical(r.Compliant), logical(allOk), ...
                    sprintf('%s: Compliant flag disagrees with its gates', r.Variant));
                testCase.verifyGreaterThanOrEqual(r.AutomationAvg, 0);
                testCase.verifyLessThanOrEqual(r.AutomationAvg, 1);
                testCase.verifyTrue(r.BehavioralSource, ...
                    'behavioral override should be active (behavioralMetrics.mat present)');
            end
        end
    end
end
