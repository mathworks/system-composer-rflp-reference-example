% runBehTests - Run all behavioral component tests in this folder and
% fail loudly if any test does not pass.
testFolder = fileparts(mfilename('fullpath'));
results = runtests(testFolder);

table(results)

assertSuccess(results);
