classdef tBehQCStation < sltest.TestCase
    % tBehQCStation - Behavioral tests for the BehQCStation component model.
    %
    % Ports (fixed simulation order):
    %   Inports:  inflow_bps, enable
    %   Outports: passflow_bps, rejectflow_bps, calibrating

    properties (Constant)
        ModelName = 'BehQCStation'
        RejectFrac = 0.02 % must match model argument default
    end

    methods (Test)
        function passRejectSplitRatio(testCase)
            % With calibration pushed far out, the station should stay in
            % Inspecting mode and split flow by (1-RejectFrac)/RejectFrac.
            stopTime = 2000;
            inflowBps = 0.02;
            extInput = sprintf('[0 %g 1; %g %g 1]', inflowBps, stopTime, inflowBps);

            out = testCase.runModel(extInput, stopTime, 'CalibPeriod_s', 1e6);

            time = out.yout{1}.Values.Time;
            passflow = out.yout{1}.Values.Data;
            rejectflow = out.yout{2}.Values.Data;

            tailIdx = time >= (stopTime - 500);
            meanPass = mean(passflow(tailIdx));
            meanReject = mean(rejectflow(tailIdx));

            testCase.verifyEqual(meanPass / (meanPass + meanReject), 1 - tBehQCStation.RejectFrac, 'RelTol', 0.01);
            testCase.verifyEqual(meanPass + meanReject, inflowBps, 'RelTol', 0.02);
        end

        function calibrationOutageBlocksFlow(testCase)
            % A short calibration period/time should trigger a visible
            % calibration outage window where passflow collapses.
            stopTime = 800;
            calibPeriodS = 300;
            calibTimeS = 100;
            extInput = sprintf('[0 0.02 1; %g 0.02 1]', stopTime);

            out = testCase.runModel(extInput, stopTime, 'CalibPeriod_s', calibPeriodS, 'CalibTime_s', calibTimeS);

            time = out.yout{1}.Values.Time;
            passflow = out.yout{1}.Values.Data;
            calibrating = out.yout{3}.Values.Data;

            testCase.verifyEqual(max(calibrating), 1, 'AbsTol', 1e-9);

            outageIdx = time >= 310 & time <= 390;
            nominalPass = 0.02 * (1 - tBehQCStation.RejectFrac);
            testCase.verifyLessThan(mean(passflow(outageIdx)), 0.10 * nominalPass);
        end

        function contaminationDetectionSplit(testCase)
            % SR-GS-007 component-level: contamination applies to the
            % quality-passed stream, detected mass moves to rejects at
            % DetectSensitivity, escaped mass ships with the passed flow.
            stopTime = 2000;
            inflowBps = 0.02;
            inc = 0.05; sens = 0.995;
            extInput = sprintf('[0 %g 1; %g %g 1]', inflowBps, stopTime, inflowBps);

            out = testCase.runModel(extInput, stopTime, 'CalibPeriod_s', 1e6, ...
                'ContamIncidence', inc, 'DetectSensitivity', sens);

            time = out.yout{1}.Values.Time;
            tailIdx = time >= (stopTime - 500);
            passOut = mean(out.yout{1}.Values.Data(tailIdx));
            rejOut  = mean(out.yout{2}.Values.Data(tailIdx));
            det     = mean(out.yout{4}.Values.Data(tailIdx));
            esc     = mean(out.yout{5}.Values.Data(tailIdx));

            passQ  = inflowBps * (1 - tBehQCStation.RejectFrac);
            contam = passQ * inc;
            testCase.verifyEqual(det, contam * sens, 'RelTol', 0.01, 'detected split');
            testCase.verifyEqual(esc, contam * (1 - sens), 'RelTol', 0.01, 'escaped split');
            testCase.verifyEqual(det / (det + esc), sens, 'RelTol', 1e-6, 'sensitivity exact');
            testCase.verifyEqual(passOut, passQ - det, 'RelTol', 0.01, 'pass stream loses detected');
            testCase.verifyEqual(rejOut, inflowBps * tBehQCStation.RejectFrac + det, ...
                'RelTol', 0.01, 'reject stream gains detected');
            % conservation: nothing created or destroyed by detection
            testCase.verifyEqual(passOut + rejOut, inflowBps, 'RelTol', 0.02, 'mass conservation');
        end

        function disabledStationBlocksFlow(testCase)
            % enable<0.5 should stop the pass stream entirely.
            stopTime = 200;
            extInput = sprintf('[0 0.02 0; %g 0.02 0]', stopTime);

            out = testCase.runModel(extInput, stopTime);
            passflow = out.yout{1}.Values.Data;

            testCase.verifyEqual(passflow(end), 0, 'AbsTol', 1e-6);
        end
    end

    methods (Static, Access = private)
        function out = runModel(extInput, stopTime, varargin)
            % Build and run a SimulationInput for BehQCStation.
            % varargin is a name/value list of model-argument overrides.
            in = Simulink.SimulationInput(tBehQCStation.ModelName);
            in = in.setModelParameter('LoadExternalInput', 'on', ...
                'ExternalInput', extInput, ...
                'StopTime', num2str(stopTime), ...
                'SaveOutput', 'on', ...
                'SaveFormat', 'Dataset');
            for k = 1:2:numel(varargin)
                in = in.setVariable(varargin{k}, varargin{k+1}, 'Workspace', tBehQCStation.ModelName);
            end
            simOut = sim(in);
            out = simOut;
        end
    end
end
