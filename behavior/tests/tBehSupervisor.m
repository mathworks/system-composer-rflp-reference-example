classdef tBehSupervisor < sltest.TestCase
    % tBehSupervisor - Behavioral tests for the BehSupervisor component model.
    %
    % Ports (fixed simulation order):
    %   Inports:  lineHealth (width 4), outFlow_bps
    %   Outports: lineEnable (width 4), plantMode (uint8)
    %
    % plantMode codes: 0 STARTUP, 1 NOMINAL, 2 DEGRADED, 3 HALTED.

    properties (Constant)
        ModelName = 'BehSupervisor'
        Startup = 0
        Nominal = 1
        Degraded = 2
        Halted = 3
    end

    methods (Test)
        function modeSequenceFollowsHealthAndFlow(testCase)
            % Drive: startup (no flow) -> nominal (flow appears) ->
            % degraded (line 2 unhealthy) -> recovery to nominal.
            stopTime = 300;
            % duplicated breakpoints make the stimulus step-like: the
            % ExternalInput matrix is linearly interpolated between rows
            extInput = ['[0 1 1 1 1 0; 10 1 1 1 1 0; 10.001 1 1 1 1 0.1; ' ...
                '100 1 1 1 1 0.1; 100.001 1 0 1 1 0.1; ' ...
                '200 1 0 1 1 0.1; 200.001 1 1 1 1 0.1]'];

            out = testCase.runModel(extInput, stopTime);

            plantMode = double(out.yout{2}.Values.Data);
            time = out.yout{2}.Values.Time;

            % Sample each phase after its transition should have settled.
            modeAtStartup = plantMode(find(time < 10, 1, 'last'));
            modeAtNominal = plantMode(find(time >= 10 & time < 100, 1, 'last'));
            modeAtDegraded = plantMode(find(time >= 100 & time < 200, 1, 'last'));
            modeAtRecovery = plantMode(end);

            testCase.verifyEqual(modeAtStartup, tBehSupervisor.Startup);
            testCase.verifyEqual(modeAtNominal, tBehSupervisor.Nominal);
            testCase.verifyEqual(modeAtDegraded, tBehSupervisor.Degraded);
            testCase.verifyEqual(modeAtRecovery, tBehSupervisor.Nominal);
        end

        function lineEnableTracksHealth(testCase)
            % Line 2's enable bit should drop to 0 exactly while its
            % health signal is unhealthy (< 0.5), and recover after.
            stopTime = 300;
            extInput = ['[0 1 1 1 1 0; 10 1 1 1 1 0; 10.001 1 1 1 1 0.1; ' ...
                '100 1 1 1 1 0.1; 100.001 1 0 1 1 0.1; ' ...
                '200 1 0 1 1 0.1; 200.001 1 1 1 1 0.1]'];

            out = testCase.runModel(extInput, stopTime);

            lineEnable = out.yout{1}.Values.Data; % Nx4
            time = out.yout{1}.Values.Time;
            line2Enable = lineEnable(:, 2);

            duringDegradedIdx = find(time >= 150 & time < 200, 1, 'last');
            afterRecoveryIdx = find(time >= 250, 1, 'last');

            testCase.verifyEqual(line2Enable(duringDegradedIdx), 0, 'AbsTol', 1e-9);
            testCase.verifyEqual(line2Enable(afterRecoveryIdx), 1, 'AbsTol', 1e-9);
        end

        function startupHoldsAllLinesEnabled(testCase)
            % Before any flow is established, the supervisor should be in
            % STARTUP with all lines enabled (healthy inputs held high).
            stopTime = 5;
            extInput = sprintf('[0 1 1 1 1 0; %g 1 1 1 1 0]', stopTime);

            out = testCase.runModel(extInput, stopTime);

            lineEnable = out.yout{1}.Values.Data;
            plantMode = double(out.yout{2}.Values.Data);

            testCase.verifyEqual(plantMode(end), tBehSupervisor.Startup);
            testCase.verifyEqual(lineEnable(end, :), ones(1, 4), 'AbsTol', 1e-9);
        end
    end

    methods (Static, Access = private)
        function out = runModel(extInput, stopTime, varargin)
            % Build and run a SimulationInput for BehSupervisor.
            % varargin is a name/value list of model-argument overrides.
            in = Simulink.SimulationInput(tBehSupervisor.ModelName);
            in = in.setModelParameter('LoadExternalInput', 'on', ...
                'ExternalInput', extInput, ...
                'StopTime', num2str(stopTime), ...
                'SaveOutput', 'on', ...
                'SaveFormat', 'Dataset');
            for k = 1:2:numel(varargin)
                in = in.setVariable(varargin{k}, varargin{k+1}, 'Workspace', tBehSupervisor.ModelName);
            end
            simOut = sim(in);
            out = simOut;
        end
    end
end
