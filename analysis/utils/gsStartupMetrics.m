function s = gsStartupMetrics(sig, opts)
%GSSTARTUPMETRICS Cold-start transient metrics for one plant simulation.
%   S = GSSTARTUPMETRICS(SIG, OPTS) answers two separate questions that
%   SR-GS-025 conflates if only one number is reported:
%
%     TimeToFirstSoup_s   when does COOKED SOUP first exist (cook-stage
%                         output), i.e. the cooking process has produced
%     TimeToFirstOut_s    when does the first PACKAGED bowl leave the
%                         plant at the root OutboundShipments port
%     TimeToNominal_s     when does the plant reach - and HOLD - its
%                         nominal production rate from cold
%
%   SIG fields (all Simulink timeseries, variable-step time base OK):
%     .flow    packaged flow at the root port            (bowls/s)
%     .soup    cook-stage soup flow, summed over lines   (bowls/s)
%     .mode    supervisor plant mode                     (1 = Nominal)
%     .power   total plant power                         (kW, optional)
%
%   OPTS fields (all optional, defaults in DEFAULTS below):
%     .SteadyStart_s  start of the steady-state averaging window
%     .Window_s       trailing window converting flow to a production RATE
%     .Band           settle band as a fraction of steady state (0.05 = 5%)
%     .Dwell_s        the rate must stay inside the band this long
%     .Floor_bph      SR-GS-002 throughput floor, for the secondary metric
%     .Eps_bps        flow above which material counts as "produced"
%
%   TimeToNominal_s uses a DWELL BAND, not a first crossing: batch-vat
%   variants ring hard on startup and cross their steady rate several
%   times before holding it (ADR-040). A first-crossing test would report
%   the first spike of a batch drain as "nominal".
%
%   Rate is a TRAILING integral difference over Window_s - the same
%   quantity an operator reads off a shift counter - so the reported
%   settle time is never earlier than the plant has actually sustained
%   the rate for a full window.
%
%   Shared by runBehavioralAnalysis, runStartupStudy, and the Simulink
%   Test custom criteria so the three cannot drift apart.

arguments
    sig  (1,1) struct
    opts (1,1) struct = struct()
end

DEFAULTS = struct('SteadyStart_s', 7200, 'Window_s', 300, 'Band', 0.05, ...
    'Dwell_s', 600, 'Floor_bph', 200, 'Eps_bps', 1e-3);
opts = applyDefaults(opts, DEFAULTS);

% --- uniform 1 s grid: the variable-step time base is not usable for
% window arithmetic, and interpolation error at 1 s is far below the
% resolution any of these metrics are reported at
tEnd = sig.flow.Time(end);
t = (0:1:floor(tEnd))';
flow = interp1(uniqueTimes(sig.flow.Time), double(sig.flow.Data(uniqueIdx(sig.flow.Time))), ...
    t, 'linear', 0);

s = struct();
s.TimeToFirstSoup_s = firstAbove(sig.soup, opts.Eps_bps);
s.TimeToFirstOut_s  = firstAbove(sig.flow, opts.Eps_bps);
s.PipelineLag_s     = s.TimeToFirstOut_s - s.TimeToFirstSoup_s;

% --- steady-state reference: identical definition to the SimThroughput_bph
% already reported by runBehavioralAnalysis, so the two agree by construction
ss = sig.flow.Time >= opts.SteadyStart_s;
assert(any(ss), 'gs:noSteadyWindow', ...
    'Run ends at %g s, before the %g s steady-state window opens.', ...
    tEnd, opts.SteadyStart_s);
s.SteadyThroughput_bph = trapz(sig.flow.Time(ss), double(sig.flow.Data(ss))) ...
    / (tEnd - opts.SteadyStart_s) * 3600;

% --- trailing production rate (bph), NaN until a full window exists
w = round(opts.Window_s);
bowls = cumtrapz(t, flow);
rate = NaN(size(t));
rate(w+1:end) = (bowls(w+1:end) - bowls(1:end-w)) / opts.Window_s * 3600;

s.TimeToNominal_s = settleTime(t, rate, (1 - opts.Band) * s.SteadyThroughput_bph, opts.Dwell_s);
s.TimeToFloor_s   = settleTime(t, rate, opts.Floor_bph, opts.Dwell_s);
s.SettleBand_bph  = (1 - opts.Band) * s.SteadyThroughput_bph;

% --- when the supervisor enters RUNNING (all lines healthy, material
% flowing). That is a health/flow state, NOT a production-rate one
% (ADR-043), so it lands far earlier than the measured settle; the lead
% is reported to keep the two from being confused for each other.
s.TimeToModeRunning_s = firstAt(sig.mode, 1);
s.ModeLead_s = s.TimeToNominal_s - s.TimeToModeRunning_s;

% --- energy burned before the plant is earning: undefined if never settled
if isfield(sig, 'power') && ~isempty(sig.power)
    if isnan(s.TimeToNominal_s)
        s.StartupEnergy_kWh = NaN;
    else
        pre = sig.power.Time <= s.TimeToNominal_s;
        s.StartupEnergy_kWh = trapz(sig.power.Time(pre), double(sig.power.Data(pre))) / 3600;
    end
else
    s.StartupEnergy_kWh = NaN;
end

s.Rate_t = t;
s.Rate_bph = rate;
end

% =====================================================================

function tu = uniqueTimes(tv)
% A variable-step solver emits repeated time points at zero crossings -
% batch drains produce plenty - and interp1 rejects duplicate sample
% points. Keep the LAST sample at each instant: it is the post-event
% value, which is the one a rate calculation should see.
tu = tv(uniqueIdx(tv));
end

function idx = uniqueIdx(tv)
[~, idx] = unique(tv, 'last');
idx = sort(idx);
end

function tf = firstAbove(ts, eps_)
% first time a signal exceeds eps_; NaN if it never does
if isempty(ts)
    tf = NaN;
    return
end
k = find(double(ts.Data) > eps_, 1);
if isempty(k), tf = NaN; else, tf = ts.Time(k); end
end

function tf = firstAt(ts, value)
% first time a (discrete) signal takes the given value; NaN if never
if isempty(ts)
    tf = NaN;
    return
end
k = find(double(ts.Data) == value, 1);
if isempty(k), tf = NaN; else, tf = ts.Time(k); end
end

function tf = settleTime(t, rate, threshold, dwell_s)
% First time RATE reaches THRESHOLD and STAYS there for DWELL_S.
% A window that runs past the end of the record cannot be shown to hold,
% so it does not qualify - which makes this metric conservative and makes
% a too-short run report NaN rather than a flattering number.
n = round(dwell_s / (t(2) - t(1)));
assert(n < numel(t), 'gs:runTooShort', ...
    'Run is shorter than the %g s settle dwell.', dwell_s);
ok = rate >= threshold;
ok(isnan(rate)) = false;
held = movmin(double(ok), [0 n]) > 0;
held(end-n+1:end) = false;
k = find(held, 1);
if isempty(k), tf = NaN; else, tf = t(k); end
end

function opts = applyDefaults(opts, defaults)
f = fieldnames(defaults);
for i = 1:numel(f)
    if ~isfield(opts, f{i}) || isempty(opts.(f{i}))
        opts.(f{i}) = defaults.(f{i});
    end
end
end
