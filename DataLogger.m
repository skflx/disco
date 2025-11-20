classdef DataLogger < handle
    % DataLogger - Handles standardized data logging for auditory experiments
    %
    % Usage:
    %   logger = DataLogger(config);
    %   logger.initialize();
    %   logger.logTrial(trialData);
    %   logger.finalize(summary);

    properties
        config ExperimentConfig
        fileID double
        trialCount double = 0
        allTrials cell
    end

    methods
        function obj = DataLogger(config)
            % Constructor
            obj.config = config;
            obj.allTrials = {};
        end

        function initialize(obj)
            % Open CSV file and write header
            obj.fileID = fopen(obj.config.outputFile, 'w');
            if obj.fileID == -1
                error('Failed to open output file: %s', obj.config.outputFile);
            end

            % Write CSV header based on experiment type
            switch obj.config.experimentType
                case 'vowels'
                    fprintf(obj.fileID, 'trial,timestamp,speaker_id,vowel_id,response_id,correct,rt_sec\n');

                case 'consonants'
                    fprintf(obj.fileID, 'trial,timestamp,speaker_id,consonant_id,response_id,correct,rt_sec\n');

                case 'crm'
                    fprintf(obj.fileID, 'run,trial,timestamp,target_color,target_number,response_color,response_number,color_correct,number_correct,snr_db,rt_sec\n');
            end

            fprintf('Logging data to: %s\n', obj.config.outputFile);
        end

        function logTrial(obj, trialData)
            % Log a single trial to CSV file
            obj.trialCount = obj.trialCount + 1;

            % Add timestamp if not present
            if ~isfield(trialData, 'timestamp')
                trialData.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS.FFF');
            end

            % Store in memory
            obj.allTrials{end+1} = trialData;

            % Write to file based on experiment type
            switch obj.config.experimentType
                case 'vowels'
                    fprintf(obj.fileID, '%d,%s,%d,%d,%d,%d,%.4f\n', ...
                        trialData.trial, ...
                        trialData.timestamp, ...
                        trialData.speaker_id, ...
                        trialData.vowel_id, ...
                        trialData.response_id, ...
                        trialData.correct, ...
                        trialData.rt_sec);

                case 'consonants'
                    fprintf(obj.fileID, '%d,%s,%d,%d,%d,%d,%.4f\n', ...
                        trialData.trial, ...
                        trialData.timestamp, ...
                        trialData.speaker_id, ...
                        trialData.consonant_id, ...
                        trialData.response_id, ...
                        trialData.correct, ...
                        trialData.rt_sec);

                case 'crm'
                    fprintf(obj.fileID, '%d,%d,%s,%d,%d,%d,%d,%d,%d,%.2f,%.4f\n', ...
                        trialData.run, ...
                        trialData.trial, ...
                        trialData.timestamp, ...
                        trialData.target_color, ...
                        trialData.target_number, ...
                        trialData.response_color, ...
                        trialData.response_number, ...
                        trialData.color_correct, ...
                        trialData.number_correct, ...
                        trialData.snr_db, ...
                        trialData.rt_sec);
            end
        end

        function finalize(obj, summary)
            % Close file and write summary JSON
            if obj.fileID ~= -1
                fclose(obj.fileID);
                obj.fileID = -1;
            end

            % Calculate overall statistics
            summary.total_trials = obj.trialCount;
            summary.config = obj.config.toStruct();
            summary.date_completed = datestr(now, 'yyyy-mm-dd HH:MM:SS');

            % Calculate accuracy
            if strcmp(obj.config.experimentType, 'crm')
                % CRM has both color and number correctness
                allCorrect = cellfun(@(x) x.color_correct && x.number_correct, obj.allTrials);
            else
                allCorrect = cellfun(@(x) x.correct, obj.allTrials);
            end
            summary.overall_accuracy = mean(allCorrect) * 100;

            % Calculate mean RT
            allRTs = cellfun(@(x) x.rt_sec, obj.allTrials);
            summary.mean_rt_sec = mean(allRTs);
            summary.std_rt_sec = std(allRTs);

            % Write summary to JSON
            obj.writeSummaryJSON(summary);

            fprintf('\nData logging complete.\n');
            fprintf('Trials: %d\n', summary.total_trials);
            fprintf('Accuracy: %.2f%%\n', summary.overall_accuracy);
            fprintf('Mean RT: %.2f sec\n', summary.mean_rt_sec);
            fprintf('Files saved:\n  %s\n  %s\n', ...
                obj.config.outputFile, obj.config.summaryFile);
        end

        function writeSummaryJSON(obj, summary)
            % Write summary data to JSON file
            try
                % Convert to JSON string
                jsonStr = jsonencode(summary);

                % Pretty print (add newlines and indentation)
                jsonStr = strrep(jsonStr, ',', sprintf(',\n  '));
                jsonStr = strrep(jsonStr, '{', sprintf('{\n  '));
                jsonStr = strrep(jsonStr, '}', sprintf('\n}'));

                % Write to file
                fid = fopen(obj.config.summaryFile, 'w');
                if fid == -1
                    warning('Failed to write summary JSON file');
                    return;
                end
                fprintf(fid, '%s', jsonStr);
                fclose(fid);

            catch ME
                warning('Error writing JSON summary: %s', ME.message);
            end
        end

        function confusion = computeConfusionMatrix(obj, numCategories)
            % Compute confusion matrix from logged trials
            confusion = zeros(numCategories, numCategories);

            for i = 1:length(obj.allTrials)
                trial = obj.allTrials{i};
                if strcmp(obj.config.experimentType, 'vowels')
                    target = trial.vowel_id;
                else
                    target = trial.consonant_id;
                end
                response = trial.response_id;

                if target > 0 && target <= numCategories && ...
                   response > 0 && response <= numCategories
                    confusion(target, response) = confusion(target, response) + 1;
                end
            end
        end
    end
end
