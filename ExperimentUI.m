classdef ExperimentUI < handle
    % ExperimentUI - Modern UI with real-time plotting for auditory experiments
    %
    % Usage:
    %   ui = ExperimentUI(config);
    %   ui.initialize();
    %   ui.updateProgress(trial, total);
    %   ui.updatePlot(data);

    properties
        config ExperimentConfig
        figure
        axes1  % Main plot (accuracy or adaptive track)
        axes2  % Secondary plot (confusion matrix)
        progressBar
        instructionText
        trialText
        accuracyText

        % Response collection
        responseValue double = 0
        waitingForResponse logical = false
        buttonPanel
        buttons

        % Data for plotting
        trialNumbers = []
        accuracyData = []
        confusionMatrix = []

        % CRM-specific
        snrTrack = []
        reversalMarkers = []
    end

    methods
        function obj = ExperimentUI(config)
            % Constructor
            obj.config = config;
        end

        function initialize(obj)
            % Create modern UI figure
            obj.figure = figure('Name', sprintf('%s Experiment - %s', ...
                upper(obj.config.experimentType), obj.config.subjectID), ...
                'NumberTitle', 'off', ...
                'Position', [100, 100, 1200, 700], ...
                'Color', [0.94 0.94 0.94], ...
                'MenuBar', 'none', ...
                'ToolBar', 'none', ...
                'CloseRequestFcn', @(~,~) obj.closeUI());

            % Create UI components based on experiment type
            switch obj.config.experimentType
                case {'vowels', 'consonants'}
                    obj.initializeRecognitionUI();
                case 'crm'
                    obj.initializeCRMUI();
            end
        end

        function initializeRecognitionUI(obj)
            % UI for vowel/consonant recognition tests

            % Instructions panel (top)
            instructPanel = uipanel(obj.figure, ...
                'Position', [0.02 0.88 0.96 0.10], ...
                'BackgroundColor', [0.3 0.5 0.8], ...
                'BorderType', 'none');

            obj.instructionText = uicontrol(instructPanel, ...
                'Style', 'text', ...
                'Units', 'normalized', ...
                'Position', [0.05 0.1 0.9 0.8], ...
                'String', 'Press START to begin', ...
                'FontSize', 16, ...
                'FontWeight', 'bold', ...
                'ForegroundColor', 'white', ...
                'BackgroundColor', [0.3 0.5 0.8], ...
                'HorizontalAlignment', 'center');

            % Progress panel (upper middle)
            progressPanel = uipanel(obj.figure, ...
                'Position', [0.02 0.78 0.96 0.08], ...
                'Title', 'Progress', ...
                'FontSize', 12, ...
                'FontWeight', 'bold');

            obj.trialText = uicontrol(progressPanel, ...
                'Style', 'text', ...
                'Units', 'normalized', ...
                'Position', [0.05 0.5 0.4 0.4], ...
                'String', 'Trial: 0 / 0', ...
                'FontSize', 14, ...
                'HorizontalAlignment', 'left');

            obj.accuracyText = uicontrol(progressPanel, ...
                'Style', 'text', ...
                'Units', 'normalized', ...
                'Position', [0.55 0.5 0.4 0.4], ...
                'String', 'Accuracy: --%', ...
                'FontSize', 14, ...
                'HorizontalAlignment', 'right');

            % Plotting area (middle)
            plotPanel = uipanel(obj.figure, ...
                'Position', [0.02 0.35 0.96 0.41], ...
                'BorderType', 'none');

            % Accuracy plot
            obj.axes1 = subplot(1, 2, 1, 'Parent', plotPanel);
            title('Running Accuracy');
            xlabel('Trial');
            ylabel('Accuracy (%)');
            grid on;
            ylim([0 100]);

            % Confusion matrix plot
            obj.axes2 = subplot(1, 2, 2, 'Parent', plotPanel);
            title('Confusion Matrix');
            xlabel('Response');
            ylabel('Target');
            axis square;
            colormap(obj.axes2, 'hot');

            % Response buttons (bottom)
            obj.createResponseButtons();
        end

        function initializeCRMUI(obj)
            % UI for CRM adaptive test

            % Instructions panel
            instructPanel = uipanel(obj.figure, ...
                'Position', [0.02 0.88 0.96 0.10], ...
                'BackgroundColor', [0.3 0.5 0.8], ...
                'BorderType', 'none');

            obj.instructionText = uicontrol(instructPanel, ...
                'Style', 'text', ...
                'Units', 'normalized', ...
                'Position', [0.05 0.1 0.9 0.8], ...
                'String', 'Press START to begin', ...
                'FontSize', 16, ...
                'FontWeight', 'bold', ...
                'ForegroundColor', 'white', ...
                'BackgroundColor', [0.3 0.5 0.8], ...
                'HorizontalAlignment', 'center');

            % Progress panel
            progressPanel = uipanel(obj.figure, ...
                'Position', [0.02 0.78 0.96 0.08], ...
                'Title', 'Progress', ...
                'FontSize', 12);

            obj.trialText = uicontrol(progressPanel, ...
                'Style', 'text', ...
                'Units', 'normalized', ...
                'Position', [0.05 0.5 0.9 0.4], ...
                'String', 'Run: 0, Trial: 0', ...
                'FontSize', 14, ...
                'HorizontalAlignment', 'center');

            % Adaptive track plot
            plotPanel = uipanel(obj.figure, ...
                'Position', [0.02 0.35 0.96 0.41], ...
                'BorderType', 'none');

            obj.axes1 = axes('Parent', plotPanel, 'Position', [0.1 0.15 0.85 0.75]);
            title('Adaptive SNR Track');
            xlabel('Trial');
            ylabel('SNR (dB)');
            grid on;
            hold on;

            % CRM Response grid (4x8 for colors and numbers)
            obj.createCRMResponseButtons();
        end

        function createResponseButtons(obj)
            % Create response buttons for vowel/consonant tests

            buttonPanel = uipanel(obj.figure, ...
                'Position', [0.02 0.02 0.96 0.31], ...
                'Title', 'Response Options', ...
                'FontSize', 12, ...
                'FontWeight', 'bold');

            % Get labels based on experiment type
            if strcmp(obj.config.experimentType, 'vowels')
                labels = {'AE', 'AH', 'AW', 'EH', 'IH', 'IY', 'OO', 'UH', 'UW'};
                nButtons = 9;
                nCols = 3;
            else  % consonants
                labels = {'B', 'D', 'F', 'G', 'K', 'M', 'N', 'P', 'S', 'T', 'V', 'Z', '#', '%', '$', '?'};
                nButtons = 16;
                nCols = 4;
            end

            nRows = ceil(nButtons / nCols);
            buttonWidth = 0.9 / nCols;
            buttonHeight = 0.85 / nRows;
            margin = 0.02;

            obj.buttons = gobjects(nButtons, 1);

            for i = 1:nButtons
                row = ceil(i / nCols);
                col = mod(i-1, nCols) + 1;

                x = margin + (col-1) * buttonWidth + 0.05;
                y = 1 - row * buttonHeight - 0.05;

                obj.buttons(i) = uicontrol(buttonPanel, ...
                    'Style', 'pushbutton', ...
                    'Units', 'normalized', ...
                    'Position', [x, y, buttonWidth-margin*2, buttonHeight-margin], ...
                    'String', labels{i}, ...
                    'FontSize', 18, ...
                    'FontWeight', 'bold', ...
                    'Enable', 'off', ...
                    'Callback', @(~,~) obj.buttonCallback(i));
            end
        end

        function createCRMResponseButtons(obj)
            % Create 4x8 grid for CRM (4 colors x 8 numbers)

            buttonPanel = uipanel(obj.figure, ...
                'Position', [0.02 0.02 0.96 0.31], ...
                'Title', 'Select Color and Number', ...
                'FontSize', 12);

            colors = {'Blue', 'Red', 'White', 'Green'};
            colorVals = {[0 0 1], [1 0 0], [0.9 0.9 0.9], [0 0.7 0]};

            obj.buttons = gobjects(32, 1);
            buttonIdx = 1;

            for row = 1:4  % 4 colors
                for col = 1:8  % 8 numbers
                    x = 0.05 + (col-1) * 0.11;
                    y = 0.75 - row * 0.20;

                    obj.buttons(buttonIdx) = uicontrol(buttonPanel, ...
                        'Style', 'pushbutton', ...
                        'Units', 'normalized', ...
                        'Position', [x, y, 0.10, 0.18], ...
                        'String', sprintf('%s\n%d', colors{row}, col-1), ...
                        'FontSize', 10, ...
                        'FontWeight', 'bold', ...
                        'BackgroundColor', colorVals{row}, ...
                        'Enable', 'off', ...
                        'UserData', struct('color', row-1, 'number', col-1), ...
                        'Callback', @(src,~) obj.crmButtonCallback(src));

                    buttonIdx = buttonIdx + 1;
                end
            end
        end

        function buttonCallback(obj, buttonNum)
            % Handle button press for vowel/consonant
            obj.responseValue = buttonNum;
            obj.waitingForResponse = false;
        end

        function crmButtonCallback(obj, src)
            % Handle button press for CRM
            data = get(src, 'UserData');
            obj.responseValue = data;
            obj.waitingForResponse = false;
        end

        function response = getResponse(obj, timeout)
            % Wait for user response with optional timeout
            if nargin < 2
                timeout = inf;
            end

            obj.responseValue = 0;
            obj.waitingForResponse = true;

            % Enable buttons
            for i = 1:length(obj.buttons)
                set(obj.buttons(i), 'Enable', 'on');
            end

            % Wait for response
            startTime = tic;
            while obj.waitingForResponse && toc(startTime) < timeout
                pause(0.05);
                drawnow;
            end

            % Disable buttons
            for i = 1:length(obj.buttons)
                set(obj.buttons(i), 'Enable', 'off');
            end

            response = obj.responseValue;
        end

        function updateInstruction(obj, text, color)
            % Update instruction text
            if nargin < 3
                color = 'white';
            end
            set(obj.instructionText, 'String', text, 'ForegroundColor', color);
            drawnow;
        end

        function updateProgress(obj, trial, total, accuracy)
            % Update progress display
            set(obj.trialText, 'String', sprintf('Trial: %d / %d', trial, total));
            if nargin > 3 && ~isnan(accuracy)
                set(obj.accuracyText, 'String', sprintf('Accuracy: %.1f%%', accuracy));
            end
            drawnow;
        end

        function updateAccuracyPlot(obj, trialNum, accuracy)
            % Update running accuracy plot
            obj.trialNumbers(end+1) = trialNum;
            obj.accuracyData(end+1) = accuracy * 100;

            axes(obj.axes1);
            cla;
            plot(obj.trialNumbers, obj.accuracyData, 'b-', 'LineWidth', 2);
            hold on;
            plot(obj.trialNumbers, obj.accuracyData, 'bo', 'MarkerSize', 4, 'MarkerFaceColor', 'b');
            xlabel('Trial');
            ylabel('Accuracy (%)');
            title('Running Accuracy');
            ylim([0 100]);
            grid on;
            drawnow;
        end

        function updateConfusionMatrix(obj, confMatrix, labels)
            % Update confusion matrix heatmap
            axes(obj.axes2);
            imagesc(confMatrix);
            colormap(obj.axes2, 'hot');
            colorbar;
            set(gca, 'XTick', 1:length(labels), 'XTickLabel', labels, 'FontSize', 8);
            set(gca, 'YTick', 1:length(labels), 'YTickLabel', labels, 'FontSize', 8);
            xlabel('Response');
            ylabel('Target');
            title('Confusion Matrix');
            axis square;
            drawnow;
        end

        function updateCRMTrack(obj, snrValues, reversals)
            % Update CRM adaptive track plot
            axes(obj.axes1);
            cla;
            plot(1:length(snrValues), snrValues, 'b-', 'LineWidth', 2);
            hold on;
            plot(1:length(snrValues), snrValues, 'bo', 'MarkerSize', 6, 'MarkerFaceColor', 'b');

            % Mark reversals
            if ~isempty(reversals)
                revTrials = reversals(:, 1);
                revSNRs = reversals(:, 2);
                plot(revTrials, revSNRs, 'rv', 'MarkerSize', 10, 'MarkerFaceColor', 'r', 'LineWidth', 2);
            end

            xlabel('Trial');
            ylabel('SNR (dB)');
            title('Adaptive SNR Track (Reversals marked with red triangles)');
            grid on;
            legend('SNR Track', 'Trials', 'Reversals', 'Location', 'best');
            drawnow;
        end

        function closeUI(obj)
            % Clean close of UI
            if isvalid(obj.figure)
                delete(obj.figure);
            end
        end

        function tf = isOpen(obj)
            % Check if UI is still open
            tf = isvalid(obj.figure) && ishandle(obj.figure);
        end
    end
end
