function results = vowels9_refactored(subjID, howmany, feedback, atten)
% VOWELS9_REFACTORED - Vowel recognition test (Dual Window Version)
%
% Inputs:
%   subjID   - Subject identifier (required)
%   howmany  - Number of trials (default: 180)
%   feedback - 'y' or 'n' (default: 'n')
%   atten    - Attenuation dB (default: 18.0)

%% Parse Inputs
if nargin < 1, error('Subject ID required'); end
if nargin < 2, howmany = 180; end
if nargin < 3, feedback = 'n'; end
if nargin < 4, atten = 18.0; end

feedbackEnabled = strcmpi(feedback, 'y');
condition = input('Enter condition label (default "NS"): ', 's');
if isempty(condition), condition = 'NS'; end

% Sound path
soundPath = 'C:/SoundFiles/Vowels/';
if ~exist(soundPath, 'dir')
    error('Sound path not found: %s', soundPath);
end

%% Setup
[hSubj, hTest] = ExperimentCommon.setupDualUI('Vowels', subjID);
[PA5, PA5_2] = ExperimentCommon.initHardware(atten);
[fid, csvPath] = ExperimentCommon.initLogFile(subjID, 'vowels', condition);

fprintf(fid, 'Subject,Trial,Speaker,Vowel,Response,Correct,RT,Condition\n');
fprintf('Started Vowels experiment for %s (%s)\n', subjID, condition);

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

%% Main Loop
scoreCum = 0;
results = [];
results.correct = [];
results.response = [];
results.target = [];

set(hTest.txtStatus, 'String', 'Running...');
ExperimentCommon.waitForResponse(btns, 'on'); % Start enabled? No, wait for sound.
set(hSubj.txtInstruct, 'String', 'Press any button to start');
while ~resp.ready, pause(0.1); end

for trial = 1:howmany
    % Prepare Trial
    ExperimentCommon.waitForResponse(btns, 'off');
    resp.ready = false;

    stimIdx = trialOrder(trial);
    vowelID = mod(stimIdx - 1, numVowels) + 1;
    speakerID = floor((stimIdx - 1) / numVowels) + 1;

    fname = fullfile(soundPath, [speakers{speakerID} vowels{vowelID} '.wav']);
    [y, fs] = audioread(fname);
    y = y * 1.982;

    % Play
    set(hSubj.txtInstruct, 'String', 'Listen...', 'ForegroundColor', 'white');
    drawnow;
    pause(0.5);
    sound(y, fs);
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

    results.target(end+1) = vowelID;
    results.response(end+1) = resp.val;
    results.correct(end+1) = isCorrect;

    % Log
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
        plot(1:length(results.correct), cumsum(results.correct) ./ (1:length(results.correct)) * 100, 'b-o');
        ylabel('Accuracy %'); xlabel('Trial'); title('Running Accuracy');
        ylim([0 100]); grid on;

        % Plot Confusion
        axes(hTest.ax2);
        C = zeros(numVowels);
        for i = 1:length(results.target)
            t = results.target(i);
            r = results.response(i);
            C(t,r) = C(t,r) + 1;
        end
        imagesc(C); colormap('hot'); colorbar;
        set(gca, 'XTick', 1:numVowels, 'XTickLabel', vowels, 'YTick', 1:numVowels, 'YTickLabel', vowels);
        xlabel('Response'); ylabel('Target');
    end
end

%% Finish
fclose(fid);
set(hSubj.txtInstruct, 'String', 'Done! Thank you.');
pause(2);

if ~isempty(PA5), delete(PA5); delete(PA5_2); end
close(hSubj.fig);
close(hTest.fig);

end
