function value = gsParseBudgetValue(srSet, reqId)
%GSPARSEBUDGETVALUE Extract the first numeric limit from a requirement's text.
%   Reads the Description of the requirement with the given Id and returns
%   the first number found, so analysis caps stay in sync with requirements.
%
%   Rich text is stripped first. A Requirements Toolbox description that
%   has been through the rich-text editor comes back as a full HTML
%   document beginning
%
%       <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0//EN" ...
%
%   and the first number in that string is the 4 of "HTML 4.0", not the
%   requirement's cap. That is not a hypothetical: SR-GS-002 and
%   SR-GS-011 were rich-texted in an editor round-trip, which silently
%   set the throughput floor and the mass budget to 3 - every variant
%   failed the mass gate and every variant passed the throughput gate.
%   Nothing errored, because 3 is a perfectly good number.
%
%   So: strip tags, drop the doctype and any style/script blocks, decode
%   the handful of entities that carry digits, and only then look for a
%   number. Text descriptions are unaffected - stripping is a no-op on
%   them.

req = srSet.find('Id', reqId);
assert(isscalar(req), 'gs:noRequirement', 'No unique requirement %s', reqId);
desc = plainText(req.Description);
tok = regexp(desc, '([\d]+(?:\.\d+)?)', 'tokens', 'once');
if isempty(tok)
    error('gs:noBudget', 'No numeric value found in %s: %s', reqId, desc);
end
value = str2double(tok{1});
end

function s = plainText(s)
% Reduce a possibly-HTML description to its visible text.
s = char(s);
if ~contains(s, '<')
    return                      % plain text already; leave it exactly as is
end
% Keep only the body. The head carries a stylesheet whose CSS is full of
% numbers (`hr { height: 1px }`), and a <meta content="1"> - strip the tags
% around those and the digits are still there, masquerading as the cap.
b = regexp(s, '<body[^>]*>(.*)</body>', 'tokens', 'once', 'ignorecase');
if ~isempty(b)
    s = b{1};
end
s = regexprep(s, '<!DOCTYPE[^>]*>', ' ', 'ignorecase');
s = regexprep(s, '<style[^>]*>.*?</style>', ' ', 'ignorecase');
s = regexprep(s, '<script[^>]*>.*?</script>', ' ', 'ignorecase');
s = regexprep(s, '<!--.*?-->', ' ');
s = regexprep(s, '<[^>]*>', ' ');                   % remaining tags
s = regexprep(s, '&nbsp;', ' ');
s = regexprep(s, '&amp;', '&');
s = regexprep(s, '&lt;', '<');
s = regexprep(s, '&gt;', '>');
s = regexprep(s, '&#(\d+);', '${char(str2double($1))}');   % numeric entities
s = strtrim(regexprep(s, '\s+', ' '));
end
