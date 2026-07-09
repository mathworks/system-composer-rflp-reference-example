classdef tBehCookLine < sltest.TestCase
    % tBehCookLine - Behavioral tests for the BehCookLine component model.
    %
    % Ports (fixed simulation order):
    %   Inports:  supply_bps, enable
    %   Outports: outflow_bps, power_kW

    properties (Constant)
        ModelName = 'BehCookLine'
        CookRateBph = 90    % must match model argument default
        PowerFullKW = 50
        PowerIdleKW = 8
    end

    methods (Test)
        function fullLoadSteadyState(testCase)
            % Abundant supply drives the line to full cook rate and full
            % power draw once the thermal lag settles.
            stopTime = 2000;
            extInput = sprintf('[0 1 1; %g 1 1]', stopTime);

            out = testCase.runModel(extInput, stopTime);
            outflow = out.yout{1}.Values.Data;
            power = out.yout{2}.Values.Data;

            capacityBps = tBehCookLine.CookRateBph / 3600;
            testCase.verifyEqual(outflow(end), capacityBps, 'RelTol', 0.02);
            testCase.verifyEqual(power(end), tBehCookLine.PowerFullKW, 'RelTol', 0.02);
        end

        function halfLoadSteadyState(testCase)
            % Supply pinned at 25% of capacity should settle power at
            % idle + 0.25*(full-idle).
            stopTime = 2000;
            quarterCapacitySupply = 0.25 * tBehCookLine.CookRateBph / 3600;
            extInput = sprintf('[0 %g 1; %g %g 1]', quarterCapacitySupply, stopTime, quarterCapacitySupply);

            out = testCase.runModel(extInput, stopTime);
            power = out.yout{2}.Values.Data;

            expectedPower = tBehCookLine.PowerIdleKW + 0.25 * (tBehCookLine.PowerFullKW - tBehCookLine.PowerIdleKW);
            testCase.verifyEqual(power(end), expectedPower, 'RelTol', 0.05);
        end

        function disabledLineIdles(testCase)
            % enable=0 should drop outflow and power to zero regardless
            % of supply.
            stopTime = 600;
            extInput = sprintf('[0 1 0; %g 1 0]', stopTime);

            out = testCase.runModel(extInput, stopTime);
            outflow = out.yout{1}.Values.Data;
            power = out.yout{2}.Values.Data;

            testCase.verifyEqual(outflow(end), 0, 'AbsTol', 1e-6);
            testCase.verifyEqual(power(end), 0, 'AbsTol', 1e-6);
        end
    end

    methods (Static, Access = private)
        function out = runModel(extInput, stopTime, varargin)
            % Build and run a SimulationInput for BehCookLine.
            % varargin is a name/value list of model-argument overrides.
            in = Simulink.SimulationInput(tBehCookLine.ModelName);
            in = in.setModelParameter('LoadExternalInput', 'on', ...
                'ExternalInput', extInput, ...
                'StopTime', num2str(stopTime), ...
                'SaveOutput', 'on', ...
                'SaveFormat', 'Dataset');
            for k = 1:2:numel(varargin)
                in = in.setVariable(varargin{k}, varargin{k+1}, 'Workspace', tBehCookLine.ModelName);
            end
            simOut = sim(in);
            out = simOut;
        end
    end
end
