classdef (TestTags = {'analysis'}) tGateAgreement < sltest.TestCase
    % The formal Requirements Table gate and the expected verdicts.
    % runComplianceGate hard-asserts formal-vs-procedural agreement
    % internally; this test baselines the expected verdict pattern on top.
    % Post-ADR-032 (72 h ingredient stores): LeanBroth fails throughput,
    % and HyperCook fails Cost AND Volume - its 20 kCr / 3 m3 margins
    % could not absorb 20,300 bowls of rack hardware. EverSimmer is the
    % only fully compliant variant; selection is forced, not scored.

    methods (Test)
        function gateVerdicts(testCase)
            gate = runComplianceGate();
            testCase.verifySize(gate{:,1:8}, [3 8]);
            testCase.verifyEqual(nnz(gate{:,1:8}), 21, ...
                'expected exactly 21 of 24 gate checks to pass (ADR-032)');
            lb = gate({'LeanBroth'},:);
            testCase.verifyFalse(lb.Throughput, ...
                'LeanBroth must fail the throughput gate at behavioral fidelity');
            hc = gate({'HyperCook'},:);
            testCase.verifyFalse(hc.Cost,   'HyperCook must fail cost post-ADR-032');
            testCase.verifyFalse(hc.Volume, 'HyperCook must fail volume post-ADR-032');
            testCase.verifyTrue(all(gate{'EverSimmer',1:8}), ...
                'EverSimmer must remain the sole fully compliant variant');
            testCase.verifyEqual(gate.AllGatesPass, [false; false; true]);
        end
    end
end
