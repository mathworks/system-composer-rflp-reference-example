function [results, gate, trade, beh] = runFullAnalysis()
%RUNFULLANALYSIS End-to-end variant analysis chain with formal gating.
%   1. runBehavioralAnalysis - simulate the three behavioral plant models
%                              (Simulink/Stateflow/Simscape) for steady
%                              throughput, energy, and fault retention
%   2. runVariantAnalysis    - roll up metrics per variant; simulated
%                              throughput/retention override the static
%                              stage-table values (procedural flags)
%   3. runComplianceGate     - formal verification via the Requirements
%                              Table gate model; hard-errors on any
%                              disagreement with the procedural flags
%   4. runTradeStudy         - MCDA scoring over the variants that passed
%                              the formal gate
%
%   A variant that fails the formal gate is EXCLUDED from scoring (it has
%   no business being ranked against compliant designs) but remains in the
%   metrics and gate outputs so the failure is visible and documented.

beh = runBehavioralAnalysis();
results = runVariantAnalysis();
gate = runComplianceGate();

nonCompliant = gate.Properties.RowNames(~gate.AllGatesPass)';
if ~isempty(nonCompliant)
    warning('gs:gateFailed', ...
        'Formal compliance gate FAILED for: %s. Excluded from trade study scoring.', ...
        strjoin(nonCompliant, ', '));
end
compliant = gate.Properties.RowNames(gate.AllGatesPass)';
assert(~isempty(compliant), 'No compliant variants: the trade space is empty.');
if numel(compliant) == 1
    % ADR-032: the compliant set collapsed to one - selection is FORCED,
    % not scored. The degenerate trade run documents the survivor
    % (winShare 1) so downstream consumers keep working.
    fprintf(['FORCED SELECTION: %s is the only gate-compliant variant; ' ...
        'the trade study is a formality.\n'], compliant{1});
end
trade = runTradeStudy(compliant);
end
