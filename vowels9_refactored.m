function results = vowels9_refactored(subjID, howmany, feedback, atten, testMode)
% VOWELS9_REFACTORED - Vowel recognition test (Enhanced Dual Window Version)
%
% Inputs:
%   subjID   - Subject identifier (required)
%   howmany  - Number of trials (default: 180)
%   feedback - 'y' or 'n' (default: 'n')
%   atten    - Attenuation dB (default: 18.0)
%   testMode - true/false, skip hardware (default: false)
%
% Outputs:
%   results  - Comprehensive results structure with statistics
%
% Output Files:
%   - CSV: Trial-by-trial data
%   - JSON: Summary statistics and metadata
%   - Parquet: Trial data in Apache Parquet format
%   - PNG: Confusion matrix and visualizations

%% Parse Inputs
if nargin < 1, error('Subject ID required'); end
if nargin < 2, howmany = 180; end
if nargin < 3, feedback = 'n'; end
if nargin < 4, atten = 18.0; end
if nargin < 5, testMode = false; end

feedbackEnabled = strcmpi(feedback, 'y');
condition = input('Enter condition label (default "NS"): ', 's');
if isempty(condition), condition = 'NS'; end

% Sound path
soundPath = 'C:/SoundFiles/Vowels/';
if ~exist(soundPath, 'dir')
    if testMode
        warning('Sound path not found, using test mode');
    else
        error('Sound path not found: %s', soundPath);
    end
end

%% Setup
[hSubj, hTest] = ExperimentCommon.setupDualUI('Vowels', subjID);
[PA5, PA5_2] = ExperimentCommon.initHardware(atten, testMode);
[fid, csvPath] = ExperimentCommon.initLogFile(subjID, 'vowels', condition);

% Get output directory
[outputDir, ~, ~] = fileparts(csvPath);
timestamp = datestr(now, 'yyyymmdd_HHMMSS');

% CSV Header
fprintf(fid, 'Subject,Trial,Speaker,Vowel,Response,Correct,RT,Condition\n');
fprintf('Started Vowels experiment for %s (%s)\n', subjID, condition);
if testMode
    fprintf('*** TEST MODE: Hardware disabled, using simulated playback ***\n');
end

%% Stimuli
speakers = {'M01','M03','M06','M08','M11','M24','M30','M33','M39','M41', ...
            'W01','W04','W09','W14','W15','W23','W25','W26','W44','W47'};
vowels = {'AE', 'AH', 'AW', 'EH', 'IH', 'IY', 'OO', 'UH', 'UW'};
numVowels = length(vowels);

%% Setup Response Buttons
resp = [];
resp.val = 0;
resp.ready = false;

    function btnClick(idx, ~)
        resp.val = idx;
        resp.ready = true;
    end

btns = ExperimentCommon.createGridButtons(hSubj.panelResp, vowels, @btnClick, 3, 3);

%% Trial Generation
rng('shuffle');
totalStim = numVowels * length(speakers);
trialOrder = mod(randperm(ceil(howmany)), totalStim) + 1;

%% Main Loop - Collect detailed data
scoreCum = 0;
results = struct();
results.correct = [];
results.response = [];
results.target = [];
results.rt = [];
results.speaker = {};
results.vowel = {};
results.trial = [];

set(hTest.txtStatus, 'String', 'Press button to start...');
set(hSubj.txtInstruct, 'String', 'Press any button to start');
ExperimentCommon.waitForResponse(btns, 'on');
while ~resp.ready, pause(0.1); end

for trial = 1:howmany
    % Prepare Trial
    ExperimentCommon.waitForResponse(btns, 'off');
    resp.ready = false;

    stimIdx = trialOrder(trial);
    vowelID = mod(stimIdx - 1, numVowels) + 1;
    speakerID = floor((stimIdx - 1) / numVowels) + 1;

    % Load audio (or skip in test mode)
    if testMode
        % Simulate audio playback
        fs = 44100;
        duration = 0.5 + rand * 0.5; % 0.5-1.0 sec
        y = zeros(round(fs * duration), 1);
    else
        fname = fullfile(soundPath, [speakers{speakerID} vowels{vowelID} '.wav']);
        [y, fs] = audioread(fname);
        y = y * 1.982;
    end

    % Play
    set(hSubj.txtInstruct, 'String', 'Listen...', 'ForegroundColor', 'white');
    drawnow;
    pause(0.5);

    if ~testMode
        sound(y, fs);
    end
    pause(length(y)/fs + 0.2);

    % Get Response
    set(hSubj.txtInstruct, 'String', 'Select Vowel');
    ExperimentCommon.waitForResponse(btns, 'on');

    tStart = tic;
    while ~resp.ready && ishandle(hSubj.fig)
        pause(0.05);
    end
    rt = toc(tStart);

    if ~ishandle(hSubj.fig), break; end

    % Score
    isCorrect = (resp.val == vowelID);
    scoreCum = scoreCum + isCorrect;

    % Store detailed results
    results.trial(end+1) = trial;
    results.target(end+1) = vowelID;
    results.response(end+1) = resp.val;
    results.correct(end+1) = isCorrect;
    results.rt(end+1) = rt;
    results.speaker{end+1} = speakers{speakerID};
    results.vowel{end+1} = vowels{vowelID};

    % Log to CSV
    fprintf(fid, '%s,%d,%s,%s,%s,%d,%.3f,%s\n', ...
        subjID, trial, speakers{speakerID}, vowels{vowelID}, ...
        vowels{resp.val}, isCorrect, rt, condition);

    % Feedback
    if feedbackEnabled
        if isCorrect
            set(hSubj.txtInstruct, 'String', 'CORRECT', 'ForegroundColor', 'green');
        else
            set(hSubj.txtInstruct, 'String', ['Incorrect: ' vowels{vowelID}], 'ForegroundColor', 'red');
        end
        pause(1.0);
    else
        pause(0.5);
    end

    % Update Tester UI (Every 5 trials)
    if mod(trial, 5) == 0 || trial == howmany
        pct = (scoreCum / trial) * 100;
        set(hTest.txtStatus, 'String', sprintf('Trial %d/%d - Acc: %.1f%%', trial, howmany, pct));

        % Plot Accuracy
        axes(hTest.ax1);
        cla;
        runningAcc = cumsum(results.correct) ./ (1:length(results.correct))' * 100;
        plot(1:length(runningAcc), runningAcc, 'b-o', 'LineWidth', 1.5);
        ylabel('Accuracy %'); xlabel('Trial'); title('Running Accuracy');
        ylim([0 100]); grid on;

        % Plot Confusion
        axes(hTest.ax2);
        cla;
        C = zeros(numVowels);
        for i = 1:length(results.target)
            t = results.target(i);
            r = results.response(i);
            C(t,r) = C(t,r) + 1;
        end
        imagesc(C); colormap('hot'); colorbar;
        set(gca, 'XTick', 1:numVowels, 'XTickLabel', vowels, ...
                 'YTick', 1:numVowels, 'YTickLabel', vowels);
        xlabel('Response'); ylabel('Target'); title('Confusion Matrix');
        drawnow;
    end
end

%% Finalize and Compute Statistics
fclose(fid);
fprintf('\n=== EXPERIMENT COMPLETE ===\n');

% Compute comprehensive summary statistics
stats = ExperimentCommon.computeSummaryStats(results, 'vowels', vowels);

% Perform statistical analysis
statsReport = ExperimentCommon.performStatisticalAnalysis(results, vowels);

% Save confusion matrix with timestamp
confMatrixPath = fullfile(outputDir, sprintf('%s_vowels_%s_confmatrix_%s', subjID, condition, timestamp));
ExperimentCommon.saveConfusionMatrix(stats.confusion_matrix, vowels, confMatrixPath, ...
    sprintf('Vowels Confusion Matrix - %s (%s)', subjID, condition));

% Create comprehensive visualization report
ExperimentCommon.createVisualizationReport(results, stats, vowels, outputDir, subjID, 'vowels');

%% Save JSON Summary
jsonPath = strrep(csvPath, '.csv', '_summary.json');
summaryData = struct();
summaryData.subject_id = subjID;
summaryData.experiment = 'vowels';
summaryData.condition = condition;
summaryData.timestamp = timestamp;
summaryData.num_trials = howmany;
summaryData.test_mode = testMode;
summaryData.attenuation_db = atten;
summaryData.feedback_enabled = feedbackEnabled;
summaryData.statistics = stats;
summaryData.statistical_tests = statsReport;
summaryData.stimulus_labels = vowels;
summaryData.speakers = speakers;

ExperimentCommon.saveJSON(jsonPath, summaryData);

%% Save Parquet format
try
    % Create table from results
    dataTable = table( ...
        results.trial', ...
        results.target', ...
        results.response', ...
        results.correct', ...
        results.rt', ...
        results.speaker', ...
        results.vowel', ...
        'VariableNames', {'Trial', 'Target', 'Response', 'Correct', 'RT', 'Speaker', 'Vowel'});

    parquetPath = strrep(csvPath, '.csv', '.parquet');
    ExperimentCommon.saveParquet(parquetPath, dataTable);
catch ME
    warning('Could not save Parquet file: %s', ME.message);
end

%% Display final summary to tester
set(hTest.txtStatus, 'String', sprintf('COMPLETE: %.1f%% accuracy, Mean RT: %.2fs', ...
    stats.overall_accuracy, stats.mean_rt));

%% Final message to subject
set(hSubj.txtInstruct, 'String', 'Done! Thank you.', 'ForegroundColor', 'white');
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

% Return results with stats
results.summary_statistics = stats;
results.statistical_analysis = statsReport;

fprintf('\n=== OUTPUT FILES ===\n');
fprintf('CSV:     %s\n', csvPath);
fprintf('JSON:    %s\n', jsonPath);
fprintf('Parquet: %s\n', strrep(csvPath, '.csv', '.parquet'));
fprintf('Confusion Matrix: %s.png\n', confMatrixPath);
fprintf('====================\n\n');

end
