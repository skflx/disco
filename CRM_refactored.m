function [rundata, runrev] = CRM_refactored(subjID, talker, maskers, nrun, feedback, atten)
% CRM_REFACTORED - Coordinate Response Measure (Dual Window Version)
%
% Inputs:
%   subjID    - Subject identifier
%   talker    - Target talker ID (0-7)
%   maskers   - Two masker IDs [M1 M2]
%   nrun      - Number of runs (default: 2)
%   feedback  - 'y' or 'n' (default: 'n')
%   atten     - Attenuation dB (default: 15.0)

%% Parse Inputs
if nargin < 3, error('Subject ID, Talker, and Maskers required'); end
if nargin < 4, nrun = 2; end
if nargin < 5, feedback = 'n'; end
if nargin < 6, atten = 15.0; end

feedbackEnabled = strcmpi(feedback, 'y');

% Validate talker/maskers
if talker < 0 || talker > 7, error('Talker must be 0-7'); end
if length(maskers) ~= 2, error('Maskers must be 2 IDs'); end
if any(maskers == talker), error('Masker cannot be target'); end

% Sound paths
baseDir = 'C:\SoundFiles\CRMCorpus\original';
if ~exist(baseDir, 'dir')
    error('Sound corpus not found: %s', baseDir);
end
pathT = fullfile(baseDir, sprintf('Talker%d', talker));
pathM1 = fullfile(baseDir, sprintf('Talker%d', maskers(1)));
pathM2 = fullfile(baseDir, sprintf('Talker%d', maskers(2)));

%% Setup
[hSubj, hTest] = ExperimentCommon.setupDualUI('CRM', subjID);
[PA5, PA5_2] = ExperimentCommon.initHardware(atten);
[fid, csvPath] = ExperimentCommon.initLogFile(subjID, 'CRM', sprintf('T%d_M%d-%d', talker, maskers(1), maskers(2)));

fprintf(fid, 'Run,Trial,TargetCol,TargetNum,RespCol,RespNum,Correct,SNR,Reversal,RT\n');

%% Setup Response Buttons (4 Colors x 8 Numbers)
% Custom layout for CRM
clf(hSubj.panelResp);
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
    trialData = [];

    % Trials (Reversal criterion)
    trial = 0;
    while nrev < 14 && trial < 100
        trial = trial + 1;
        ExperimentCommon.waitForResponse(btns, 'off');
        resp.ready = false;

        % Stimuli
        c = randperm(4)-1; n = randperm(8)-1;
        tgtC = c(1); tgtN = n(1);

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

        % Play
        set(hSubj.txtInstruct, 'String', 'Listen...', 'ForegroundColor', 'white');
        drawnow;
        pause(0.5);
        sound(y, fs);
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
        plot(1:length(snrHistory), snrHistory, 'b-o');
        ylabel('SNR (dB)'); xlabel('Trial'); title(sprintf('Run %d SNR Track', run));
        grid on;

    end

    rundata{run} = snrHistory;
    runrev{run} = revHistory;

    if run < nrun
        set(hSubj.txtInstruct, 'String', 'Run Complete. Press button for next run.');
        ExperimentCommon.waitForResponse(btns, 'on');
        while ~resp.ready, pause(0.1); end
    end
end

%% Finish
fclose(fid);
set(hSubj.txtInstruct, 'String', 'Experiment Complete.');
pause(2);

if ~isempty(PA5), delete(PA5); delete(PA5_2); end
close(hSubj.fig);
close(hTest.fig);

end
