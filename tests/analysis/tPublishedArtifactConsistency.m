classdef (TestTags = {'analysis'}) tPublishedArtifactConsistency < sltest.TestCase
    % Reader-facing trade claims must agree with the canonical result CSVs.

    methods (Test)
        function markdownMatchesCanonicalResults(testCase)
            root = char(currentProject().RootFolder);
            facts = tPublishedArtifactConsistency.loadFacts(root);

            readme = fileread(fullfile(root, 'README.md'));
            rollup = fileread(fullfile(root, 'docs', 'explainers', ...
                '01_static_rollup.md'));
            gateDoc = fileread(fullfile(root, 'docs', 'explainers', ...
                '04_compliance_gate.md'));
            scoring = fileread(fullfile(root, 'docs', 'explainers', ...
                '05_trade_scoring.md'));
            results = fileread(fullfile(root, 'docs', ...
                '06_trade_study_results.md'));
            formalGate = fileread(fullfile(root, 'docs', ...
                '08_formal_compliance_gate.md'));

            testCase.verifySubstring(readme, facts.hyperCook);
            testCase.verifySubstring(rollup, facts.hyperCook);
            testCase.verifySubstring(gateDoc, facts.gateCount);
            testCase.verifySubstring(scoring, facts.winShare);
            testCase.verifySubstring(results, facts.gateCount);
            testCase.verifySubstring(results, facts.winShare);
            testCase.verifySubstring(formalGate, facts.gateCount);
            testCase.verifySubstring(readme, 'No variant is committed as baseline');
        end

        function tradeDeckMatchesCanonicalResults(testCase)
            root = char(currentProject().RootFolder);
            facts = tPublishedArtifactConsistency.loadFacts(root);
            deck = fullfile(root, 'docs', 'deliverables', ...
                'GalacticSoupTradeDeck.pptx');
            testCase.assertTrue(isfile(deck), 'Published trade deck is missing');

            extractDir = tempname;
            mkdir(extractDir);
            cleanup = onCleanup(@() rmdir(extractDir, 's'));
            unzip(deck, extractDir);
            slides = dir(fullfile(extractDir, 'ppt', 'slides', 'slide*.xml'));
            slideText = cell(numel(slides), 1);
            for k = 1:numel(slides)
                xml = fileread(fullfile(slides(k).folder, slides(k).name));
                slideText{k} = regexprep(xml, '<[^>]+>', ' ');
            end
            deckText = strjoin(slideText, ' ');

            testCase.verifySubstring(deckText, facts.hyperCook);
            testCase.verifySubstring(deckText, facts.gateCountLong);
            testCase.verifySubstring(deckText, facts.winShare);
            testCase.verifySubstring(deckText, facts.scenarioWins);
            testCase.verifySubstring(deckText, 'No baseline is committed');
        end
    end

    methods (Static, Access = private)
        function facts = loadFacts(root)
            resultDir = fullfile(root, 'analysis', 'results');
            metrics = readtable(fullfile(resultDir, 'variantMetrics.csv'), ...
                'ReadRowNames', true);
            gate = readtable(fullfile(resultDir, 'complianceGate.csv'), ...
                'ReadRowNames', true);
            trade = readtable(fullfile(resultDir, 'tradeScores.csv'), ...
                'ReadRowNames', true);
            mc = readtable(fullfile(resultDir, 'mcWinShare.csv'), ...
                'ReadRowNames', true);

            gateCells = logical(gate{:,1:end-1});
            nPass = nnz(gateCells);
            nTotal = numel(gateCells);
            [~,winnerIndex] = max(trade{:,:}, [], 1);
            winners = trade.Properties.RowNames(winnerIndex);
            nEverSimmerWins = nnz(strcmp(winners, 'EverSimmer'));

            facts.hyperCook = sprintf( ...
                'HyperCook: %.1f kW, %.1f kCr, %.1f m^3', ...
                metrics{'HyperCook','Power_kW'}, ...
                metrics{'HyperCook','Cost_kCredits'}, ...
                metrics{'HyperCook','Volume_m3'});
            facts.gateCount = sprintf('%d/%d checks pass', nPass, nTotal);
            facts.gateCountLong = sprintf('%d of %d', nPass, nTotal);
            facts.winShare = sprintf('%.1f%%', ...
                100 * mc{'EverSimmer','WinShare'});
            facts.scenarioWins = sprintf('%d of %d named scenarios', ...
                nEverSimmerWins, width(trade));
        end
    end
end
