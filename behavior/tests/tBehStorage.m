classdef tBehStorage < sltest.TestCase
    % tBehStorage - Behavioral tests for the BehStorage component model.
    %
    % Ports (fixed simulation order):
    %   Inports:  inflow_bps, draw_bps
    %   Outports: outflow_bps, level_bowls, starved

    properties (Constant)
        ModelName = 'BehStorage'
    end

    methods (Test)
        function conservationOfMass(testCase)
            % With steady inflow > draw and no starvation, level should
            % rise by roughly (inflow-draw)*time and outflow should track
            % draw closely (relay open the whole run).
            stopTime = 1000;
            inflowBps = 0.2;
            drawBps = 0.1;
            extInput = sprintf('[0 %g %g; %g %g %g]', inflowBps, drawBps, stopTime, inflowBps, drawBps);

            out = testCase.runModel(extInput, stopTime);

            level = out.yout{2}.Values.Data;
            outflow = out.yout{1}.Values.Data;

            expectedLevel = 500 + drawBps * stopTime; % net drop; InitLevel default 500
            testCase.verifyEqual(level(end), expectedLevel, 'RelTol', 0.01);
            testCase.verifyEqual(mean(outflow(end-5:end)), drawBps, 'RelTol', 0.05);
        end

        function starvationDropsOutflow(testCase)
            % Starting near empty with draw exceeding inflow should drain
            % the bowl, trip the starved flag, and choke off outflow.
            stopTime = 200;
            extInput = sprintf('[0 0 0.5; %g 0 0.5]', stopTime);

            out = testCase.runModel(extInput, stopTime, 'InitLevel_bowls', 1);

            level = out.yout{2}.Values.Data;
            starved = out.yout{3}.Values.Data;
            outflow = out.yout{1}.Values.Data;
            time = out.yout{1}.Values.Time;

            testCase.verifyLessThan(level(end), 0.5);
            testCase.verifyEqual(starved(end), 1, 'AbsTol', 1e-9);

            tailIdx = time >= (stopTime - 100);
            testCase.verifyLessThan(mean(outflow(tailIdx)), 0.05);
        end

        function capacityClamp(testCase)
            % Filling near-full storage should saturate level at capacity,
            % never overshooting it.
            stopTime = 100;
            extInput = sprintf('[0 1 0; %g 1 0]', stopTime);

            out = testCase.runModel(extInput, stopTime, 'InitLevel_bowls', 990);

            level = out.yout{2}.Values.Data;
            testCase.verifyEqual(level(end), 1000, 'RelTol', 0.005);
            testCase.verifyLessThanOrEqual(max(level), 1000 + 1e-6);
        end
    end

    methods (Static, Access = private)
        function out = runModel(extInput, stopTime, varargin)
            % Build and run a SimulationInput for BehStorage.
            % varargin is a name/value list of model-argument overrides.
            in = Simulink.SimulationInput(tBehStorage.ModelName);
            in = in.setModelParameter('LoadExternalInput', 'on', ...
                'ExternalInput', extInput, ...
                'StopTime', num2str(stopTime), ...
                'SaveOutput', 'on', ...
                'SaveFormat', 'Dataset');
            for k = 1:2:numel(varargin)
                in = in.setVariable(varargin{k}, varargin{k+1}, ...
                    'Workspace', tBehStorage.ModelName);
            end
            simOut = sim(in);
            out = simOut;
        end
    end
end
