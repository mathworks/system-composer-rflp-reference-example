function results = runBehTests(mode)
%RUNBEHTESTS Run behavioral component cases through Simulink Test Manager.
%   results = runBehTests() runs BehaviorComponentTests.mldatx.
%   results = runBehTests("view") also opens Test Manager so the logged
%   outputs, baseline comparisons, tolerances, and assessments can be
%   inspected interactively.

arguments
    mode (1,1) string {mustBeMember(mode, ["run","view"])} = "run"
end

testFolder = fileparts(mfilename('fullpath'));
testFile = fullfile(testFolder, 'BehaviorComponentTests.mldatx');
assert(isfile(testFile), ...
    'Missing %s. Run buildBehaviorTestFile first.', testFile);

sltest.testmanager.clear;
sltest.testmanager.clearResults;
tf = sltest.testmanager.load(testFile);
results = run(tf);

fprintf('Behavior tests: %d passed, %d failed, %d incomplete\n', ...
    results.NumPassed, results.NumFailed, results.NumIncomplete);
assert(results.NumFailed == 0 && results.NumIncomplete == 0, ...
    'Behavioral component test run was not successful.');

if mode == "view"
    sltest.testmanager.view;
end
end
