classdef tBehCookVat < sltest.TestCase
    % tBehCookVat - Behavioral tests for the BehCookVat component model.
    %
    % Ports (fixed simulation order):
    %   Inports:  supply_bps, enable
    %   Outports: outflow_bps, power_kW, vatTemp_C, state, hopperLevel_bowls
    %
    % state codes: 0 Idle, 1 Fill, 2 Heat, 3 Simmer, 4 Drain, 5 Clean.
    %
    % Contains a Simscape thermal network, so each simulation takes a few
    % seconds; StopTime is kept at or below 5400 s per guidance.

    properties (Constant)
        ModelName = 'BehCookVat'
        BatchSizeBowls = 50 % must match model argument default
        DrainState = 4
    end

    methods (Test)
        function referenceCycleWithDefaults(testCase)
            % Empirically verified reference run: full fill/heat/simmer/
            % drain/clean cycle repeats three times over 5400 s.
            stopTime = 5400;
            extInput = sprintf('[0 0.5 1; %g 0.5 1]', stopTime);

            out = testCase.runModel(extInput, stopTime);

            state = out.yout{4}.Values.Data;
            vatTemp = out.yout{3}.Values.Data;
            time3 = out.yout{3}.Values.Time;
            outflow = out.yout{1}.Values.Data;
            time1 = out.yout{1}.Values.Time;
            power = out.yout{2}.Values.Data;

            % All six states should be visited at least once.
            testCase.verifyEqual(double(sort(unique(state)))', 0:5);

            testCase.verifyEqual(tBehCookVat.countDrainEvents(state), 3);

            totalDrained = trapz(time1, outflow);
            testCase.verifyEqual(totalDrained, 150, 'AbsTol', 1);

            testCase.verifyGreaterThanOrEqual(max(vatTemp), 94);
            testCase.verifyLessThanOrEqual(max(vatTemp), 99);

            afterWarmupIdx = time3 > 100;
            testCase.verifyLessThan(min(vatTemp(afterWarmupIdx)), 20);

            testCase.verifyEqual(max(power), 40, 'RelTol', 0.02);
        end

        function disabledVatStaysIdle(testCase)
            % enable=0 should keep the vat in Idle with negligible flow
            % and power draw.
            stopTime = 1000;
            extInput = sprintf('[0 0.5 0; %g 0.5 0]', stopTime);

            out = testCase.runModel(extInput, stopTime);

            state = out.yout{4}.Values.Data;
            outflow = out.yout{1}.Values.Data;
            time1 = out.yout{1}.Values.Time;
            power = out.yout{2}.Values.Data;

            testCase.verifyEqual(double(unique(state)), 0);
            testCase.verifyLessThan(trapz(time1, outflow), 0.1);
            testCase.verifyEqual(mean(power), 0, 'AbsTol', 1e-6);
        end

        function batchIntegrityAcrossDrains(testCase)
            % Total bowls drained should be an integer multiple of
            % BatchSize_bowls (one full batch is drained per cycle).
            stopTime = 5400;
            extInput = sprintf('[0 0.5 1; %g 0.5 1]', stopTime);

            out = testCase.runModel(extInput, stopTime);

            outflow = out.yout{1}.Values.Data;
            time1 = out.yout{1}.Values.Time;
            totalDrained = trapz(time1, outflow);

            numBatches = totalDrained / tBehCookVat.BatchSizeBowls;
            testCase.verifyEqual(numBatches, round(numBatches), 'AbsTol', 0.02);
        end
    end

    methods (Static, Access = private)
        function out = runModel(extInput, stopTime, varargin)
            % Build and run a SimulationInput for BehCookVat.
            % varargin is a name/value list of model-argument overrides.
            in = Simulink.SimulationInput(tBehCookVat.ModelName);
            in = in.setModelParameter('LoadExternalInput', 'on', ...
                'ExternalInput', extInput, ...
                'StopTime', num2str(stopTime), ...
                'SaveOutput', 'on', ...
                'SaveFormat', 'Dataset');
            for k = 1:2:numel(varargin)
                in = in.setVariable(varargin{k}, varargin{k+1}, 'Workspace', tBehCookVat.ModelName);
            end
            simOut = sim(in);
            out = simOut;
        end

        function n = countDrainEvents(state)
            % Count rising-edge entries into the Drain state.
            enteredDrain = (state(2:end) == tBehCookVat.DrainState) & ...
                (state(1:end-1) ~= tBehCookVat.DrainState);
            n = sum(enteredDrain);
        end
    end
end
