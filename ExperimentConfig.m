classdef ExperimentConfig < handle
    % ExperimentConfig - Manages paths and settings for auditory experiments
    %
    % Usage:
    %   config = ExperimentConfig('vowels', 'S001');
    %   config.setupPaths();

    properties
        % Subject information
        subjectID char
        condition char = 'default'

        % Experiment type
        experimentType char  % 'vowels', 'consonants', 'crm'

        % Paths
        soundPath char
        dataPath char
        developmentPath char = 'C:/Development/Matlab/'

        % Audio settings
        attenuation double = 18.0
        sampleRate double = 44100

        % Experiment settings
        numTrials double
        feedbackEnabled logical = false

        % Hardware settings
        useHardware logical = true
        pa5USB1 double = 1
        pa5USB2 double = 2

        % Output files
        outputFile char
        summaryFile char
        timestamp char
    end

    methods
        function obj = ExperimentConfig(experimentType, subjectID)
            % Constructor
            if nargin > 0
                obj.experimentType = lower(experimentType);
                obj.subjectID = subjectID;
                obj.timestamp = datestr(now, 'yyyymmdd_HHMMSS');
                obj.setDefaultPaths();
                obj.setDefaultTrials();
            end
        end

        function setDefaultPaths(obj)
            % Set default paths based on experiment type
            switch obj.experimentType
                case 'vowels'
                    obj.soundPath = 'C:/SoundFiles/Vowels/';
                    obj.sampleRate = 44100;
                    obj.attenuation = 18.0;

                case 'consonants'
                    obj.soundPath = 'C:/SoundFiles/Multi/Full/';
                    obj.sampleRate = 22050;
                    obj.attenuation = 22.0;

                case 'crm'
                    obj.soundPath = 'C:/SoundFiles/CRMCorpus/';
                    obj.sampleRate = 44100;
                    obj.attenuation = 15.0;

                otherwise
                    error('Unknown experiment type: %s', obj.experimentType);
            end

            obj.dataPath = fullfile('C:', 'Experiments', 'Data', obj.subjectID);
        end

        function setDefaultTrials(obj)
            % Set default number of trials
            switch obj.experimentType
                case 'vowels'
                    obj.numTrials = 180;
                case 'consonants'
                    obj.numTrials = 64;
                case 'crm'
                    obj.numTrials = 2;  % Number of runs
            end
        end

        function setupPaths(obj)
            % Create data directory if it doesn't exist
            if ~exist(obj.dataPath, 'dir')
                success = mkdir('C:/Experiments/Data/', obj.subjectID);
                if ~success
                    error('Failed to create data directory: %s', obj.dataPath);
                end
                fprintf('Created data directory: %s\n', obj.dataPath);
            end

            % Setup output filenames
            baseFilename = sprintf('%s_%s_%s_%s', ...
                obj.subjectID, obj.experimentType, obj.condition, obj.timestamp);

            obj.outputFile = fullfile(obj.dataPath, [baseFilename '.csv']);
            obj.summaryFile = fullfile(obj.dataPath, [baseFilename '_summary.json']);

            % Check for existing files
            if exist(obj.outputFile, 'file')
                warning('Output file already exists: %s', obj.outputFile);
            end
        end

        function validateSoundPath(obj)
            % Verify sound files directory exists
            if ~exist(obj.soundPath, 'dir')
                error('Sound file directory does not exist: %s', obj.soundPath);
            end
        end

        function struct = toStruct(obj)
            % Convert config to structure for saving
            struct.subjectID = obj.subjectID;
            struct.condition = obj.condition;
            struct.experimentType = obj.experimentType;
            struct.soundPath = obj.soundPath;
            struct.dataPath = obj.dataPath;
            struct.attenuation = obj.attenuation;
            struct.sampleRate = obj.sampleRate;
            struct.numTrials = obj.numTrials;
            struct.feedbackEnabled = obj.feedbackEnabled;
            struct.timestamp = obj.timestamp;
            struct.matlabVersion = version;
            struct.computerName = getenv('COMPUTERNAME');
        end
    end
end
