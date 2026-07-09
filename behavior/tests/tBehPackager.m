classdef tBehPackager < sltest.TestCase
    % tBehPackager - Behavioral tests for the BehPackager component model.
    %
    % Ports (fixed simulation order):
    %   Inports:  supply_bps, enable
    %   Outports: outflow_bps

    properties (Constant)
        ModelName = 'BehPackager'
        PackRateBph = 200 % must match model argument default
    end

    methods (Test)
        function capacityLimitedSteadyState(testCase)
            % Abundant supply should saturate outflow at PackRate/3600
            % once the first-order lag settles.
            stopTime = 900;
            hugeSupply = 1.0;
            extInput = sprintf('[0 %g 1; %g %g 1]', hugeSupply, stopTime, hugeSupply);

            out = testCase.runModel(extInput, stopTime);
            outflow = out.yout{1}.Values.Data;

            capacityBps = tBehPackager.PackRateBph / 3600;
            testCase.verifyEqual(outflow(end), capacityBps, 'RelTol', 0.02);
        end

        function supplyLimitedPassThrough(testCase)
            % A supply below rated capacity should pass through at
            % steady state.
            stopTime = 900;
            scarceSupply = 0.02;
            extInput = sprintf('[0 %g 1; %g %g 1]', scarceSupply, stopTime, scarceSupply);

            out = testCase.runModel(extInput, stopTime);
            outflow = out.yout{1}.Values.Data;

            testCase.verifyEqual(outflow(end), scarceSupply, 'RelTol', 0.02);
        end

        function disabledPackagerProducesNothing(testCase)
            % enable=0 should zero outflow regardless of supply.
            stopTime = 400;
            extInput = sprintf('[0 1 0; %g 1 0]', stopTime);

            out = testCase.runModel(extInput, stopTime);
            outflow = out.yout{1}.Values.Data;

            testCase.verifyEqual(outflow(end), 0, 'AbsTol', 1e-6);
        end
    end

    methods (Static, Access = private)
        function out = runModel(extInput, stopTime, varargin)
            % Build and run a SimulationInput for BehPackager.
            % varargin is a name/value list of model-argument overrides.
            in = Simulink.SimulationInput(tBehPackager.ModelName);
            in = in.setModelParameter('LoadExternalInput', 'on', ...
                'ExternalInput', extInput, ...
                'StopTime', num2str(stopTime), ...
                'SaveOutput', 'on', ...
                'SaveFormat', 'Dataset');
            for k = 1:2:numel(varargin)
                in = in.setVariable(varargin{k}, varargin{k+1}, 'Workspace', tBehPackager.ModelName);
            end
            simOut = sim(in);
            out = simOut;
        end
    end
end
