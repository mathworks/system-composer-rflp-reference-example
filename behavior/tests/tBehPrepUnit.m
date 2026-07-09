classdef tBehPrepUnit < sltest.TestCase
    % tBehPrepUnit - Behavioral tests for the BehPrepUnit component model.
    %
    % Ports (fixed simulation order):
    %   Inports:  supply_bps, enable
    %   Outports: outflow_bps, demand_bps

    properties (Constant)
        ModelName = 'BehPrepUnit'
        PrepRateBph = 100 % must match model argument default
    end

    methods (Test)
        function capacityLimitedSteadyState(testCase)
            % Abundant supply should saturate outflow at PrepRate/3600
            % once the first-order lag settles.
            stopTime = 1200;
            hugeSupply = 1.0;
            extInput = sprintf('[0 %g 1; %g %g 1]', hugeSupply, stopTime, hugeSupply);

            out = testCase.runModel(extInput, stopTime);
            outflow = out.yout{1}.Values.Data;
            demand = out.yout{2}.Values.Data;

            capacityBps = tBehPrepUnit.PrepRateBph / 3600;
            testCase.verifyEqual(outflow(end), capacityBps, 'RelTol', 0.02);
            testCase.verifyEqual(demand(end), capacityBps, 'RelTol', 0.02);
        end

        function supplyLimitedSteadyState(testCase)
            % A supply below rated capacity should pass through at
            % steady state (lag settles to the input value).
            stopTime = 1200;
            scarceSupply = 0.01;
            extInput = sprintf('[0 %g 1; %g %g 1]', scarceSupply, stopTime, scarceSupply);

            out = testCase.runModel(extInput, stopTime);
            outflow = out.yout{1}.Values.Data;

            testCase.verifyEqual(outflow(end), scarceSupply, 'RelTol', 0.02);
        end

        function disabledUnitProducesNothing(testCase)
            % enable=0 should zero both outflow and demand regardless of
            % supply.
            stopTime = 600;
            extInput = sprintf('[0 1 0; %g 1 0]', stopTime);

            out = testCase.runModel(extInput, stopTime);
            outflow = out.yout{1}.Values.Data;
            demand = out.yout{2}.Values.Data;

            testCase.verifyEqual(outflow(end), 0, 'AbsTol', 1e-6);
            testCase.verifyEqual(demand(end), 0, 'AbsTol', 1e-9);
        end
    end

    methods (Static, Access = private)
        function out = runModel(extInput, stopTime, varargin)
            % Build and run a SimulationInput for BehPrepUnit.
            % varargin is a name/value list of model-argument overrides.
            in = Simulink.SimulationInput(tBehPrepUnit.ModelName);
            in = in.setModelParameter('LoadExternalInput', 'on', ...
                'ExternalInput', extInput, ...
                'StopTime', num2str(stopTime), ...
                'SaveOutput', 'on', ...
                'SaveFormat', 'Dataset');
            for k = 1:2:numel(varargin)
                in = in.setVariable(varargin{k}, varargin{k+1}, 'Workspace', tBehPrepUnit.ModelName);
            end
            simOut = sim(in);
            out = simOut;
        end
    end
end
