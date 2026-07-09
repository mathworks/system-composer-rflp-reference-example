function gsNewBehComponent(name, args)
%GSNEWBEHCOMPONENT Create a behavioral component model shell.
%   gsNewBehComponent(name, args) creates behavior/components/<name>.slx,
%   links it to BehParamsCommon.sldd (which chains to BehaviorInterfaces),
%   defines the fields of struct ARGS as model-workspace variables, and
%   declares them all as model arguments (instance parameters) so variant
%   plant models can override them per model-reference instance.
%
%   Destructive: an existing model of the same name is recreated.

proj = currentProject;
compDir = char(fullfile(proj.RootFolder, 'behavior', 'components'));
if bdIsLoaded(name), close_system(name, 0); end
f = fullfile(compDir, [name '.slx']);
if isfile(f), delete(f); end

new_system(name);
set_param(name, 'DataDictionary', 'BehParamsCommon.sldd');  % filename only

argNames = fieldnames(args);
if ~isempty(argNames)
    mws = get_param(name, 'ModelWorkspace');
    for i = 1:numel(argNames)
        assignin(mws, argNames{i}, args.(argNames{i}));
    end
    set_param(name, 'ParameterArgumentNames', strjoin(argNames', ','));
end

save_system(name, f);
projFiles = {proj.Files.Path};
if ~any(strcmpi(projFiles, f)), addFile(proj, f); end
fprintf('%s: shell created with %d model arguments\n', name, numel(argNames));
end
