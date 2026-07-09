function value = gsParseBudgetValue(srSet, reqId)
%GSPARSEBUDGETVALUE Extract the first numeric limit from a requirement's text.
%   Reads the Description of the requirement with the given Id and returns
%   the first number found, so analysis caps stay in sync with requirements.

req = srSet.find('Id', reqId);
desc = req.Description;
tok = regexp(desc, '([\d]+(?:\.\d+)?)', 'tokens', 'once');
if isempty(tok)
    error('gs:noBudget', 'No numeric value found in %s: %s', reqId, desc);
end
value = str2double(tok{1});
end
