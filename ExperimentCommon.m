classdef ExperimentCommon
    % EXPERIMENTCOMMON - Shared utilities for auditory experiments
    % consolidates UI, Hardware, and Logging to reduce file count.

    methods (Static)
        function [hSubj, hTest] = setupDualUI(expName, subjectID)
            % SETUPDUALUI - Creates Subject (2nd Monitor) and Tester (1st Monitor) figures

            % Get Monitor Positions
            mp = get(0, 'MonitorPositions');
            % Sort by X position to ensure left-to-right ordering
            [~, idx] = sort(mp(:,1));
            mp = mp(idx, :);

            % Determine monitors
            if size(mp, 1) > 1
                posTest = mp(1, :); % Primary
                posSubj = mp(2, :); % Secondary
            else
                % Single monitor - split screen? Or just overlap.
                % Let's put Tester on left, Subject on right for dev/testing
                scrSz = mp(1, :);
                w = scrSz(3)/2;
                posTest = [1, 1, w, scrSz(4)*0.9];
                posSubj = [w+1, 1, w, scrSz(4)*0.9];
                fprintf('Single monitor detected. Splitting screen.\n');
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

        function [PA5, PA5_2] = initHardware(atten)
            % INITHARDWARE - Initialize TDT PA5 attenuators
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
                    disp(['PA5 Error: ' err]);
                end
            catch
                warning('TDT PA5 hardware initialization failed. Running in simulation mode.');
                PA5 = []; PA5_2 = [];
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
    end
end
