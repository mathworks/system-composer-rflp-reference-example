classdef (TestTags = {'analysis'}) tGateAgreement < sltest.TestCase
    % The formal Requirements Table gate and the expected verdicts.
    % runComplianceGate hard-asserts formal-vs-procedural agreement
    % internally; this test baselines the expected verdict pattern on top.
    % Post-ADR-032 (72 h ingredient stores): LeanBroth fails throughput,
    % and HyperCook fails Cost AND Volume - its 20 kCr / 3 m3 margins
    % could not absorb 20,300 bowls of rack hardware. EverSimmer is the
    % only fully compliant variant; selection is forced, not scored.
    % Post-ADR-032 the count was 21 of 24.
    %
    % ADR-037 (bay status concentrators) took it to 20: HyperCook was
    % running at 498 of its 500 kW power cap, and six concentrators at
    % 0.4 kW each put it at 500.4. HyperCook now fails Power as well as
    % Cost and Volume - the clearest single illustration of what the
    % control hierarchy costs a variant with no margin left.

    methods (Test)
        function gateVerdicts(testCase)
            gate = runComplianceGate();
            testCase.verifySize(gate{:,1:8}, [3 8]);
            testCase.verifyEqual(nnz(gate{:,1:8}), 20, ...
                'expected exactly 20 of 24 gate checks to pass (ADR-037)');
            lb = gate({'LeanBroth'},:);
            testCase.verifyFalse(lb.Throughput, ...
                'LeanBroth must fail the throughput gate at behavioral fidelity');
            hc = gate({'HyperCook'},:);
            testCase.verifyFalse(hc.Cost,   'HyperCook must fail cost post-ADR-032');
            testCase.verifyFalse(hc.Volume, 'HyperCook must fail volume post-ADR-032');
            testCase.verifyFalse(hc.Power, ...
                'HyperCook must fail power post-ADR-037 (498 -> 500.4 of 500)');
            testCase.verifyTrue(all(gate{'EverSimmer',1:8}), ...
                'EverSimmer must remain the sole fully compliant variant');
            testCase.verifyEqual(gate.AllGatesPass, [false; false; true]);
        end
    end
end
