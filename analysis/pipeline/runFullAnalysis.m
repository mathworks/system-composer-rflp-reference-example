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
%   The published comparison figures always show all three variants so the
%   design space remains visible in the docs. If the formal gate narrows
%   the candidate set, the compliant-only decision artifacts are written to
%   a tagged output location instead of overwriting the comparison set.

beh = runBehavioralAnalysis();
results = runVariantAnalysis();
gate = runComplianceGate();
comparison = runTradeStudy();

nonCompliant = gate.Properties.RowNames(~gate.AllGatesPass)';
if ~isempty(nonCompliant)
    warning('gs:gateFailed', ...
        'Formal compliance gate FAILED for: %s. Excluded from trade study scoring.', ...
        strjoin(nonCompliant, ', '));
end
compliant = gate.Properties.RowNames(gate.AllGatesPass)';
assert(~isempty(compliant), 'No compliant variants: the trade space is empty.');
if isscalar(compliant)
    % ADR-032: the compliant set collapsed to one - selection is FORCED,
    % not scored. The degenerate trade run documents the survivor
    % (winShare 1) so downstream consumers keep working.
    fprintf(['FORCED SELECTION: %s is the only gate-compliant variant; ' ...
        'the trade study is a formality.\n'], compliant{1});
end
allVariants = gate.Properties.RowNames';
if isequal(compliant, allVariants)
    trade = comparison;
else
    trade = runTradeStudy(compliant, 'ResultTag', 'compliant');
end
end
