function [rundata, runrev, results] = CRM_refactored(subjID, talker, maskers, nrun, feedback, atten, testMode)
% CRM_REFACTORED - Coordinate Response Measure (Enhanced Dual Window Version)
%
% Inputs:
%   subjID    - Subject identifier
%   talker    - Target talker ID (0-7)
%   maskers   - Two masker IDs [M1 M2]
%   nrun      - Number of runs (default: 2)
%   feedback  - 'y' or 'n' (default: 'n')
%   atten     - Attenuation dB (default: 15.0)
%   testMode  - true/false, skip hardware (default: false)
%
% Outputs:
%   rundata  - Cell array of SNR history per run
%   runrev   - Cell array of reversal SNRs per run
%   results  - Comprehensive results structure with statistics
%
% Output Files:
%   - CSV: Trial-by-trial data with SNR tracking
%   - JSON: Summary statistics and adaptive track metadata
%   - Parquet: Trial data in Apache Parquet format
%   - PNG: SNR tracking plots and visualizations

%% Parse Inputs
if nargin < 3, error('Subject ID, Talker, and Maskers required'); end
if nargin < 4, nrun = 2; end
if nargin < 5, feedback = 'n'; end
if nargin < 6, atten = 15.0; end
if nargin < 7, testMode = false; end

feedbackEnabled = strcmpi(feedback, 'y');

% Validate talker/maskers
if talker < 0 || talker > 7, error('Talker must be 0-7'); end
if length(maskers) ~= 2, error('Maskers must be 2 IDs'); end
if any(maskers == talker), error('Masker cannot be target'); end

% Sound paths
baseDir = 'C:\SoundFiles\CRMCorpus\original';
if ~exist(baseDir, 'dir')
    if testMode
        warning('Sound corpus not found, using test mode');
    else
        error('Sound corpus not found: %s', baseDir);
    end
end

if ~testMode
    pathT = fullfile(baseDir, sprintf('Talker%d', talker));
    pathM1 = fullfile(baseDir, sprintf('Talker%d', maskers(1)));
    pathM2 = fullfile(baseDir, sprintf('Talker%d', maskers(2)));
else
    pathT = ''; pathM1 = ''; pathM2 = '';
end

%% Setup
condition = sprintf('T%d_M%d-%d', talker, maskers(1), maskers(2));
[hSubj, hTest] = ExperimentCommon.setupDualUI('CRM', subjID);
[PA5, PA5_2] = ExperimentCommon.initHardware(atten, testMode);
[fid, csvPath] = ExperimentCommon.initLogFile(subjID, 'CRM', condition);

% Get output directory
[outputDir, ~, ~] = fileparts(csvPath);
timestamp = datestr(now, 'yyyymmdd_HHMMSS');

% CSV Header
fprintf(fid, 'Run,Trial,TargetCol,TargetNum,RespCol,RespNum,Correct,SNR,Reversal,RT\n');
fprintf('Started CRM experiment for %s (Talker %d, Maskers %d-%d)\n', subjID, talker, maskers(1), maskers(2));
if testMode
    fprintf('*** TEST MODE: Hardware disabled, using simulated playback ***\n');
end

%% Setup Response Buttons (4 Colors x 8 Numbers)
colors = {'Blue', 'Red', 'White', 'Green'};
colorVals = {[0 0 1], [1 0 0], [0.9 0.9 0.9], [0 0.7 0]}; % RGB
resp = [];
resp.col = -1;
resp.num = -1;
resp.ready = false;

    function btnClick(colIdx, numIdx)
        resp.col = colIdx - 1; % 0-3
        resp.num = numIdx - 1; % 0-7
        resp.ready = true;
    end

% Create 4x8 grid manually
btns = gobjects(32, 1);
idx = 1;
for r = 1:4 % Colors
    for c = 1:8 % Numbers
        x = (c-1) * (1/8);
        y = 1 - (r * (1/4));
        w = 1/8 - 0.01;
        h = 1/4 - 0.01;

        btns(idx) = uicontrol(hSubj.panelResp, 'Style', 'pushbutton', ...
            'Units', 'normalized', ...
            'Position', [x+0.005, y+0.005, w, h], ...
            'String', sprintf('%s\n%d', colors{r}, c-1), ...
            'BackgroundColor', colorVals{r}, ...
            'FontSize', 10, 'FontWeight', 'bold', ...
            'Callback', @(~,~) btnClick(r, c));
        idx = idx + 1;
    end
end

%% Initialize results structure
results = struct();
results.run = [];
results.trial = [];
results.target_color = [];
results.target_number = [];
results.response_color = [];
results.response_number = [];
results.correct = [];
results.snr = [];
results.reversal = [];
results.rt = [];

%% Run Loop
rundata = cell(nrun, 1);
runrev = cell(nrun, 1);

ExperimentCommon.waitForResponse(btns, 'on');
set(hSubj.txtInstruct, 'String', 'Press any button to start');
while ~resp.ready, pause(0.1); end

for run = 1:nrun
    fprintf('Starting Run %d...\n', run);
    set(hTest.txtStatus, 'String', sprintf('Run %d / %d', run, nrun));

    % Adaptive Parameters
    tlevel = -15;
    mlevel = tlevel - 20; % Start at +20 dB SNR
    step = 4;
    nrev = 0;
    prevdir = 1;

    snrHistory = [];
    revHistory = [];

    % Trials (Reversal criterion)
    trial = 0;
    while nrev < 14 && trial < 100
        trial = trial + 1;
        ExperimentCommon.waitForResponse(btns, 'off');
        resp.ready = false;

        % Stimuli
        c = randperm(4)-1; n = randperm(8)-1;
        tgtC = c(1); tgtN = n(1);

        % Load audio (or simulate in test mode)
        if testMode
            % Simulate audio
            fs = 44100;
            duration = 2.0 + rand * 0.5; % 2.0-2.5 sec
            y = zeros(round(fs * duration), 1);
        else
            fnT = fullfile(pathT, sprintf('000%d0%d.wav', tgtC, tgtN));
            fnM1 = fullfile(pathM1, sprintf('020%d0%d.wav', c(2), n(2)));
            fnM2 = fullfile(pathM2, sprintf('030%d0%d.wav', c(3), n(3)));

            [ta, fs] = audioread(fnT);
            [m1, ~] = audioread(fnM1);
            [m2, ~] = audioread(fnM2);

            % Levels
            ta = ta .* 10^(tlevel/20);
            m1 = m1 .* 10^(mlevel/20);
            m2 = m2 .* 10^(mlevel/20);

            % Pad and Mix
            mx = max([length(ta), length(m1), length(m2)]);
            ta(end+1:mx) = 0; m1(end+1:mx) = 0; m2(end+1:mx) = 0;

            y = ta + m1 + m2;
            if max(abs(y)) > 1, y = y / max(abs(y)) * 0.99; warning('Clipped'); end
        end

        % Play
        set(hSubj.txtInstruct, 'String', 'Listen...', 'ForegroundColor', 'white');
        drawnow;
        pause(0.5);

        if ~testMode
            sound(y, fs);
        end
        pause(length(y)/fs + 0.2);

        % Response
        set(hSubj.txtInstruct, 'String', 'Select Color and Number');
        ExperimentCommon.waitForResponse(btns, 'on');

        tStart = tic;
        while ~resp.ready && ishandle(hSubj.fig), pause(0.05); end
        rt = toc(tStart);
        if ~ishandle(hSubj.fig), break; end

        % Logic
        isCorrect = (resp.col == tgtC && resp.num == tgtN);
        curSNR = tlevel - mlevel;
        isRev = 0;

        if isCorrect
            if prevdir == -1 && trial > 1
                nrev = nrev + 1;
                isRev = 1;
                if nrev >= 4, step = 2; end
            end
            prevdir = 1;
            mlevel = mlevel + step;
        else
            if prevdir == 1 && trial > 1
                nrev = nrev + 1;
                isRev = 1;
                if nrev >= 4, step = 2; end
            end
            prevdir = -1;
            mlevel = mlevel - step;
        end

        % Store & Log
        snrHistory(end+1) = curSNR;
        if isRev, revHistory(end+1) = curSNR; end

        % Store in results structure
        results.run(end+1) = run;
        results.trial(end+1) = trial;
        results.target_color(end+1) = tgtC;
        results.target_number(end+1) = tgtN;
        results.response_color(end+1) = resp.col;
        results.response_number(end+1) = resp.num;
        results.correct(end+1) = isCorrect;
        results.snr(end+1) = curSNR;
        results.reversal(end+1) = isRev;
        results.rt(end+1) = rt;

        fprintf(fid, '%d,%d,%d,%d,%d,%d,%d,%.2f,%d,%.3f\n', ...
            run, trial, tgtC, tgtN, resp.col, resp.num, isCorrect, curSNR, isRev, rt);

        % Feedback
        if feedbackEnabled
            if isCorrect
                set(hSubj.txtInstruct, 'String', 'CORRECT', 'ForegroundColor', 'green');
            else
                set(hSubj.txtInstruct, 'String', 'INCORRECT', 'ForegroundColor', 'red');
            end
            pause(1);
        else
            pause(0.5);
        end

        % Update Plot (Every trial)
        axes(hTest.ax1);
        cla;
        plot(1:length(snrHistory), snrHistory, 'b-o', 'LineWidth', 1.5);
        hold on;
        if ~isempty(revHistory)
            revIdx = find([0 diff(snrHistory) ~= 0]);  % Approximation
            plot(revIdx(revIdx <= length(snrHistory)), snrHistory(revIdx(revIdx <= length(snrHistory))), ...
                'rv', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
        end
        ylabel('SNR (dB)'); xlabel('Trial'); title(sprintf('Run %d SNR Track', run));
        grid on;
        legend({'SNR', 'Reversals'}, 'Location', 'best');

        % Update accuracy plot
        axes(hTest.ax2);
        cla;
        runCorrect = results.correct(results.run == run);
        runningAcc = cumsum(runCorrect) ./ (1:length(runCorrect))' * 100;
        plot(1:length(runningAcc), runningAcc, 'g-o', 'LineWidth', 1.5);
        ylabel('Accuracy %'); xlabel('Trial'); title(sprintf('Run %d Accuracy', run));
        ylim([0 100]); grid on;

        drawnow;
    end

    rundata{run} = snrHistory;
    runrev{run} = revHistory;

    if run < nrun
        set(hSubj.txtInstruct, 'String', 'Run Complete. Press button for next run.');
        ExperimentCommon.waitForResponse(btns, 'on');
        while ~resp.ready, pause(0.1); end
    end
end

%% Finalize and Compute Statistics
fclose(fid);
fprintf('\n=== EXPERIMENT COMPLETE ===\n');

% Compute statistics
overallAcc = mean(results.correct) * 100;
meanSNR = mean(results.snr);
stdSNR = std(results.snr);
meanRT = mean(results.rt);
stdRT = std(results.rt);

% Compute threshold (mean of last 6 reversals across all runs)
allReversals = [];
for r = 1:nrun
    if length(runrev{r}) >= 6
        allReversals = [allReversals runrev{r}(end-5:end)];
    end
end
if ~isempty(allReversals)
    threshold = mean(allReversals);
    thresholdSD = std(allReversals);
else
    threshold = NaN;
    thresholdSD = NaN;
end

fprintf('\n=== SUMMARY STATISTICS ===\n');
fprintf('Overall Accuracy: %.2f%%\n', overallAcc);
fprintf('Mean SNR: %.2f dB (SD = %.2f)\n', meanSNR, stdSNR);
fprintf('Threshold (last 6 rev): %.2f dB (SD = %.2f)\n', threshold, thresholdSD);
fprintf('Mean RT: %.3f s (SD = %.3f)\n', meanRT, stdRT);
fprintf('==========================\n\n');

%% Create Comprehensive Visualizations
% SNR tracking plot for all runs
fig = figure('Visible', 'off', 'Position', [100 100 1200 800]);
for r = 1:nrun
    subplot(ceil(nrun/2), 2, r);
    plot(1:length(rundata{r}), rundata{r}, 'b-o', 'LineWidth', 1.5);
    hold on;
    if ~isempty(runrev{r})
        % Find reversal indices
        revIdx = [];
        for i = 1:length(runrev{r})
            idx = find(rundata{r} == runrev{r}(i), 1);
            if ~isempty(idx), revIdx(end+1) = idx; end
        end
        plot(revIdx, rundata{r}(revIdx), 'rv', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
    end
    xlabel('Trial'); ylabel('SNR (dB)');
    title(sprintf('Run %d: SNR Track', r));
    grid on;
    legend({'SNR', 'Reversals'}, 'Location', 'best');
end
snrPlotPath = fullfile(outputDir, sprintf('%s_CRM_%s_snr_tracking_%s.png', subjID, condition, timestamp));
saveas(fig, snrPlotPath);
close(fig);

% RT distribution
fig = figure('Visible', 'off', 'Position', [100 100 1000 600]);
histogram(results.rt, 20, 'FaceColor', 'b', 'EdgeColor', 'k');
xlabel('Reaction Time (s)', 'FontSize', 12);
ylabel('Count', 'FontSize', 12);
title(sprintf('CRM RT Distribution - %s (Mean=%.2fs)', subjID, meanRT), 'FontSize', 14);
grid on;
rtPlotPath = fullfile(outputDir, sprintf('%s_CRM_%s_rt_dist_%s.png', subjID, condition, timestamp));
saveas(fig, rtPlotPath);
close(fig);

%% Save JSON Summary
jsonPath = strrep(csvPath, '.csv', '_summary.json');
summaryData = struct();
summaryData.subject_id = subjID;
summaryData.experiment = 'CRM';
summaryData.condition = condition;
summaryData.timestamp = timestamp;
summaryData.talker = talker;
summaryData.maskers = maskers;
summaryData.num_runs = nrun;
summaryData.test_mode = testMode;
summaryData.attenuation_db = atten;
summaryData.feedback_enabled = feedbackEnabled;

summaryData.overall_accuracy = overallAcc;
summaryData.mean_snr = meanSNR;
summaryData.std_snr = stdSNR;
summaryData.threshold_db = threshold;
summaryData.threshold_std = thresholdSD;
summaryData.mean_rt = meanRT;
summaryData.std_rt = stdRT;

summaryData.run_data = rundata;
summaryData.run_reversals = runrev;

ExperimentCommon.saveJSON(jsonPath, summaryData);

%% Save Parquet format
try
    % Create table from results
    dataTable = table( ...
        results.run', ...
        results.trial', ...
        results.target_color', ...
        results.target_number', ...
        results.response_color', ...
        results.response_number', ...
        results.correct', ...
        results.snr', ...
        results.reversal', ...
        results.rt', ...
        'VariableNames', {'Run', 'Trial', 'TargetColor', 'TargetNumber', ...
                          'ResponseColor', 'ResponseNumber', 'Correct', 'SNR', 'Reversal', 'RT'});

    parquetPath = strrep(csvPath, '.csv', '.parquet');
    ExperimentCommon.saveParquet(parquetPath, dataTable);
catch ME
    warning('Could not save Parquet file: %s', ME.message);
end

%% Display final summary to tester
set(hTest.txtStatus, 'String', sprintf('COMPLETE: %.1f%% acc, Threshold: %.1f dB', overallAcc, threshold));

%% Final message to subject
set(hSubj.txtInstruct, 'String', 'Experiment Complete. Thank you!', 'ForegroundColor', 'white');
pause(2);

%% Cleanup
if ~isempty(PA5)
    try
        delete(PA5);
        delete(PA5_2);
    catch
        % Ignore cleanup errors
    end
end

if ishandle(hSubj.fig), close(hSubj.fig); end
if ishandle(hTest.fig), close(hTest.fig); end

% Add summary to results
results.summary = summaryData;

fprintf('\n=== OUTPUT FILES ===\n');
fprintf('CSV:     %s\n', csvPath);
fprintf('JSON:    %s\n', jsonPath);
fprintf('Parquet: %s\n', strrep(csvPath, '.csv', '.parquet'));
fprintf('SNR Plot: %s\n', snrPlotPath);
fprintf('RT Plot:  %s\n', rtPlotPath);
fprintf('====================\n\n');

end
