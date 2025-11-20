function [rundata, runrev] = CRM_refactored(subjID, talker, maskers, feedback, baseatten, nrun)
% CRM_REFACTORED - Coordinate Response Measure test with adaptive SNR tracking
%
% Syntax:
%   [rundata, runrev] = CRM_refactored(subjID, talker, maskers)
%   [rundata, runrev] = CRM_refactored(subjID, talker, maskers, feedback, baseatten, nrun)
%
% Inputs:
%   subjID    - Subject identifier (required)
%   talker    - Target talker ID (0-7): 0-3=male, 4-7=female
%   maskers   - Vector of 2 masker talker IDs (different from target)
%   feedback  - Feedback enabled: 'y' or 'n' (default: 'n')
%   baseatten - Base attenuation in dB (default: 15)
%   nrun      - Number of runs (default: 2)
%
% Outputs:
%   rundata   - Cell array with trial-by-trial data for each run
%   runrev    - Cell array with reversal SNR values for each run
%
% Examples:
%   CRM_refactored('S001', 0, [1 3])              % Male target, 2 male maskers
%   CRM_refactored('S001', 0, [1 3], 'y', 15, 2)  % With feedback, 2 runs
%
% Features:
%   - Real-time adaptive SNR tracking plot with reversal markers
%   - Standardized CSV + JSON output
%   - Modern UI with color/number response grid
%   - Automatic SRT calculation
%
% Original: CRM.m
% Refactored: 2025-01-20

%% Parse and validate inputs
if nargin < 3
    error('Subject ID, talker, and maskers are required');
end
if nargin < 4, feedback = 'n'; end
if nargin < 5, baseatten = 15; end
if nargin < 6, nrun = 2; end

feedbackEnabled = strcmpi(feedback, 'y');

% Validate talker IDs
if talker < 0 || talker > 7
    error('Talker ID must be 0-7');
end
if length(maskers) ~= 2
    error('Must specify exactly 2 masker talkers');
end
if any(maskers == talker)
    error('Masker talkers must be different from target talker');
end
if any(maskers < 0 | maskers > 7)
    error('Masker IDs must be 0-7');
end

%% Initialize configuration
config = ExperimentConfig('crm', subjID);
config.numTrials = nrun;  % Number of runs
config.feedbackEnabled = feedbackEnabled;
config.attenuation = baseatten;
config.condition = sprintf('T%d_M%d-%d', talker, maskers(1), maskers(2));
config.setupPaths();

fprintf('\n=== CRM Adaptive SNR Test ===\n');
fprintf('Subject: %s\n', subjID);
fprintf('Target Talker: %d\n', talker);
fprintf('Masker Talkers: %d, %d\n', maskers(1), maskers(2));
fprintf('Base Atten: %.1f dB\n', baseatten);
fprintf('Runs: %d\n', nrun);
fprintf('Feedback: %s\n', feedback);
fprintf('==============================\n\n');

%% Setup paths for CRM corpus
soundbasedir = 'C:\SoundFiles\CRMCorpus';
targetdir = fullfile(soundbasedir, 'original', sprintf('Talker%d', talker));
maskerdir1 = fullfile(soundbasedir, 'original', sprintf('Talker%d', maskers(1)));
maskerdir2 = fullfile(soundbasedir, 'original', sprintf('Talker%d', maskers(2)));

% Validate directories
if ~exist(targetdir, 'dir')
    error('Target talker directory not found: %s', targetdir);
end
if ~exist(maskerdir1, 'dir') || ~exist(maskerdir2, 'dir')
    error('Masker talker directory not found');
end

%% Initialize data logger
logger = DataLogger(config);
logger.initialize();

%% Initialize UI
ui = ExperimentUI(config);
ui.initialize();
ui.updateInstruction('Press START to begin', 'white');

%% Initialize hardware
try
    PA5 = actxcontrol('PA5.x', [5 5 26 26]);
    invoke(PA5, 'ConnectPA5', 'USB', 1);
    PA5.SetAtten(baseatten);
    errorMsg = PA5.GetError();
    if ~isempty(errorMsg)
        PA5.Display(errorMsg, 0);
        error('PA5 error: %s', errorMsg);
    end
    fprintf('Hardware initialized successfully\n');
catch ME
    warning('Hardware initialization failed: %s', ME.message);
    PA5 = [];
end

%% Initialize random number generator
rng('shuffle');

%% Wait for start
pause(0.5);
response = ui.getResponse();
ui.updateInstruction('Starting run 1...', 'white');
pause(1);

%% Run adaptive procedure for each run
rundata = cell(nrun, 1);
runrev = cell(nrun, 1);

for runNum = 1:nrun

    ui.updateInstruction(sprintf('Run %d of %d', runNum, nrun), 'white');
    pause(1);

    % Adaptive tracking parameters
    tlevel = -15;      % Target level (dB)
    mlevel = tlevel - 20;  % Initial masker level (start at +20 dB SNR)
    step = 4;          % Initial step size
    nrev = 0;          % Number of reversals
    prevdir = 1;       % Previous direction (1=up, -1=down)
    trial = 0;
    maxTrials = 100;   % Safety limit
    targetReversals = 14;

    trialDataRun = [];
    snrTrack = [];
    reversalData = [];

    % Continue until we get enough reversals
    while nrev < targetReversals && trial < maxTrials

        % Reduce step size after initial reversals
        if nrev >= 4
            step = 2;
        end

        trial = trial + 1;

        % Generate random stimuli
        % CRM format: "Ready [callsign] go to [color] [number] now"
        % callsign: 0, color: 0-3 (B,R,W,G), number: 0-7
        nums = randperm(8) - 1;
        cols = randperm(4) - 1;

        targetCol = cols(1);
        targetNum = nums(1);

        % Construct filenames (format: 0CC0N.wav where CC=color, N=number)
        targetFile = fullfile(targetdir, sprintf('000%d0%d.wav', targetCol, targetNum));
        masker1File = fullfile(maskerdir1, sprintf('020%d0%d.wav', cols(2), nums(2)));
        masker2File = fullfile(maskerdir2, sprintf('030%d0%d.wav', cols(3), nums(3)));

        % Load audio files
        [ta, fs] = audioread(targetFile);
        [m1, ~] = audioread(masker1File);
        [m2, ~] = audioread(masker2File);

        % Apply level adjustments
        ta = ta .* 10.^(tlevel/20);
        m1 = m1 .* 10.^(mlevel/20);
        m2 = m2 .* 10.^(mlevel/20);

        % Zero-pad to same length
        maxlen = max([length(ta), length(m1), length(m2)]);
        ta = [ta; zeros(maxlen - length(ta), 1)];
        m1 = [m1; zeros(maxlen - length(m1), 1)];
        m2 = [m2; zeros(maxlen - length(m2), 1)];

        % Mix target and maskers
        x = ta + m1 + m2;

        % Safety check for clipping
        if max(abs(x)) > 1
            warning('Audio clipping detected! SNR: %.1f dB', tlevel - mlevel);
            x = x / max(abs(x)) * 0.99;
        end

        % Play stimulus
        ui.updateInstruction('Listen...', 'white');
        pause(0.5);
        sound(x, fs);
        pause(length(x)/fs + 0.3);

        % Collect response
        ui.updateInstruction('Select the color and number you heard', 'white');
        tstart = tic;
        responseData = ui.getResponse();
        rt = toc(tstart);

        % Parse response
        if isstruct(responseData)
            responseCol = responseData.color;
            responseNum = responseData.number;
        else
            % Fallback if response format is unexpected
            responseCol = -1;
            responseNum = -1;
        end

        % Score response
        colCorrect = (responseCol == targetCol);
        numCorrect = (responseNum == targetNum);
        bothCorrect = colCorrect && numCorrect;

        % Provide feedback if enabled
        if feedbackEnabled
            if bothCorrect
                ui.updateInstruction('CORRECT!', [0 1 0]);
            else
                ui.updateInstruction('Incorrect', [1 0 0]);
            end
            pause(1);
        end

        % Update adaptive track
        currentSNR = tlevel - mlevel;

        if bothCorrect
            % Correct: make it harder (increase masker = decrease SNR)
            if prevdir == -1 && trial > 1
                nrev = nrev + 1;
                reversalData(end+1, :) = [trial, currentSNR];
            end
            prevdir = 1;
            mlevel = mlevel + step;
        else
            % Incorrect: make it easier (decrease masker = increase SNR)
            if prevdir == 1 && trial > 1
                nrev = nrev + 1;
                reversalData(end+1, :) = [trial, currentSNR];
            end
            prevdir = -1;
            mlevel = mlevel - step;
        end

        % Store trial data
        trialData = struct(...
            'run', runNum, ...
            'trial', trial, ...
            'target_color', targetCol, ...
            'target_number', targetNum, ...
            'response_color', responseCol, ...
            'response_number', responseNum, ...
            'color_correct', colCorrect, ...
            'number_correct', numCorrect, ...
            'snr_db', currentSNR, ...
            'rt_sec', rt);

        trialDataRun = [trialDataRun; trialData];
        snrTrack(end+1) = currentSNR;

        % Log to file
        logger.logTrial(trialData);

        % Update plot
        ui.updateCRMTrack(snrTrack, reversalData);
        ui.updateProgress(runNum, nrun, nrev / targetReversals);

        % Check if UI was closed
        if ~ui.isOpen()
            fprintf('Experiment terminated by user\n');
            break;
        end
    end

    % Store run data
    rundata{runNum} = trialDataRun;
    runrev{runNum} = reversalData(:, 2);  % SNR values at reversals

    % Calculate and display SRT for this run
    if length(runrev{runNum}) >= 10
        srt = mean(runrev{runNum}(5:end));  % Average of last reversals (after first 4)
        srtStd = std(runrev{runNum}(5:end));
        fprintf('Run %d: SRT = %.2f dB, SD = %.2f dB\n', runNum, srt, srtStd);
    else
        fprintf('Run %d: Not enough reversals for SRT calculation\n', runNum);
    end

    % Brief pause between runs
    if runNum < nrun
        ui.updateInstruction(sprintf('Run %d complete. Press button for Run %d', runNum, runNum+1), 'white');
        response = ui.getResponse();
    end
end

%% Finalize and save results
ui.updateInstruction('All runs complete! Processing results...', 'white');

% Calculate overall SRT
allReversals = [];
for i = 1:nrun
    if length(runrev{i}) >= 10
        allReversals = [allReversals; runrev{i}(5:end)];
    end
end

if ~isempty(allReversals)
    overallSRT = mean(allReversals);
    overallSD = std(allReversals);
else
    overallSRT = NaN;
    overallSD = NaN;
end

% Create summary
summary = struct();
summary.overall_srt_db = overallSRT;
summary.overall_std_db = overallSD;
summary.num_runs = nrun;
summary.talker = talker;
summary.maskers = maskers;

for i = 1:nrun
    if length(runrev{i}) >= 10
        summary.(sprintf('run%d_srt', i)) = mean(runrev{i}(5:end));
        summary.(sprintf('run%d_std', i)) = std(runrev{i}(5:end));
    end
end

% Finalize logging
logger.finalize(summary);

% Update display
ui.updateInstruction(sprintf('Complete! Overall SRT: %.2f dB', overallSRT), [0 1 0]);

fprintf('\n=== Experiment Complete ===\n');
fprintf('Overall SRT: %.2f +/- %.2f dB\n', overallSRT, overallSD);
fprintf('Individual runs:\n');
for i = 1:nrun
    if length(runrev{i}) >= 10
        fprintf('  Run %d: %.2f +/- %.2f dB\n', i, ...
            mean(runrev{i}(5:end)), std(runrev{i}(5:end)));
    end
end
fprintf('===========================\n\n');

% Keep UI open for review
fprintf('Close the figure window to finish.\n');
waitfor(ui.figure);

% Cleanup
if ~isempty(PA5)
    try
        delete(PA5);
    catch
    end
end

end
