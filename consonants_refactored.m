function results = consonants_refactored(subjID, howmany, feedback, atten)
% CONSONANTS_REFACTORED - Modern 16-consonant recognition test with real-time visualization
%
% Syntax:
%   results = consonants_refactored(subjID)
%   results = consonants_refactored(subjID, howmany, feedback, atten)
%
% Inputs:
%   subjID   - Subject identifier (required)
%   howmany  - Number of trials (default: 64)
%   feedback - Feedback enabled: 'y' or 'n' (default: 'n')
%   atten    - Attenuation level in dB (default: 22.0)
%
% Outputs:
%   results  - Structure with experiment results and summary statistics
%
% Examples:
%   consonants_refactored('S001')                    % 64 trials, no feedback
%   consonants_refactored('S001', 64, 'y', 22.0)    % With feedback
%
% Features:
%   - Modern UI with real-time accuracy plot and confusion matrix
%   - Standardized CSV + JSON output for easy analysis
%   - Configurable paths and settings
%   - Better error handling and validation
%
% Original: consonants.m (last updated 11/23/2021)
% Refactored: 2025-01-20

%% Parse and validate inputs
if nargin < 1
    error('Subject ID is required');
end
if nargin < 2, howmany = 64; end
if nargin < 3, feedback = 'n'; end
if nargin < 4, atten = 22.0; end

feedbackEnabled = strcmpi(feedback, 'y');

%% Get condition label
condition = input(['How do you want to label this condition?\n' ...
    '(e.g. ear for HI or bCI (L,R,B) or device for bimodal CIHA (CI,HA,BM): '], 's');
if isempty(condition)
    condition = 'NS';
end

%% Initialize configuration
config = ExperimentConfig('consonants', subjID);
config.numTrials = howmany;
config.feedbackEnabled = feedbackEnabled;
config.attenuation = atten;
config.condition = condition;
config.setupPaths();
config.validateSoundPath();

fprintf('\n=== Consonant Recognition Experiment ===\n');
fprintf('Subject: %s\n', subjID);
fprintf('Condition: %s\n', condition);
fprintf('Trials: %d\n', howmany);
fprintf('Feedback: %s\n', feedback);
fprintf('Attenuation: %.1f dB\n', atten);
fprintf('========================================\n\n');

%% Initialize data logger
logger = DataLogger(config);
logger.initialize();

%% Initialize UI
ui = ExperimentUI(config);
ui.initialize();
ui.updateInstruction('Press any button to start', 'white');

%% Define stimuli
speakers = {'ah-a', 'ct-a', 'lf-a', 'sy-a'};
consonants = {'b', 'd', 'f', 'g', 'k', 'm', 'n', 'p', 's', 't', 'v', 'z', '#', '%', '$', '?'};
consonantLabels = {'B', 'D', 'F', 'G', 'K', 'M', 'N', 'P', 'S', 'T', 'V', 'Z', '#', '%', '$', '?'};

numConsonants = length(consonants);
numSpeakers = length(speakers);

%% Initialize hardware (PA5 attenuators)
try
    [PA5, PA5_2] = initializeHardware(atten);
    fprintf('Hardware initialized successfully\n');
catch ME
    warning('Hardware initialization failed: %s', ME.message);
    fprintf('Continuing in test mode without hardware\n');
    PA5 = [];
    PA5_2 = [];
end

%% Load noise generation parameters (for compatibility, though usually not used)
numBands = 0;  % 0 means no noise/masking (testing in quiet)
SNR = 60;      % Very high SNR = essentially no masking

% Load band division data if available
try
    load('banDivision.mat', 'ch12_710');
    filtCoeff = ch12_710;
catch
    fprintf('banDivision.mat not found - proceeding without noise masking\n');
    filtCoeff = [];
end

% Generate or load noise components (kept for compatibility)
if ~isempty(filtCoeff) && numBands > 0
    % Would generate noise here if needed
    noiseCompo = [];
    noiseEnv = [];
else
    noiseCompo = zeros(30000, 12);  % Placeholder
    noiseEnv = ones(30000, 12) * 1e-5;
end

%% Load energy information for SNR matching
soundPath = config.soundPath;
try
    load(fullfile(soundPath, 'miscInfo.mat'), 'energyTarget');
catch
    fprintf('Warning: miscInfo.mat not found - creating placeholder\n');
    energyTarget = cell(numSpeakers, numConsonants);
    for i = 1:numSpeakers
        for j = 1:numConsonants
            energyTarget{i, j} = 1;  % Placeholder
        end
    end
end

%% Randomize trial order
rng('shuffle');
totalStimuli = numConsonants * numSpeakers;  % 16 consonants * 4 speakers = 64
trialOrder = mod(randperm(ceil(howmany)), totalStimuli) + 1;

%% Wait for start
pause(0.5);
response = ui.getResponse();  % Wait for button press
ui.updateInstruction('Starting experiment...', 'white');
pause(1);

%% Main experiment loop
scoreCum = 0;
for trial = 1:howmany

    % Determine which consonant and speaker
    stimIdx = trialOrder(trial);
    consonantID = mod(stimIdx - 1, numConsonants) + 1;
    speakerID = floor((stimIdx - 1) / numConsonants) + 1;

    consonantLabel = consonants{consonantID};
    speakerLabel = speakers{speakerID};

    % Load audio
    soundFile = fullfile(soundPath, [speakerLabel consonantLabel 'a.wav']);

    if ~exist(soundFile, 'file')
        warning('Sound file not found: %s', soundFile);
        continue;
    end

    [target, fs] = audioread(soundFile);

    % Add noise if needed (usually SNR=60 means essentially no noise)
    if SNR < 60 && ~isempty(noiseCompo)
        len = length(target);
        noiseID = randi(size(noiseCompo, 1) - len - 100) + 1;
        noiseSegment = noiseCompo(noiseID:noiseID+len-1, :);

        % SNR matching would go here
        % For now, just use target without noise
        audioData = target;
    else
        audioData = target;
    end

    % Scale audio
    audioData = audioData * 1.982;

    % Update UI - Playing
    ui.updateProgress(trial, howmany, scoreCum / max(1, trial-1));
    ui.updateInstruction('Listen...', 'white');
    pause(0.5);

    % Play sound
    sound(audioData, fs);
    pause(length(audioData) / fs + 0.3);

    % Collect response
    ui.updateInstruction('Which consonant did you hear?', 'white');
    tstart = tic;
    responseID = ui.getResponse();
    rt = toc(tstart);

    % Score response
    correct = (responseID == consonantID);
    scoreCum = scoreCum + correct;

    % Provide feedback if enabled
    if feedbackEnabled
        if correct
            ui.updateInstruction('CORRECT!', [0 1 0]);  % Green
        else
            ui.updateInstruction(sprintf('Correct answer: %s', consonantLabels{consonantID}), [1 0.5 0]);
        end
        pause(1.5);
    else
        pause(0.5);
    end

    % Log trial data
    trialData = struct(...
        'trial', trial, ...
        'speaker_id', speakerID, ...
        'consonant_id', consonantID, ...
        'response_id', responseID, ...
        'correct', correct, ...
        'rt_sec', rt);
    logger.logTrial(trialData);

    % Update plots every 4 trials (for efficiency)
    if mod(trial, 4) == 0 || trial == howmany
        currentAccuracy = scoreCum / trial;
        ui.updateAccuracyPlot(trial, currentAccuracy);

        confMatrix = logger.computeConfusionMatrix(numConsonants);
        ui.updateConfusionMatrix(confMatrix, consonantLabels);
    end

    % Check if UI was closed
    if ~ui.isOpen()
        fprintf('Experiment terminated by user\n');
        break;
    end
end

%% Finalize and save results
ui.updateInstruction('Run finished. Processing results...', 'white');

% Calculate summary statistics
percentCorrect = (scoreCum / howmany) * 100;
confusionMatrix = logger.computeConfusionMatrix(numConsonants);

% Create summary structure
summary = struct();
summary.percent_correct = percentCorrect;
summary.total_correct = scoreCum;
summary.confusion_matrix = confusionMatrix;
summary.consonant_labels = {consonantLabels};

% Finalize data logging
logger.finalize(summary);

% Update final display
ui.updateInstruction(sprintf('Experiment Complete! Score: %.1f%%', percentCorrect), [0 1 0]);
fprintf('\n=== Experiment Complete ===\n');
fprintf('Score: %.2f%%\n', percentCorrect);
fprintf('See plots for detailed results\n');
fprintf('===========================\n\n');

% Return results
results = struct();
results.config = config;
results.summary = summary;
results.percentCorrect = percentCorrect;

% Keep UI open for review
fprintf('Close the figure window to finish.\n');
waitfor(ui.figure);

% Cleanup hardware
cleanupHardware(PA5, PA5_2);

end

%% Helper Functions

function [PA5, PA5_2] = initializeHardware(atten)
    % Initialize TDT PA5 attenuators

    PA5 = actxcontrol('PA5.x', [5 5 26 26]);
    invoke(PA5, 'ConnectPA5', 'USB', 1);

    PA5_2 = actxcontrol('PA5.x', [10 5 36 26]);
    invoke(PA5_2, 'ConnectPA5', 'USB', 2);

    % Set attenuation levels
    PA5.SetAtten(atten);
    errorMsg = PA5.GetError();
    if ~isempty(errorMsg)
        PA5.Display(errorMsg, 0);
        error('PA5 error: %s', errorMsg);
    end

    PA5_2.SetAtten(90.0);  % Second channel muted
    errorMsg = PA5_2.GetError();
    if ~isempty(errorMsg)
        PA5_2.Display(errorMsg, 0);
    end
end

function cleanupHardware(PA5, PA5_2)
    % Clean up hardware connections
    try
        if ~isempty(PA5)
            delete(PA5);
        end
        if ~isempty(PA5_2)
            delete(PA5_2);
        end
    catch
        % Ignore cleanup errors
    end
end
