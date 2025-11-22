function results = consonants_refactored(subjID, howmany, feedback, atten)
% CONSONANTS_REFACTORED - Consonant recognition test (Dual Window Version)
%
% Inputs:
%   subjID   - Subject identifier (required)
%   howmany  - Number of trials (default: 64)
%   feedback - 'y' or 'n' (default: 'n')
%   atten    - Attenuation dB (default: 22.0)

%% Parse Inputs
if nargin < 1, error('Subject ID required'); end
if nargin < 2, howmany = 64; end
if nargin < 3, feedback = 'n'; end
if nargin < 4, atten = 22.0; end

feedbackEnabled = strcmpi(feedback, 'y');
condition = input('Enter condition label (default "NS"): ', 's');
if isempty(condition), condition = 'NS'; end

% Sound path
soundPath = 'C:/SoundFiles/Multi/Full/';
% For compatibility with old script path handling
if ~exist(soundPath, 'dir')
    soundPath = 'C:/SoundFiles/Multi/'; % Fallback
end
if ~exist(soundPath, 'dir')
    error('Sound path not found: %s', soundPath);
end

%% Setup
[hSubj, hTest] = ExperimentCommon.setupDualUI('Consonants', subjID);
[PA5, PA5_2] = ExperimentCommon.initHardware(atten);
[fid, csvPath] = ExperimentCommon.initLogFile(subjID, 'consonants', condition);

fprintf(fid, 'Subject,Trial,Speaker,Consonant,Response,Correct,RT,Condition\n');
fprintf('Started Consonants experiment for %s (%s)\n', subjID, condition);

%% Stimuli
speakers = {'ah-a', 'ct-a', 'lf-a', 'sy-a'};
consonants = {'b', 'd', 'f', 'g', 'k', 'm', 'n', 'p', 's', 't', 'v', 'z', '#', '%', '$', '?'};
labels = {'B', 'D', 'F', 'G', 'K', 'M', 'N', 'P', 'S', 'T', 'V', 'Z', '#', '%', '$', '?'};
numCons = length(consonants);

%% Setup Response Buttons
resp = [];
resp.val = 0;
resp.ready = false;

    function btnClick(idx, ~)
        resp.val = idx;
        resp.ready = true;
    end

btns = ExperimentCommon.createGridButtons(hSubj.panelResp, labels, @btnClick, 4, 4);

%% Trial Generation
rng('shuffle');
totalStim = numCons * length(speakers);
trialOrder = mod(randperm(ceil(howmany)), totalStim) + 1;

%% Main Loop
scoreCum = 0;
results = [];
results.correct = [];
results.response = [];
results.target = [];

set(hTest.txtStatus, 'String', 'Running...');
set(hSubj.txtInstruct, 'String', 'Press any button to start');
ExperimentCommon.waitForResponse(btns, 'on');
while ~resp.ready, pause(0.1); end

for trial = 1:howmany
    ExperimentCommon.waitForResponse(btns, 'off');
    resp.ready = false;

    stimIdx = trialOrder(trial);
    consID = mod(stimIdx - 1, numCons) + 1;
    spkID = floor((stimIdx - 1) / numCons) + 1;

    fname = fullfile(soundPath, [speakers{spkID} consonants{consID} 'a.wav']);
    if ~exist(fname, 'file')
        % Try without 'a' suffix just in case
        fname = fullfile(soundPath, [speakers{spkID} consonants{consID} '.wav']);
    end

    if exist(fname, 'file')
        [y, fs] = audioread(fname);
        y = y * 1.982;

        % Play
        set(hSubj.txtInstruct, 'String', 'Listen...', 'ForegroundColor', 'white');
        drawnow;
        pause(0.5);
        sound(y, fs);
        pause(length(y)/fs + 0.2);
    else
        warning('File not found: %s', fname);
        y = zeros(fs,1); % Skip
    end

    % Get Response
    set(hSubj.txtInstruct, 'String', 'Select Consonant');
    ExperimentCommon.waitForResponse(btns, 'on');

    tStart = tic;
    while ~resp.ready && ishandle(hSubj.fig)
        pause(0.05);
    end
    rt = toc(tStart);

    if ~ishandle(hSubj.fig), break; end

    % Score
    isCorrect = (resp.val == consID);
    scoreCum = scoreCum + isCorrect;

    results.target(end+1) = consID;
    results.response(end+1) = resp.val;
    results.correct(end+1) = isCorrect;

    % Log
    fprintf(fid, '%s,%d,%s,%s,%s,%d,%.3f,%s\n', ...
        subjID, trial, speakers{spkID}, consonants{consID}, ...
        consonants{resp.val}, isCorrect, rt, condition);

    % Feedback
    if feedbackEnabled
        if isCorrect
            set(hSubj.txtInstruct, 'String', 'CORRECT', 'ForegroundColor', 'green');
        else
            set(hSubj.txtInstruct, 'String', ['Incorrect: ' labels{consID}], 'ForegroundColor', 'red');
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
        C = zeros(numCons);
        for i = 1:length(results.target)
            t = results.target(i);
            r = results.response(i);
            C(t,r) = C(t,r) + 1;
        end
        imagesc(C); colormap('hot'); colorbar;
        set(gca, 'XTick', 1:numCons, 'XTickLabel', labels, 'YTick', 1:numCons, 'YTickLabel', labels);
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
