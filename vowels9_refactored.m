function results = vowels9_refactored(subjID, howmany, feedback, atten)
% VOWELS9_REFACTORED - Modern 9-vowel recognition test with real-time visualization
%
% Syntax:
%   results = vowels9_refactored(subjID)
%   results = vowels9_refactored(subjID, howmany, feedback, atten)
%
% Inputs:
%   subjID   - Subject identifier (required)
%   howmany  - Number of trials (default: 180)
%   feedback - Feedback enabled: 'y' or 'n' (default: 'n')
%   atten    - Attenuation level in dB (default: 18.0)
%
% Outputs:
%   results  - Structure with experiment results and summary statistics
%
% Examples:
%   vowels9_refactored('S001')                    % 180 trials, no feedback
%   vowels9_refactored('S001', 10, 'n', 18.0)    % 10 trials for testing
%   vowels9_refactored('S001', 180, 'y', 20.0)   % With feedback, 20dB atten
%
% Features:
%   - Modern UI with real-time accuracy plot and confusion matrix
%   - Standardized CSV + JSON output for easy analysis
%   - Configurable paths and settings
%   - Better error handling and validation
%
% Original: vowels9.m (last updated 6/10/2021)
% Refactored: 2025-01-20

%% Parse and validate inputs
if nargin < 1
    error('Subject ID is required');
end
if nargin < 2, howmany = 180; end
if nargin < 3, feedback = 'n'; end
if nargin < 4, atten = 18.0; end

feedbackEnabled = strcmpi(feedback, 'y');

%% Get condition label
condition = input(['How do you want to label this condition?\n' ...
    '(e.g. ear for HI or bCI (L,R,B) or device for bimodal CIHA (CI,HA,BM): '], 's');
if isempty(condition)
    condition = 'NS';
end

%% Initialize configuration
config = ExperimentConfig('vowels', subjID);
config.numTrials = howmany;
config.feedbackEnabled = feedbackEnabled;
config.attenuation = atten;
config.condition = condition;
config.setupPaths();
config.validateSoundPath();

fprintf('\n=== Vowel Recognition Experiment ===\n');
fprintf('Subject: %s\n', subjID);
fprintf('Condition: %s\n', condition);
fprintf('Trials: %d\n', howmany);
fprintf('Feedback: %s\n', feedback);
fprintf('Attenuation: %.1f dB\n', atten);
fprintf('=====================================\n\n');

%% Initialize data logger
logger = DataLogger(config);
logger.initialize();

%% Initialize UI
ui = ExperimentUI(config);
ui.initialize();
ui.updateInstruction('Press any button to start', 'white');

%% Define stimuli
speakers = {'M01','M03','M06','M08','M11','M24','M30','M33','M39','M41', ...
            'W01','W04','W09','W14','W15','W23','W25','W26','W44','W47'};

vowels = {'AE', 'AH', 'AW', 'EH', 'IH', 'IY', 'OO', 'UH', 'UW'};
numVowels = length(vowels);
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

%% Randomize trial order
rng('shuffle');  % Modern MATLAB random seed
totalStimuli = numVowels * numSpeakers;  % 9 vowels * 20 speakers = 180
trialOrder = mod(randperm(ceil(howmany)), totalStimuli) + 1;

%% Wait for start
pause(0.5);
response = ui.getResponse();  % Wait for button press
ui.updateInstruction('Starting experiment...', 'white');
pause(1);

%% Main experiment loop
scoreCum = 0;
for trial = 1:howmany

    % Determine which vowel and speaker
    stimIdx = trialOrder(trial);
    vowelID = mod(stimIdx - 1, numVowels) + 1;
    speakerID = floor((stimIdx - 1) / numVowels) + 1;

    vowelLabel = vowels{vowelID};
    speakerLabel = speakers{speakerID};

    % Load and prepare audio
    soundFile = fullfile(config.soundPath, [speakerLabel vowelLabel '.wav']);

    if ~exist(soundFile, 'file')
        warning('Sound file not found: %s', soundFile);
        continue;
    end

    [audioData, fs] = audioread(soundFile);
    audioData = audioData * 1.982;  % Original scaling factor

    % Update UI - Playing
    ui.updateProgress(trial, howmany, scoreCum / max(1, trial-1));
    ui.updateInstruction('Playing...', 'white');
    pause(0.7);

    % Play sound
    sound(audioData, fs);
    pause(length(audioData) / fs + 0.3);

    % Collect response
    ui.updateInstruction('Which vowel did you hear?', 'white');
    tstart = tic;
    responseID = ui.getResponse();
    rt = toc(tstart);

    % Score response
    correct = (responseID == vowelID);
    scoreCum = scoreCum + correct;

    % Provide feedback if enabled
    if feedbackEnabled
        if correct
            ui.updateInstruction('CORRECT!', [0 1 0]);  % Green
        else
            ui.updateInstruction(sprintf('Correct answer: %s', vowelLabel), [1 0.5 0]);  % Orange
        end
        pause(1.5);
    else
        pause(0.5);
    end

    % Log trial data
    trialData = struct(...
        'trial', trial, ...
        'speaker_id', speakerID, ...
        'vowel_id', vowelID, ...
        'response_id', responseID, ...
        'correct', correct, ...
        'rt_sec', rt);
    logger.logTrial(trialData);

    % Update plots every 5 trials (for efficiency)
    if mod(trial, 5) == 0 || trial == howmany
        currentAccuracy = scoreCum / trial;
        ui.updateAccuracyPlot(trial, currentAccuracy);

        confMatrix = logger.computeConfusionMatrix(numVowels);
        ui.updateConfusionMatrix(confMatrix, vowels);
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
confusionMatrix = logger.computeConfusionMatrix(numVowels);

% Create summary structure
summary = struct();
summary.percent_correct = percentCorrect;
summary.total_correct = scoreCum;
summary.confusion_matrix = confusionMatrix;
summary.vowel_labels = {vowels};

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
