function makeRequirementsReport()
%MAKEREQUIREMENTSREPORT Generate the requirements coverage report.
%   Produces docs/deliverables/GalacticSoupRequirementsReport.pdf from the two
%   requirement sets via the Requirements Toolbox report generator, with
%   implementation status (Implement links from the architectures),
%   verification status (Verify links from the Simulink Test simulation
%   cases, colored by the latest results), and the link listings per
%   requirement. Run after runAllTests so verification results are fresh.

proj = currentProject;
reqDir = char(fullfile(proj.RootFolder, 'requirements'));
outFile = char(fullfile(proj.RootFolder, 'docs', 'deliverables', 'GalacticSoupRequirementsReport.pdf'));

slreq.clear();
sn = slreq.load(fullfile(reqDir, 'StakeholderNeeds.slreqx'));
sr = slreq.load(fullfile(reqDir, 'SystemRequirements.slreqx'));
updateImplementationStatus(sr);
updateVerificationStatus(sr);

opts = slreq.getReportOptions();
opts.reportPath = outFile;
opts.includes.ImplementationStatus = true;
opts.includes.VerificationStatus = true;
opts.includes.Links = true;
opts.includes.EmptySections = false;

if isfile(outFile), delete(outFile); end
slreq.generateReport([sn sr], opts);
assert(isfile(outFile), 'report was not generated');

pf = {proj.Files.Path};
if ~any(strcmpi(pf, outFile)), addFile(proj, outFile); end
fprintf('requirements report: %s\n', outFile);
end
