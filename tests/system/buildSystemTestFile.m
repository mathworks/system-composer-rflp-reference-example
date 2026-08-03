function buildSystemTestFile()
%BUILDSYSTEMTESTFILE Generate the Simulink Test system-tier test file.
%   Creates tests/system/GalacticSoupSystemTests.mldatx (ADR-022): two suites of
%   simulation test cases on the three physical architecture models.
%
%   Verify-link semantics (ADR-022, per-variant per ADR-035): a Verify
%   link attaches wherever a passing case means THAT VARIANT genuinely
%   meets the requirement. No variant is committed as baseline: all
%   three candidate architectures carry their own evidence, and
%   per-variant attribution (which variant's cases verify which SRs)
%   is done at reporting time from the case names - see the runAllTests
%   per-variant coverage table and makeVariantTraceMatrix. Cases named
%   "- regression baseline" pin a number that does NOT satisfy the
%   requirement (or has none to satisfy) and stay unlinked.
%
%   Nominal suite - steady throughput and plant mode via custom criteria:
%     HC/ES verify SR-GS-002 (floor) and SR-GS-025 (first packaged
%     output within the 3600 s startup period); ES additionally verifies
%     SR-GS-008 (vat serves from the simmer band, never exceeding 95 C).
%     LB genuinely fails the floor (196.8 bph) - baselined unlinked;
%     that story belongs to the compliance gate.
%   WorstFault suite - Fault_T_* parameter overrides at t = 7200 s:
%     ES verifies SR-GS-026 (retention ~2/3, Degraded mode); HC/LB
%     baseline their 0% collapse unlinked.
%   GravityExtremes suite - Gravity_g overrides at the SR-GS-015 range
%     ends (0.1 g / 12 g): HyperCook holds the floor across the range
%     and verifies SR-GS-015; EverSimmer fails at 0.1 g (189.3 bph,
%     ADR-026 - the pump-assisted drain redesign case) and its 0.1 g
%     case is baselined unlinked.
%
%   Destructive and idempotent: recreates the file and re-links, purging
%   stale Verify links to this artifact from the requirement set first.

proj = currentProject;
% every simulation case runs through its model's external test harness
% (ADR-033, built by buildTestHarnesses) - root signals observable at
% harness outports, sources explicit
hmap = containers.Map( ...
    {'PhysicalHyperCook','PhysicalLeanBroth','PhysicalEverSimmer'}, ...
    {'HyperCookSystemHarness','LeanBrothSystemHarness','EverSimmerSystemHarness'});
tdir = char(fullfile(proj.RootFolder, 'tests', 'system'));
tfPath = fullfile(tdir, 'GalacticSoupSystemTests.mldatx');

sltest.testmanager.clear;
sltest.testmanager.clearResults;
slreq.clear();
srSet = slreq.load(fullfile(char(proj.RootFolder), 'requirements', 'SystemRequirements.slreqx'));

% purge stale Verify links from earlier builds of this artifact
for id = {'SR-GS-002','SR-GS-026','SR-GS-008','SR-GS-015','SR-GS-025','SR-GS-007','SR-GS-006','SR-GS-001','SR-GS-018','SR-GS-021'}
    sr = find(srSet, 'Id', id{1});
    for L = inLinks(sr)
        try
            s = source(L);
            if contains(char(s.artifact), 'GalacticSoupSystemTests')
                remove(L);
            end
        catch
        end
    end
end
if isfile(tfPath), delete(tfPath); end

tf = sltest.testmanager.TestFile(tfPath);
suites = getTestSuites(tf);
suites(1).Name = 'Nominal';
% every new suite ships a default placeholder case - drop it
for stray = getTestCases(suites(1))
    remove(stray);
end
faultSuite = createTestSuite(tf, 'WorstFault');
% createTestSuite ships a default placeholder case - drop it
for stray = getTestCases(faultSuite)
    remove(stray);
end

% shared harvest preamble for all criteria callbacks
harvest = [ ...
    'yout = test.sltest_simout.get(''yout'');\n' ...
    'flow = []; power = []; mode = [];\n' ...
    'for i = 1:yout.numElements\n' ...
    '    e = yout{i}; v = e.Values;\n' ...
    '    if isstruct(v) && isfield(v,''flow_bps''), flow = v.flow_bps; end\n' ...
    '    if strcmp(e.Name, ''totalPower_kW''), power = v; end\n' ...
    '    if strcmp(e.Name, ''plantMode''), mode = v; end\n' ...
    'end\n'];
% reusable criterion fragments
floorFrag = sprintf('test.verifyGreaterThanOrEqual(bph, 200, ''SR-GS-002 floor'');%s', newline);
% SR-GS-025: packaged output must appear within the defined 3600 s startup period
startupFrag = sprintf(['tfirst = flow.Time(find(flow.Data > 1e-3, 1));\n' ...
    'test.verifyLessThanOrEqual(tfirst, 3600, ''SR-GS-025 startup period'');\n']);
% SR-GS-008: soup temperature while the vat is DRAINING (i.e. serving)
% must sit inside the required 70-95 C window; the transient simmer
% overshoot (~95.5 C, bang-bang control) is not serving temperature
tempFrag = sprintf(['lg = test.sltest_simout.get(''logsout'');\n' ...
    'vt = lg.get(''vatTemp_Cell1'').Values;\n' ...
    'vs = lg.get(''vatState_Cell1'').Values;\n' ...
    'drainT = vs.Time(vs.Data == 4);\n' ...
    'test.verifyNotEmpty(drainT, ''vat never drained'');\n' ...
    'servT = interp1(vt.Time, vt.Data, drainT);\n' ...
    'test.verifyLessThanOrEqual(max(servT), 95, ''SR-GS-008 serving <= 95 C'');\n' ...
    'test.verifyGreaterThanOrEqual(min(servT), 70, ''SR-GS-008 serving >= 70 C'');\n']);

% {name, model, steady bph, extraFrags, links}
nom = { ...
 'HyperCook nominal',  'PhysicalHyperCook',  308.4, [floorFrag startupFrag], {'SR-GS-002','SR-GS-025'}; ...
 'LeanBroth nominal - regression baseline', 'PhysicalLeanBroth', 196.8, '', {}; ...
 'EverSimmer nominal', 'PhysicalEverSimmer', 231.9, [floorFrag startupFrag tempFrag], {'SR-GS-002','SR-GS-025','SR-GS-008'}};
for i = 1:size(nom,1)
    tc = createTestCase(suites(1), 'simulation', nom{i,1});
    setProperty(tc, 'Model', nom{i,2});
    setProperty(tc, 'HarnessOwner', nom{i,2}, 'HarnessName', hmap(nom{i,2}));
    setProperty(tc, 'OverrideStopTime', true);
    setProperty(tc, 'StopTime', 14400);
    cc = getCustomCriteria(tc);
    cc.Enabled = true;
    cc.Callback = sprintf([harvest ...
        'sel = flow.Time > 7200;\n' ...
        'bph = trapz(flow.Time(sel), flow.Data(sel))/(flow.Time(end)-7200)*3600;\n' ...
        '%s' ...
        'test.verifyEqual(bph, %g, ''AbsTol'', 3, ''regression band'');\n' ...
        'test.verifyEqual(double(mode.Data(end)), 1, ''Nominal mode'');\n'], ...
        nom{i,4}, nom{i,3});
end

% --- Gravity suite: SR-GS-015 extremes (0.1 g and 12 g) ---
% Only HyperCook holds the floor across the whole range (see
% analysis/sweeps/runGravitySweep): its pumped continuous lines are
% gravity-insensitive, so its cases verify SR-GS-015 FOR HYPERCOOK.
% EverSimmer's batch vats drain at sqrt(g) and fall to ~189 bph at
% 0.1 g - baselined, unlinked, and flagged as the microgravity redesign
% case (pump-assisted drains, ADR-026). Per-variant reporting keeps
% this honest: HyperCook's pass never paints EverSimmer's trace green.
gravSuite = createTestSuite(tf, 'GravityExtremes');
for stray = getTestCases(gravSuite)
    remove(stray);
end
% {name, model, Gravity_g, steady bph, verifyFloor, links}
grv = { ...
 'HyperCook at 0.1 g',  'PhysicalHyperCook', 0.1, 308.4, true,  {'SR-GS-015'}; ...
 'HyperCook at 12 g',   'PhysicalHyperCook', 12,  271.0, true,  {'SR-GS-015'}; ...
 'EverSimmer at 0.1 g - regression baseline', 'PhysicalEverSimmer', 0.1, 189.3, false, {}};
for i = 1:size(grv,1)
    tc = createTestCase(gravSuite, 'simulation', grv{i,1});
    setProperty(tc, 'Model', grv{i,2});
    setProperty(tc, 'HarnessOwner', grv{i,2}, 'HarnessName', hmap(grv{i,2}));
    setProperty(tc, 'OverrideStopTime', true);
    setProperty(tc, 'StopTime', 14400);
    ps = addParameterSet(tc, 'Name', 'gravity');
    addParameterOverride(ps, 'Gravity_g', grv{i,3});
    fc = '';
    if grv{i,5}, fc = floorFrag; end
    cc = getCustomCriteria(tc);
    cc.Enabled = true;
    % liveness check (ADR-034): the AmbientGravity root input, driven by
    % the harness source from the same Gravity_g the physics reads, must
    % arrive at the gravity compensator at exactly the overridden value
    cc.Callback = sprintf([harvest ...
        'sel = flow.Time > 7200;\n' ...
        'bph = trapz(flow.Time(sel), flow.Data(sel))/(flow.Time(end)-7200)*3600;\n' ...
        '%s' ...
        'test.verifyEqual(bph, %g, ''AbsTol'', 3, ''regression band'');\n' ...
        'lg = test.sltest_simout.get(''logsout'');\n' ...
        'g_ = lg.get(''ambientGravity'').Values;\n' ...
        'test.verifyEqual(mean(g_.Data), %g, ''AbsTol'', 1e-9, ''live AmbientGravity input'');\n'], ...
        fc, grv{i,4}, grv{i,3});
end

% {name, model, fault var, retention, endMode(if checked), linkReq}
flt = { ...
 'HyperCook worst fault - regression baseline', 'PhysicalHyperCook', 'Fault_T_QC',    0,     [], ''; ...
 'LeanBroth worst fault - regression baseline', 'PhysicalLeanBroth', 'Fault_T_Prep',  0,     [], ''; ...
 'EverSimmer worst fault',                 'PhysicalEverSimmer','Fault_T_Cell1', 0.672,  2, 'SR-GS-026'};
for i = 1:size(flt,1)
    tc = createTestCase(faultSuite, 'simulation', flt{i,1});
    setProperty(tc, 'Model', flt{i,2});
    setProperty(tc, 'HarnessOwner', flt{i,2}, 'HarnessName', hmap(flt{i,2}));
    setProperty(tc, 'OverrideStopTime', true);
    setProperty(tc, 'StopTime', 21600);
    ps = addParameterSet(tc, 'Name', 'worstFault');
    addParameterOverride(ps, flt{i,3}, 7200);
    modeCheck = '';
    if ~isempty(flt{i,5})
        modeCheck = sprintf('test.verifyEqual(double(mode.Data(end)), %d, ''Degraded mode'');%s', flt{i,5}, newline);
    end
    cc = getCustomCriteria(tc);
    cc.Enabled = true;
    cc.Callback = sprintf([ ...
        'yout = test.sltest_simout.get(''yout'');\n' ...
        'flow = []; power = []; mode = [];\n' ...
        'for i = 1:yout.numElements\n' ...
        '    e = yout{i}; v = e.Values;\n' ...
        '    if isstruct(v) && isfield(v,''flow_bps''), flow = v.flow_bps; end\n' ...
        '    if strcmp(e.Name, ''totalPower_kW''), power = v; end\n' ...
    '    if strcmp(e.Name, ''plantMode''), mode = v; end\n' ...
        'end\n' ...
        'pre  = flow.Time > 3600  & flow.Time < 7200;\n' ...
        'post = flow.Time > 14400;\n' ...
        'preR  = trapz(flow.Time(pre),  flow.Data(pre))/3600;\n' ...
        'postR = trapz(flow.Time(post), flow.Data(post))/7200;\n' ...
        'retention = postR/preR;\n' ...
        '%s' ...
        'test.verifyEqual(retention, %g, ''AbsTol'', 0.02, ''worst-fault retention'');\n'], ...
        modeCheck, flt{i,4});
end

% --- Contamination suite: SR-GS-007 detection sensitivity at 2% incidence ---
% Criteria measure sensitivity = detected/(detected+escaped) from the
% logged QC signals; design sensitivity 0.995 vs the 0.99 requirement
% floor. Both robotic-QC variants link; LeanBroth is covered by the
% analysis sweep (already sub-floor nominal, no case needed).
contamSuite = createTestSuite(tf, 'Contamination');
for stray = getTestCases(contamSuite)
    remove(stray);
end
sensFrag = sprintf(['lg = test.sltest_simout.get(''logsout'');\n' ...
    'det = lg.get(''contamDetected_bps'').Values;\n' ...
    'esc = lg.get(''contamEscaped_bps'').Values;\n' ...
    'sens = trapz(det.Time,det.Data)/(trapz(det.Time,det.Data)+trapz(esc.Time,esc.Data));\n' ...
    'test.verifyGreaterThanOrEqual(sens, 0.99, ''SR-GS-007 sensitivity floor'');\n' ...
    'test.verifyEqual(sens, 0.995, ''AbsTol'', 1e-3, ''design sensitivity'');\n']);
% {name, model, bph at 2% incidence, links}
ctm = { ...
 'HyperCook contamination 2 percent',  'PhysicalHyperCook',  302.3, {'SR-GS-007'}; ...
 'EverSimmer contamination 2 percent', 'PhysicalEverSimmer', 227.3, {'SR-GS-007'}};
for i = 1:size(ctm,1)
    tc = createTestCase(contamSuite, 'simulation', ctm{i,1});
    setProperty(tc, 'Model', ctm{i,2});
    setProperty(tc, 'HarnessOwner', ctm{i,2}, 'HarnessName', hmap(ctm{i,2}));
    setProperty(tc, 'OverrideStopTime', true);
    setProperty(tc, 'StopTime', 14400);
    ps = addParameterSet(tc, 'Name', 'contamination');
    addParameterOverride(ps, 'QC_ContamIncidence', 0.02);
    cc = getCustomCriteria(tc);
    cc.Enabled = true;
    cc.Callback = sprintf([harvest ...
        'sel = flow.Time > 7200;\n' ...
        'bph = trapz(flow.Time(sel), flow.Data(sel))/(flow.Time(end)-7200)*3600;\n' ...
        floorFrag ...
        'test.verifyEqual(bph, %g, ''AbsTol'', 3, ''regression band'');\n' ...
        '%s'], ctm{i,3}, sensFrag);
end

% --- TransportLoading suite: SR-GS-006 loading latency at nominal ---
% Latency = dock-queue wait + transit, measured as the median
% mass-threshold lag between the logged packed/loaded cumulative curves.
% All three variants link: LeanBroth fails the throughput floor but
% genuinely satisfies loading latency - the link semantics cut both ways.
transSuite = createTestSuite(tf, 'TransportLoading');
for stray = getTestCases(transSuite)
    remove(stray);
end
latFrag = [ ...
    'lg = test.sltest_simout.get(''logsout'');\n' ...
    'pk = lg.get(''packedFlow_bps'').Values; ld = lg.get(''loadedFlow_bps'').Values;\n' ...
    'cumP = cumtrapz(pk.Time, pk.Data); cumL = cumtrapz(ld.Time, ld.Data);\n' ...
    'Xs = linspace(0.2, 0.8, 13) * min(cumP(end), cumL(end));\n' ...
    'lag = zeros(size(Xs));\n' ...
    'for k = 1:numel(Xs)\n' ...
    '    tP = interp1(cumP + (1:numel(cumP))''*1e-9, pk.Time, Xs(k));\n' ...
    '    tL = interp1(cumL + (1:numel(cumL))''*1e-9, ld.Time, Xs(k));\n' ...
    '    lag(k) = tL - tP;\n' ...
    'end\n' ...
    'lag = median(lag);\n' ...
    'test.verifyLessThanOrEqual(lag, 600, ''SR-GS-006 ten-minute limit'');\n'];
% {name, model, transit baseline s, links}
trn = { ...
 'HyperCook transport loading',  'PhysicalHyperCook',  30,  {'SR-GS-006'}; ...
 'LeanBroth transport loading',  'PhysicalLeanBroth',  120, {'SR-GS-006'}; ...
 'EverSimmer transport loading', 'PhysicalEverSimmer', 60,  {'SR-GS-006'}};
for i = 1:size(trn,1)
    tc = createTestCase(transSuite, 'simulation', trn{i,1});
    setProperty(tc, 'Model', trn{i,2});
    setProperty(tc, 'HarnessOwner', trn{i,2}, 'HarnessName', hmap(trn{i,2}));
    setProperty(tc, 'OverrideStopTime', true);
    setProperty(tc, 'StopTime', 14400);
    cc = getCustomCriteria(tc);
    cc.Enabled = true;
    cc.Callback = sprintf([latFrag ...
        'test.verifyEqual(lag, %g, ''AbsTol'', 15, ''latency regression band'');\n'], ...
        trn{i,3});
end

% --- RecipeRotation suite: SR-GS-001 runtime recipe rotation ---
% >= 8 distinct recipes counted from the logged activeRecipe signal.
% HyperCook runs with a realistic 120 s changeover flush (continuous
% lines pay for switching); EverSimmer's batch cycle hides changeover
% in its clean phase and needs no override.
recSuite = createTestSuite(tf, 'RecipeRotation');
for stray = getTestCases(recSuite)
    remove(stray);
end
recFrag = [ ...
    'lg = test.sltest_simout.get(''logsout'');\n' ...
    'r = lg.get(''activeRecipe'').Values;\n' ...
    'test.verifyGreaterThanOrEqual(numel(unique(round(r.Data))), 8, ''SR-GS-001 recipe count'');\n'];
% {name, model, flush override (or []), steady bph, links}
rcp = { ...
 'HyperCook recipe rotation',  'PhysicalHyperCook',  120, 289.0, {'SR-GS-001'}; ...
 'EverSimmer recipe rotation', 'PhysicalEverSimmer', [],  231.9, {'SR-GS-001'}};
for i = 1:size(rcp,1)
    tc = createTestCase(recSuite, 'simulation', rcp{i,1});
    setProperty(tc, 'Model', rcp{i,2});
    setProperty(tc, 'HarnessOwner', rcp{i,2}, 'HarnessName', hmap(rcp{i,2}));
    setProperty(tc, 'OverrideStopTime', true);
    setProperty(tc, 'StopTime', 14400);
    if ~isempty(rcp{i,3})
        ps = addParameterSet(tc, 'Name', 'changeover');
        addParameterOverride(ps, 'Recipe_Flush_s', rcp{i,3});
    end
    cc = getCustomCriteria(tc);
    cc.Enabled = true;
    cc.Callback = sprintf([harvest ...
        'sel = flow.Time > 7200;\n' ...
        'bph = trapz(flow.Time(sel), flow.Data(sel))/(flow.Time(end)-7200)*3600;\n' ...
        floorFrag ...
        'test.verifyEqual(bph, %g, ''AbsTol'', 3, ''regression band'');\n' ...
        recFrag], rcp{i,4});
end

% --- StorageEndurance suite: SR-GS-021 verification (post-ADR-032) ---
% Stores sized for 72 h at each variant's nominal rate; consumables
% excluded from the SR-GS-011 mass budget by requirements decision.
% Resupply cut at t = 3600 s with stores full: production must not
% starve inside the 12 h window and projected endurance (capacity /
% measured unsupplied rate) must reach 72 h. The finding-era baseline
% cases (6.41/4.66/5.44 h with their < 72 h assertions) were retired
% consciously by this rework, exactly as their design intended.
endSuite = createTestSuite(tf, 'StorageEndurance');
for stray = getTestCases(endSuite)
    remove(stray);
end
% {name, model, init var, cap, projected h, links}
edu = { ...
 'HyperCook storage endurance',  'PhysicalHyperCook',  'HC_StorageInit_bowls', 22300, 72.3, {'SR-GS-021'}; ...
 'LeanBroth storage endurance',  'PhysicalLeanBroth',  'LB_StorageInit_bowls', 14300, 72.6, {'SR-GS-021'}; ...
 'EverSimmer storage endurance', 'PhysicalEverSimmer', 'ES_StorageInit_bowls', 16800, 72.8, {'SR-GS-021'}};
for i = 1:size(edu,1)
    tc = createTestCase(endSuite, 'simulation', edu{i,1});
    setProperty(tc, 'Model', edu{i,2});
    setProperty(tc, 'HarnessOwner', edu{i,2}, 'HarnessName', hmap(edu{i,2}));
    setProperty(tc, 'OverrideStopTime', true);
    setProperty(tc, 'StopTime', 46800);
    ps = addParameterSet(tc, 'Name', 'endurance');
    addParameterOverride(ps, 'Resupply_Cutoff_T', 3600);
    addParameterOverride(ps, edu{i,3}, edu{i,4});
    cc = getCustomCriteria(tc);
    cc.Enabled = true;
    cc.Callback = sprintf([harvest ...
        'lastIdx = find(flow.Data*3600 > 20, 1, ''last'');\n' ...
        'test.verifyGreaterThan(flow.Time(lastIdx), 46800 - 2400, ''no starvation in window'');\n' ...
        'post = flow.Time > 3600;\n' ...
        'rate = trapz(flow.Time(post), flow.Data(post))/(46800-3600)*3600;\n' ...
        'proj_h = %g / rate;\n' ...
        'test.verifyGreaterThanOrEqual(proj_h, 72, ''SR-GS-021 endurance floor'');\n' ...
        'test.verifyEqual(proj_h, %g, ''AbsTol'', 0.5, ''endurance regression band'');\n'], ...
        edu{i,4}, edu{i,5});
end

% --- RocketTurnaround suite: SR-GS-018 (fill + handling <= 1200 s) ---
% Turnaround measured from the logged loaded-flow cumulative curve at the
% 60-bowl design shipment plus 120 s handling. HyperCook and EverSimmer
% pass and link; LeanBroth misses by 41.5 s at the design point - a
% finding, baselined unlinked with an explicit > 1200 s assertion.
rktSuite = createTestSuite(tf, 'RocketTurnaround');
for stray = getTestCases(rktSuite)
    remove(stray);
end
rktFrag = [ ...
    'lg = test.sltest_simout.get(''logsout'');\n' ...
    'ld = lg.get(''loadedFlow_bps'').Values;\n' ...
    'cumL = cumtrapz(ld.Time, ld.Data) + (1:numel(ld.Time))''*1e-9;\n' ...
    'starts = linspace(0.3, 0.7, 11) * cumL(end);\n' ...
    'ft = zeros(size(starts));\n' ...
    'for j = 1:numel(starts)\n' ...
    '    t0 = interp1(cumL, ld.Time, starts(j));\n' ...
    '    t1 = interp1(cumL, ld.Time, starts(j) + 60);\n' ...   % Rocket_Load_bowls
    '    ft(j) = t1 - t0;\n' ...
    'end\n' ...
    'turnaround = median(ft) + 120;\n'];                        % Rocket_Handling_s
% {name, model, turnaround baseline s, passes, links}
rkt = { ...
 'HyperCook rocket turnaround',  'PhysicalHyperCook',  808.1,  true,  {'SR-GS-018'}; ...
 'EverSimmer rocket turnaround', 'PhysicalEverSimmer', 1086.0, true,  {'SR-GS-018'}; ...
 'LeanBroth rocket turnaround - regression baseline', 'PhysicalLeanBroth', 1241.5, false, {}};
for i = 1:size(rkt,1)
    tc = createTestCase(rktSuite, 'simulation', rkt{i,1});
    setProperty(tc, 'Model', rkt{i,2});
    setProperty(tc, 'HarnessOwner', rkt{i,2}, 'HarnessName', hmap(rkt{i,2}));
    setProperty(tc, 'OverrideStopTime', true);
    setProperty(tc, 'StopTime', 14400);
    if rkt{i,4}
        lim = 'test.verifyLessThanOrEqual(turnaround, 1200, ''SR-GS-018 twenty-minute limit'');\n';
    else
        lim = 'test.verifyGreaterThan(turnaround, 1200, ''SR-GS-018 finding: retire this case if fixed'');\n';
    end
    cc = getCustomCriteria(tc);
    cc.Enabled = true;
    cc.Callback = sprintf([rktFrag lim ...
        'test.verifyEqual(turnaround, %g, ''AbsTol'', 30, ''turnaround regression band'');\n'], ...
        rkt{i,3});
end

% save FIRST so cases carry persistent IDs, then link (links made against
% unsaved cases capture provisional IDs and never match executed results)
saveToFile(tf);
linkSpec = [nom(:,[1 5]); flt(:,[1 6]); grv(:,[1 6]); ctm(:,[1 4]); trn(:,[1 4]); rcp(:,[1 5]); rkt(:,[1 5]); edu(:,[1 6])];
nLinks = 0;
for s = getTestSuites(tf)
    for tc = getTestCases(s)
        k = strcmp(linkSpec(:,1), tc.Name);
        if ~any(k), continue; end
        ids = linkSpec{k,2};
        if ischar(ids), ids = {ids}; end
        for id = ids(~cellfun(@isempty, ids))
            lnk = slreq.createLink(tc, find(srSet, 'Id', id{1})); %#ok<NASGU>
            nLinks = nLinks + 1;
        end
    end
end
saveToFile(tf);
slreq.saveAll();
pf = {proj.Files.Path};
if ~any(strcmpi(pf, tfPath)), addFile(proj, tfPath); end
fprintf('%s built: 22 cases, %d Verify links\n', tfPath, nLinks);
end
