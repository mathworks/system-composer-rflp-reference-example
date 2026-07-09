function spec = uncertaintySpec()
%UNCERTAINTYSPEC Parameter-uncertainty study definition (ADR-025).
%   Single source of truth for the Monte Carlo over PHYSICAL parameters:
%   which model-workspace variables are uncertain, their distributions,
%   the draw count, and the seeds. Both the simulation study
%   (runUncertaintySims) and the reproducibility test regenerate draws
%   from this spec, so there is exactly one place the study is defined.
%
%   The uncertain parameters are the QC-station estimates the behavioral
%   docs flag as engineering judgment rather than measurement: reject
%   fraction and calibration schedule. Distributions are triangular
%   (right-skewed where downside risk dominates: rejects and maintenance
%   run over, rarely under) and uniform for the calibration period.
%   All three variants share ONE Latin hypercube (common random numbers),
%   so cross-variant comparisons see the same "world" per draw.

spec.N = 200;              % parameter draws (x3 variants = 600 simulations)
spec.seedDraws = 7;        % LHS seed
spec.seedWeights = 42;     % Dirichlet weight seed (matches runTradeStudy)
spec.K = 25;               % weight draws per parameter draw (N*K = 5000 scores)
spec.T_STOP = 14400;       % nominal run length (s), same as runBehavioralAnalysis
spec.T_SS = 7200;          % steady-state window start (s)

% {model-workspace variable, distribution, params}
% tri: [lo mode hi] absolute; uniFrac/triFrac: multipliers on the nominal
spec.variants = struct( ...
  'HyperCook', struct('model','PhysicalHyperCook', 'params', {{ ...
     'HC_QCReject',        'tri',     [0.010 0.02 0.050], 1; ...
     'HC_QCCalibPeriod_s', 'uniFrac', [0.75 1.25],  3600; ...
     'HC_QCCalibTime_s',   'triFrac', [0.7 1 2.5],    60}}), ...
  'LeanBroth', struct('model','PhysicalLeanBroth', 'params', {{ ...
     'LB_QCReject',        'tri',     [0.015 0.03 0.070], 1; ...
     'LB_QCCalibPeriod_s', 'uniFrac', [0.75 1.25],  7200; ...
     'LB_QCCalibTime_s',   'triFrac', [0.7 1 2.5],   300}}), ...
  'EverSimmer', struct('model','PhysicalEverSimmer', 'params', {{ ...
     'ES_QCReject',        'tri',     [0.010 0.02 0.050], 1; ...
     'ES_QCCalibPeriod_s', 'uniFrac', [0.75 1.25],  5400; ...
     'ES_QCCalibTime_s',   'triFrac', [0.7 1 2.5],    90}}));

% One Latin hypercube shared by all variants (common random numbers)
rng(spec.seedDraws);
spec.U = lhsdesign(spec.N, 3);

% Realized parameter values per variant: N x 3 matrix each
for vn = fieldnames(spec.variants)'
    v = spec.variants.(vn{1});
    vals = zeros(spec.N, size(v.params,1));
    for j = 1:size(v.params,1)
        u = spec.U(:,j);
        switch v.params{j,2}
            case 'tri'
                vals(:,j) = triICDF(u, v.params{j,3});
            case 'uniFrac'
                f = v.params{j,3};
                vals(:,j) = (f(1) + u*(f(2)-f(1))) * v.params{j,4};
            case 'triFrac'
                vals(:,j) = triICDF(u, v.params{j,3}) * v.params{j,4};
        end
    end
    spec.variants.(vn{1}).values = vals;
end
end

function x = triICDF(u, p)
% inverse CDF of the triangular distribution [lo mode hi]
lo = p(1); md = p(2); hi = p(3);
Fm = (md-lo) / (hi-lo);
x = zeros(size(u));
lohalf = u < Fm;
x(lohalf)  = lo + sqrt(u(lohalf)   * (hi-lo) * (md-lo));
x(~lohalf) = hi - sqrt((1-u(~lohalf)) * (hi-lo) * (hi-md));
end
