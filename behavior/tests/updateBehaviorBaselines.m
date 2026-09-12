function updateBehaviorBaselines(confirmUpdate)
%UPDATEBEHAVIORBASELINES Recapture native Test Manager waveform baselines.
%   updateBehaviorBaselines(true) deliberately replaces all 21 waveform
%   baselines and rebuilds BehaviorComponentTests.mldatx.

arguments
    confirmUpdate (1,1) logical = false
end
assert(confirmUpdate, ['Baseline replacement is intentionally explicit. ' ...
    'Call updateBehaviorBaselines(true) after reviewing model changes.']);
buildBehaviorTestFile(true);
end
