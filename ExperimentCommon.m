classdef ExperimentCommon
    % EXPERIMENTCOMMON - Shared utilities for auditory experiments
    % Consolidates UI, Hardware, Logging, and Analysis to minimize complexity
    %
    % Key Features:
    %   - Dual-window UI (Subject/Tester) - always rendered
    %   - Multi-format output: CSV, JSON, Parquet
    %   - Comprehensive summary statistics
    %   - Statistical analysis functions
    %   - Test mode for development without hardware

    methods (Static)
        function [hSubj, hTest] = setupDualUI(expName, subjectID)
            % SETUPDUALUI - Creates Subject and Tester figures (ALWAYS dual-window)
            % Subject window is ALWAYS blind to performance data
            %
            % Returns:
            %   hSubj - Subject window handles (instructions, buttons)
            %   hTest - Tester window handles (plots, controls, stats)

            % Get Monitor Positions
            mp = get(0, 'MonitorPositions');
            % Sort by X position to ensure left-to-right ordering
            [~, idx] = sort(mp(:,1));
            mp = mp(idx, :);

            % Determine monitor layout - ALWAYS create dual windows
            if size(mp, 1) > 1
                % Dual monitor setup
                posTest = mp(1, :); % Primary (Tester control)
                posSubj = mp(2, :); % Secondary (Subject display)
                fprintf('Dual monitor detected: Tester on Monitor 1, Subject on Monitor 2\n');
            else
                % Single monitor - split vertically (Tester left, Subject right)
                scrSz = mp(1, :);
                w = scrSz(3)/2;
                h = scrSz(4)*0.9;
                posTest = [scrSz(1), scrSz(2)+20, w-10, h];
                posSubj = [scrSz(1)+w+10, scrSz(2)+20, w-10, h];
                fprintf('Single monitor detected: Rendering dual windows side-by-side\n');
            end

            % --- Tester Figure ---
            hTest.fig = figure('Name', sprintf('%s - Tester Control - %s', expName, subjectID), ...
                'NumberTitle', 'off', ...
                'Position', posTest, ...
                'MenuBar', 'none', ...
                'ToolBar', 'none', ...
                'Color', [0.94 0.94 0.94]);

            % Tester layout
            hTest.panelInfo = uipanel(hTest.fig, 'Position', [0.02 0.85 0.96 0.13], 'Title', 'Status');
            hTest.txtStatus = uicontrol(hTest.panelInfo, 'Style', 'text', 'Units', 'normalized', ...
                'Position', [0.02 0.1 0.96 0.8], 'String', 'Initializing...', 'FontSize', 12, 'HorizontalAlignment', 'left');

            hTest.panelPlot = uipanel(hTest.fig, 'Position', [0.02 0.02 0.96 0.81], 'Title', 'Results');
            hTest.ax1 = axes(hTest.panelPlot, 'Position', [0.1 0.55 0.85 0.4]); % Top plot
            hTest.ax2 = axes(hTest.panelPlot, 'Position', [0.1 0.08 0.85 0.35]); % Bottom plot

            % --- Subject Figure ---
            hSubj.fig = figure('Name', sprintf('%s - Subject Display', expName), ...
                'NumberTitle', 'off', ...
                'Position', posSubj, ...
                'MenuBar', 'none', ...
                'ToolBar', 'none', ...
                'Color', 'black'); % Black background for vision accessibility

            % Subject Layout
            hSubj.txtInstruct = uicontrol(hSubj.fig, 'Style', 'text', 'Units', 'normalized', ...
                'Position', [0.05 0.85 0.9 0.1], 'String', 'Please Wait...', ...
                'FontSize', 24, 'FontWeight', 'bold', ...
                'ForegroundColor', 'white', 'BackgroundColor', 'black');

            hSubj.panelResp = uipanel(hSubj.fig, 'Position', [0.05 0.05 0.9 0.75], ...
                'BackgroundColor', 'black', 'BorderType', 'none');

        end

        function [PA5, PA5_2] = initHardware(atten, testMode)
            % INITHARDWARE - Initialize TDT PA5 attenuators
            %
            % Inputs:
            %   atten    - Attenuation in dB
            %   testMode - (optional) true to skip hardware init, default false
            %
            % Returns:
            %   PA5, PA5_2 - Hardware objects (empty if testMode or init fails)

            if nargin < 2
                testMode = false;
            end

            if testMode
                fprintf('TEST MODE: Skipping hardware initialization\n');
                PA5 = [];
                PA5_2 = [];
                return;
            end

            try
                PA5 = actxcontrol('PA5.x', [5 5 26 26]);
                invoke(PA5, 'ConnectPA5', 'USB', 1);
                PA5.SetAtten(atten);

                PA5_2 = actxcontrol('PA5.x', [10 5 36 26]);
                invoke(PA5_2, 'ConnectPA5', 'USB', 2);
                PA5_2.SetAtten(120.0); % Mute second channel by default

                % Check errors
                err = PA5.GetError();
                if ~isempty(err)
                    warning('PA5 Error: %s', err);
                end

                fprintf('Hardware initialized: PA5 atten = %.1f dB\n', atten);
            catch ME
                warning('TDT PA5 hardware initialization failed: %s\nRunning in simulation mode.', ME.message);
                PA5 = [];
                PA5_2 = [];
            end
        end

        function [fid, csvPath] = initLogFile(subjectID, expType, condition)
            % INITLOGFILE - Setup CSV logging
            baseDir = 'C:\Experiments\Data\';
            if ~exist(baseDir, 'dir')
                mkdir(baseDir);
            end
            subjDir = fullfile(baseDir, subjectID);
            if ~exist(subjDir, 'dir')
                mkdir(subjDir);
            end

            timestamp = datestr(now, 'yyyymmdd_HHMMSS');
            csvPath = fullfile(subjDir, sprintf('%s_%s_%s_%s.csv', ...
                subjectID, expType, condition, timestamp));

            fid = fopen(csvPath, 'wt');
            if fid == -1
                error('Could not create log file: %s', csvPath);
            end
        end

        function btns = createGridButtons(parentPanel, labels, callback, nRows, nCols, colors)
            % CREATEGRIDBUTTONS - Generates response buttons
            % colors: optional cell array matching labels or single color

            btns = gobjects(length(labels), 1);

            width = 1 / nCols;
            height = 1 / nRows;
            margin = 0.01;

            for i = 1:length(labels)
                r = ceil(i / nCols);
                c = mod(i-1, nCols) + 1;

                % Calculate position (from top-left)
                % Matlab coords are from bottom-left
                yPos = 1 - (r * height);
                xPos = (c-1) * width;

                if nargin < 6 || isempty(colors)
                    bgColor = [0.2 0.2 0.2]; % Dark grey default
                elseif iscell(colors)
                    bgColor = colors{i};
                else
                    bgColor = colors;
                end

                btns(i) = uicontrol(parentPanel, 'Style', 'pushbutton', ...
                    'Units', 'normalized', ...
                    'Position', [xPos+margin, yPos+margin, width-2*margin, height-2*margin], ...
                    'String', labels{i}, ...
                    'FontSize', 14, 'FontWeight', 'bold', ...
                    'BackgroundColor', bgColor, ...
                    'ForegroundColor', 'white', ...
                    'Callback', @(src, ~) callback(i, src));
            end
        end

        function waitForResponse(btns, state)
            % Enable/Disable buttons
            set(btns, 'Enable', state);
            drawnow;
        end

        function saveJSON(filepath, data)
            % SAVEJSON - Save data structure to JSON file
            %
            % Inputs:
            %   filepath - Full path to JSON file
            %   data     - Struct or any JSON-encodable data

            try
                jsonStr = jsonencode(data, 'PrettyPrint', true);
                fid = fopen(filepath, 'w');
                if fid == -1
                    error('Cannot open file: %s', filepath);
                end
                fprintf(fid, '%s', jsonStr);
                fclose(fid);
                fprintf('Saved JSON: %s\n', filepath);
            catch ME
                warning('Failed to save JSON: %s', ME.message);
            end
        end

        function saveParquet(filepath, dataTable)
            % SAVEPARQUET - Save data table to Parquet file
            %
            % Inputs:
            %   filepath  - Full path to .parquet file
            %   dataTable - MATLAB table to save

            try
                parquetwrite(filepath, dataTable);
                fprintf('Saved Parquet: %s\n', filepath);
            catch ME
                warning('Failed to save Parquet: %s\nNote: Parquet support requires MATLAB R2019a+', ME.message);
            end
        end

        function confPath = saveConfusionMatrix(confMatrix, labels, filepath, titleStr)
            % SAVECONFUSIONMATRIX - Save confusion matrix as image and data
            %
            % Inputs:
            %   confMatrix - NxN confusion matrix
            %   labels     - Cell array of labels
            %   filepath   - Base filepath (without extension)
            %   titleStr   - Title for the plot
            %
            % Returns:
            %   confPath - Path to saved image file

            try
                % Create figure
                fig = figure('Visible', 'off', 'Position', [100 100 800 700]);

                % Plot confusion matrix
                imagesc(confMatrix);
                colormap('hot');
                colorbar;

                % Labels and formatting
                set(gca, 'XTick', 1:length(labels), 'XTickLabel', labels, ...
                         'YTick', 1:length(labels), 'YTickLabel', labels, ...
                         'FontSize', 10);
                xlabel('Response', 'FontSize', 12, 'FontWeight', 'bold');
                ylabel('Target', 'FontSize', 12, 'FontWeight', 'bold');
                title(titleStr, 'FontSize', 14, 'FontWeight', 'bold');

                % Add text annotations with counts
                for i = 1:size(confMatrix, 1)
                    for j = 1:size(confMatrix, 2)
                        if confMatrix(i,j) > 0
                            textColor = confMatrix(i,j) > max(confMatrix(:))/2;
                            if textColor
                                clr = 'black';
                            else
                                clr = 'white';
                            end
                            text(j, i, sprintf('%d', confMatrix(i,j)), ...
                                'HorizontalAlignment', 'center', ...
                                'VerticalAlignment', 'middle', ...
                                'Color', clr, 'FontSize', 9, 'FontWeight', 'bold');
                        end
                    end
                end

                % Save as PNG
                confPath = [filepath '.png'];
                saveas(fig, confPath);

                % Save as CSV
                csvPath = [filepath '.csv'];
                confTable = array2table(confMatrix, 'VariableNames', labels, 'RowNames', labels);
                writetable(confTable, csvPath, 'WriteRowNames', true);

                close(fig);
                fprintf('Saved confusion matrix: %s\n', confPath);
            catch ME
                warning('Failed to save confusion matrix: %s', ME.message);
                confPath = '';
            end
        end

        function stats = computeSummaryStats(results, expType, labels)
            % COMPUTESUMMARYSTATS - Comprehensive summary statistics
            %
            % Inputs:
            %   results - Struct with fields: correct, response, target, rt (optional)
            %   expType - 'vowels', 'consonants', or 'CRM'
            %   labels  - Cell array of stimulus labels
            %
            % Returns:
            %   stats - Struct with comprehensive statistics

            stats = struct();

            % Overall performance
            stats.overall_accuracy = mean(results.correct) * 100;
            stats.total_trials = length(results.correct);
            stats.total_correct = sum(results.correct);
            stats.total_incorrect = sum(~results.correct);

            % Reaction time stats (if available)
            if isfield(results, 'rt')
                stats.mean_rt = mean(results.rt);
                stats.median_rt = median(results.rt);
                stats.std_rt = std(results.rt);
                stats.min_rt = min(results.rt);
                stats.max_rt = max(results.rt);

                % RT by correctness
                correctRTs = results.rt(results.correct == 1);
                incorrectRTs = results.rt(results.correct == 0);
                if ~isempty(correctRTs)
                    stats.mean_rt_correct = mean(correctRTs);
                    stats.std_rt_correct = std(correctRTs);
                end
                if ~isempty(incorrectRTs)
                    stats.mean_rt_incorrect = mean(incorrectRTs);
                    stats.std_rt_incorrect = std(incorrectRTs);
                end
            end

            % Confusion matrix
            n = length(labels);
            stats.confusion_matrix = zeros(n, n);
            for i = 1:length(results.target)
                t = results.target(i);
                r = results.response(i);
                if t >= 1 && t <= n && r >= 1 && r <= n
                    stats.confusion_matrix(t, r) = stats.confusion_matrix(t, r) + 1;
                end
            end
            stats.confusion_labels = labels;

            % Per-stimulus accuracy
            stats.accuracy_by_stimulus = zeros(n, 1);
            stats.count_by_stimulus = zeros(n, 1);
            for i = 1:n
                idx = results.target == i;
                stats.count_by_stimulus(i) = sum(idx);
                if stats.count_by_stimulus(i) > 0
                    stats.accuracy_by_stimulus(i) = mean(results.correct(idx)) * 100;
                end
            end

            % Per-response counts
            stats.count_by_response = zeros(n, 1);
            for i = 1:n
                stats.count_by_response(i) = sum(results.response == i);
            end

            % Stratified by speaker (if available)
            if isfield(results, 'speaker')
                uniqueSpeakers = unique(results.speaker);
                stats.accuracy_by_speaker = struct();
                for i = 1:length(uniqueSpeakers)
                    spk = uniqueSpeakers{i};
                    idx = strcmp(results.speaker, spk);
                    stats.accuracy_by_speaker.(spk) = mean(results.correct(idx)) * 100;
                end
            end

            % Additional metrics
            stats.d_prime = ExperimentCommon.computeDPrime(stats.confusion_matrix);
            stats.bias = ExperimentCommon.computeBias(stats.confusion_matrix);

            fprintf('\n=== SUMMARY STATISTICS ===\n');
            fprintf('Overall Accuracy: %.2f%% (%d/%d)\n', stats.overall_accuracy, stats.total_correct, stats.total_trials);
            if isfield(stats, 'mean_rt')
                fprintf('Mean RT: %.3f s (SD = %.3f)\n', stats.mean_rt, stats.std_rt);
            end
            fprintf('==========================\n\n');
        end

        function dPrime = computeDPrime(confMatrix)
            % COMPUTEDPRIME - Calculate d' (d-prime) from confusion matrix
            % Simplified calculation using hits and false alarms

            hits = trace(confMatrix) / sum(confMatrix(:));
            falseAlarms = (sum(confMatrix(:)) - trace(confMatrix)) / sum(confMatrix(:));

            % Avoid infinite values
            hits = max(0.01, min(0.99, hits));
            falseAlarms = max(0.01, min(0.99, falseAlarms));

            % z-scores
            zHits = norminv(hits);
            zFA = norminv(falseAlarms);

            dPrime = zHits - zFA;
        end

        function bias = computeBias(confMatrix)
            % COMPUTEBIAS - Calculate response bias (beta)

            hits = trace(confMatrix) / sum(confMatrix(:));
            falseAlarms = (sum(confMatrix(:)) - trace(confMatrix)) / sum(confMatrix(:));

            % Avoid infinite values
            hits = max(0.01, min(0.99, hits));
            falseAlarms = max(0.01, min(0.99, falseAlarms));

            % z-scores
            zHits = norminv(hits);
            zFA = norminv(falseAlarms);

            bias = -0.5 * (zHits + zFA);
        end

        function statsReport = performStatisticalAnalysis(results, labels)
            % PERFORMSTATISTICALANALYSIS - Comprehensive statistical tests
            %
            % Inputs:
            %   results - Struct with experiment results
            %   labels  - Cell array of stimulus labels
            %
            % Returns:
            %   statsReport - Struct with statistical test results

            statsReport = struct();

            % Chi-square test for uniformity of responses
            observedResponses = histcounts(results.response, 1:(length(labels)+1));
            expectedResponses = ones(size(observedResponses)) * mean(observedResponses);
            [statsReport.chi2_pval, statsReport.chi2_stat] = ...
                ExperimentCommon.chiSquareTest(observedResponses, expectedResponses);

            % ANOVA for accuracy by stimulus (if enough data)
            if length(unique(results.target)) > 2
                [statsReport.anova_p, statsReport.anova_table] = ...
                    ExperimentCommon.oneWayANOVA(results.correct, results.target);
            end

            fprintf('\n=== STATISTICAL ANALYSIS ===\n');
            fprintf('Chi-square test (response uniformity): χ² = %.2f, p = %.4f\n', ...
                statsReport.chi2_stat, statsReport.chi2_pval);
            if isfield(statsReport, 'anova_p')
                fprintf('ANOVA (accuracy by stimulus): p = %.4f\n', statsReport.anova_p);
            end
            fprintf('============================\n\n');
        end

        function [p, chi2] = chiSquareTest(observed, expected)
            % CHISQUARETEST - Simple chi-square goodness of fit test
            chi2 = sum((observed - expected).^2 ./ expected);
            df = length(observed) - 1;
            p = 1 - chi2cdf(chi2, df);
        end

        function [p, anovaTable] = oneWayANOVA(values, groups)
            % ONEWAYANOVA - Simple one-way ANOVA
            try
                [p, anovaTable] = anova1(values, groups, 'off');
            catch
                p = NaN;
                anovaTable = [];
            end
        end

        function createVisualizationReport(results, stats, labels, outputDir, subjID, expType)
            % CREATEVISUALIZATIONREPORT - Generate comprehensive visualization report
            %
            % Creates multiple plots and saves them to output directory

            timestamp = datestr(now, 'yyyymmdd_HHMMSS');

            % 1. Accuracy over time
            fig = figure('Visible', 'off', 'Position', [100 100 1000 600]);
            runningAcc = cumsum(results.correct) ./ (1:length(results.correct))' * 100;
            plot(1:length(runningAcc), runningAcc, 'b-', 'LineWidth', 2);
            hold on;
            plot([1 length(runningAcc)], [stats.overall_accuracy stats.overall_accuracy], 'r--', 'LineWidth', 1.5);
            xlabel('Trial Number', 'FontSize', 12);
            ylabel('Accuracy (%)', 'FontSize', 12);
            title(sprintf('%s: Running Accuracy - %s', expType, subjID), 'FontSize', 14);
            legend({'Running Accuracy', 'Overall Mean'}, 'Location', 'best');
            grid on;
            ylim([0 100]);
            saveas(fig, fullfile(outputDir, sprintf('%s_%s_accuracy_%s.png', subjID, expType, timestamp)));
            close(fig);

            % 2. Accuracy by stimulus
            fig = figure('Visible', 'off', 'Position', [100 100 1000 600]);
            bar(stats.accuracy_by_stimulus);
            set(gca, 'XTickLabel', labels, 'XTick', 1:length(labels));
            xlabel('Stimulus', 'FontSize', 12);
            ylabel('Accuracy (%)', 'FontSize', 12);
            title(sprintf('%s: Accuracy by Stimulus - %s', expType, subjID), 'FontSize', 14);
            ylim([0 100]);
            grid on;
            xtickangle(45);
            saveas(fig, fullfile(outputDir, sprintf('%s_%s_by_stimulus_%s.png', subjID, expType, timestamp)));
            close(fig);

            % 3. Response distribution
            fig = figure('Visible', 'off', 'Position', [100 100 1000 600]);
            bar(stats.count_by_response);
            set(gca, 'XTickLabel', labels, 'XTick', 1:length(labels));
            xlabel('Response', 'FontSize', 12);
            ylabel('Count', 'FontSize', 12);
            title(sprintf('%s: Response Distribution - %s', expType, subjID), 'FontSize', 14);
            grid on;
            xtickangle(45);
            saveas(fig, fullfile(outputDir, sprintf('%s_%s_responses_%s.png', subjID, expType, timestamp)));
            close(fig);

            % 4. RT histogram (if available)
            if isfield(results, 'rt')
                fig = figure('Visible', 'off', 'Position', [100 100 1000 600]);
                histogram(results.rt, 20, 'FaceColor', 'b', 'EdgeColor', 'k');
                xlabel('Reaction Time (s)', 'FontSize', 12);
                ylabel('Count', 'FontSize', 12);
                title(sprintf('%s: RT Distribution - %s (Mean=%.2fs)', expType, subjID, stats.mean_rt), 'FontSize', 14);
                grid on;
                saveas(fig, fullfile(outputDir, sprintf('%s_%s_rt_dist_%s.png', subjID, expType, timestamp)));
                close(fig);
            end

            fprintf('Visualization report saved to: %s\n', outputDir);
        end

        function stats = computeCRMStats(results, nrun)
            % COMPUTECRMSTATS - CRM-specific comprehensive statistics
            %
            % Inputs:
            %   results - Struct with CRM experiment results
            %   nrun    - Number of runs
            %
            % Returns:
            %   stats - Struct with CRM-specific statistics

            stats = struct();

            % Overall performance
            stats.overall_accuracy = mean(results.correct) * 100;
            stats.total_trials = length(results.correct);
            stats.total_correct = sum(results.correct);
            stats.total_incorrect = sum(~results.correct);

            % RT statistics
            stats.mean_rt = mean(results.rt);
            stats.median_rt = median(results.rt);
            stats.std_rt = std(results.rt);
            stats.min_rt = min(results.rt);
            stats.max_rt = max(results.rt);

            % RT by correctness
            correctRTs = results.rt(results.correct == 1);
            incorrectRTs = results.rt(results.correct == 0);
            if ~isempty(correctRTs)
                stats.mean_rt_correct = mean(correctRTs);
                stats.std_rt_correct = std(correctRTs);
            end
            if ~isempty(incorrectRTs)
                stats.mean_rt_incorrect = mean(incorrectRTs);
                stats.std_rt_incorrect = std(incorrectRTs);
            end

            % SNR statistics
            stats.mean_snr = mean(results.snr);
            stats.median_snr = median(results.snr);
            stats.std_snr = std(results.snr);
            stats.min_snr = min(results.snr);
            stats.max_snr = max(results.snr);

            % Stratified by color (0-3)
            stats.accuracy_by_color = zeros(4, 1);
            stats.count_by_color = zeros(4, 1);
            for c = 0:3
                idx = results.target_color == c;
                stats.count_by_color(c+1) = sum(idx);
                if stats.count_by_color(c+1) > 0
                    stats.accuracy_by_color(c+1) = mean(results.correct(idx)) * 100;
                end
            end

            % Stratified by number (0-7)
            stats.accuracy_by_number = zeros(8, 1);
            stats.count_by_number = zeros(8, 1);
            for n = 0:7
                idx = results.target_number == n;
                stats.count_by_number(n+1) = sum(idx);
                if stats.count_by_number(n+1) > 0
                    stats.accuracy_by_number(n+1) = mean(results.correct(idx)) * 100;
                end
            end

            % Stratified by run
            stats.accuracy_by_run = zeros(nrun, 1);
            stats.mean_snr_by_run = zeros(nrun, 1);
            stats.trials_by_run = zeros(nrun, 1);
            for r = 1:nrun
                idx = results.run == r;
                stats.trials_by_run(r) = sum(idx);
                if stats.trials_by_run(r) > 0
                    stats.accuracy_by_run(r) = mean(results.correct(idx)) * 100;
                    stats.mean_snr_by_run(r) = mean(results.snr(idx));
                end
            end

            % Confusion matrices for color and number
            stats.color_confusion = zeros(4, 4);
            stats.number_confusion = zeros(8, 8);
            for i = 1:length(results.target_color)
                tc = results.target_color(i) + 1;
                rc = results.response_color(i) + 1;
                tn = results.target_number(i) + 1;
                rn = results.response_number(i) + 1;
                if tc >= 1 && tc <= 4 && rc >= 1 && rc <= 4
                    stats.color_confusion(tc, rc) = stats.color_confusion(tc, rc) + 1;
                end
                if tn >= 1 && tn <= 8 && rn >= 1 && rn <= 8
                    stats.number_confusion(tn, rn) = stats.number_confusion(tn, rn) + 1;
                end
            end

            % Reversal analysis
            stats.total_reversals = sum(results.reversal);
            stats.reversal_rate = stats.total_reversals / stats.total_trials * 100;

            fprintf('\n=== CRM SUMMARY STATISTICS ===\n');
            fprintf('Overall Accuracy: %.2f%% (%d/%d)\n', stats.overall_accuracy, stats.total_correct, stats.total_trials);
            fprintf('Mean SNR: %.2f dB (SD = %.2f)\n', stats.mean_snr, stats.std_snr);
            fprintf('Mean RT: %.3f s (SD = %.3f)\n', stats.mean_rt, stats.std_rt);
            fprintf('Total Reversals: %d (%.1f%% of trials)\n', stats.total_reversals, stats.reversal_rate);
            fprintf('===============================\n\n');
        end

        function createCRMVisualizationReport(results, stats, outputDir, subjID, condition, nrun)
            % CREATECRMVISUALIZATIONREPORT - Generate comprehensive CRM visualization report
            %
            % Creates multiple CRM-specific plots and saves them to output directory

            timestamp = datestr(now, 'yyyymmdd_HHMMSS');
            colors = {'Blue', 'Red', 'White', 'Green'};

            % 1. Accuracy over time (combined all runs)
            fig = figure('Visible', 'off', 'Position', [100 100 1200 600]);
            runningAcc = cumsum(results.correct) ./ (1:length(results.correct))' * 100;
            plot(1:length(runningAcc), runningAcc, 'b-', 'LineWidth', 2);
            hold on;
            plot([1 length(runningAcc)], [stats.overall_accuracy stats.overall_accuracy], 'r--', 'LineWidth', 1.5);
            xlabel('Trial Number (All Runs)', 'FontSize', 12);
            ylabel('Accuracy (%)', 'FontSize', 12);
            title(sprintf('CRM: Running Accuracy - %s', subjID), 'FontSize', 14);
            legend({'Running Accuracy', 'Overall Mean'}, 'Location', 'best');
            grid on;
            ylim([0 100]);
            saveas(fig, fullfile(outputDir, sprintf('%s_CRM_%s_overall_accuracy_%s.png', subjID, condition, timestamp)));
            close(fig);

            % 2. SNR over time (combined all runs with run markers)
            fig = figure('Visible', 'off', 'Position', [100 100 1200 600]);
            plot(1:length(results.snr), results.snr, 'b-', 'LineWidth', 1.5);
            hold on;

            % Mark run boundaries
            runBoundaries = [0];
            for r = 1:nrun
                runBoundaries(end+1) = runBoundaries(end) + sum(results.run == r);
            end
            for r = 2:nrun
                plot([runBoundaries(r) runBoundaries(r)], ylim, 'k--', 'LineWidth', 1);
            end

            % Mark reversals
            revIdx = find(results.reversal);
            plot(revIdx, results.snr(revIdx), 'rv', 'MarkerSize', 8, 'MarkerFaceColor', 'r');

            xlabel('Trial Number', 'FontSize', 12);
            ylabel('SNR (dB)', 'FontSize', 12);
            title(sprintf('CRM: SNR Tracking (All Runs) - %s', subjID), 'FontSize', 14);
            legend({'SNR', 'Run Boundaries', 'Reversals'}, 'Location', 'best');
            grid on;
            saveas(fig, fullfile(outputDir, sprintf('%s_CRM_%s_snr_tracking_%s.png', subjID, condition, timestamp)));
            close(fig);

            % 3. Accuracy by color
            fig = figure('Visible', 'off', 'Position', [100 100 1000 600]);
            bar(stats.accuracy_by_color);
            set(gca, 'XTickLabel', colors, 'XTick', 1:4);
            xlabel('Color', 'FontSize', 12);
            ylabel('Accuracy (%)', 'FontSize', 12);
            title(sprintf('CRM: Accuracy by Color - %s', subjID), 'FontSize', 14);
            ylim([0 100]);
            grid on;
            saveas(fig, fullfile(outputDir, sprintf('%s_CRM_%s_by_color_%s.png', subjID, condition, timestamp)));
            close(fig);

            % 4. Accuracy by number
            fig = figure('Visible', 'off', 'Position', [100 100 1000 600]);
            bar(stats.accuracy_by_number);
            set(gca, 'XTickLabel', arrayfun(@num2str, 0:7, 'UniformOutput', false), 'XTick', 1:8);
            xlabel('Number', 'FontSize', 12);
            ylabel('Accuracy (%)', 'FontSize', 12);
            title(sprintf('CRM: Accuracy by Number - %s', subjID), 'FontSize', 14);
            ylim([0 100]);
            grid on;
            saveas(fig, fullfile(outputDir, sprintf('%s_CRM_%s_by_number_%s.png', subjID, condition, timestamp)));
            close(fig);

            % 5. Accuracy by run
            fig = figure('Visible', 'off', 'Position', [100 100 1000 600]);
            bar(stats.accuracy_by_run);
            set(gca, 'XTickLabel', arrayfun(@num2str, 1:nrun, 'UniformOutput', false), 'XTick', 1:nrun);
            xlabel('Run', 'FontSize', 12);
            ylabel('Accuracy (%)', 'FontSize', 12);
            title(sprintf('CRM: Accuracy by Run - %s', subjID), 'FontSize', 14);
            ylim([0 100]);
            grid on;
            saveas(fig, fullfile(outputDir, sprintf('%s_CRM_%s_by_run_%s.png', subjID, condition, timestamp)));
            close(fig);

            % 6. Color confusion matrix
            fig = figure('Visible', 'off', 'Position', [100 100 800 700]);
            imagesc(stats.color_confusion);
            colormap('hot');
            colorbar;
            set(gca, 'XTick', 1:4, 'XTickLabel', colors, 'YTick', 1:4, 'YTickLabel', colors, 'FontSize', 10);
            xlabel('Response Color', 'FontSize', 12, 'FontWeight', 'bold');
            ylabel('Target Color', 'FontSize', 12, 'FontWeight', 'bold');
            title(sprintf('CRM: Color Confusion Matrix - %s', subjID), 'FontSize', 14, 'FontWeight', 'bold');

            % Add text annotations
            for i = 1:4
                for j = 1:4
                    if stats.color_confusion(i,j) > 0
                        textColor = stats.color_confusion(i,j) > max(stats.color_confusion(:))/2;
                        if textColor
                            clr = 'black';
                        else
                            clr = 'white';
                        end
                        text(j, i, sprintf('%d', stats.color_confusion(i,j)), ...
                            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                            'Color', clr, 'FontSize', 11, 'FontWeight', 'bold');
                    end
                end
            end

            saveas(fig, fullfile(outputDir, sprintf('%s_CRM_%s_color_confusion_%s.png', subjID, condition, timestamp)));
            close(fig);

            % 7. Number confusion matrix
            fig = figure('Visible', 'off', 'Position', [100 100 900 800]);
            imagesc(stats.number_confusion);
            colormap('hot');
            colorbar;
            numLabels = arrayfun(@num2str, 0:7, 'UniformOutput', false);
            set(gca, 'XTick', 1:8, 'XTickLabel', numLabels, 'YTick', 1:8, 'YTickLabel', numLabels, 'FontSize', 10);
            xlabel('Response Number', 'FontSize', 12, 'FontWeight', 'bold');
            ylabel('Target Number', 'FontSize', 12, 'FontWeight', 'bold');
            title(sprintf('CRM: Number Confusion Matrix - %s', subjID), 'FontSize', 14, 'FontWeight', 'bold');

            % Add text annotations
            for i = 1:8
                for j = 1:8
                    if stats.number_confusion(i,j) > 0
                        textColor = stats.number_confusion(i,j) > max(stats.number_confusion(:))/2;
                        if textColor
                            clr = 'black';
                        else
                            clr = 'white';
                        end
                        text(j, i, sprintf('%d', stats.number_confusion(i,j)), ...
                            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                            'Color', clr, 'FontSize', 9, 'FontWeight', 'bold');
                    end
                end
            end

            saveas(fig, fullfile(outputDir, sprintf('%s_CRM_%s_number_confusion_%s.png', subjID, condition, timestamp)));
            close(fig);

            % 8. RT distribution
            fig = figure('Visible', 'off', 'Position', [100 100 1000 600]);
            histogram(results.rt, 20, 'FaceColor', 'b', 'EdgeColor', 'k');
            xlabel('Reaction Time (s)', 'FontSize', 12);
            ylabel('Count', 'FontSize', 12);
            title(sprintf('CRM: RT Distribution - %s (Mean=%.2fs)', subjID, stats.mean_rt), 'FontSize', 14);
            grid on;
            saveas(fig, fullfile(outputDir, sprintf('%s_CRM_%s_rt_dist_%s.png', subjID, condition, timestamp)));
            close(fig);

            % 9. SNR distribution
            fig = figure('Visible', 'off', 'Position', [100 100 1000 600]);
            histogram(results.snr, 20, 'FaceColor', 'g', 'EdgeColor', 'k');
            xlabel('SNR (dB)', 'FontSize', 12);
            ylabel('Count', 'FontSize', 12);
            title(sprintf('CRM: SNR Distribution - %s (Mean=%.1f dB)', subjID, stats.mean_snr), 'FontSize', 14);
            grid on;
            saveas(fig, fullfile(outputDir, sprintf('%s_CRM_%s_snr_dist_%s.png', subjID, condition, timestamp)));
            close(fig);

            fprintf('CRM visualization report saved to: %s\n', outputDir);
        end
    end
end
