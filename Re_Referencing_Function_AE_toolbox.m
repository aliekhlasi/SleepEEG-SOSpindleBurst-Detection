function [EEG_reref, Channels] = Re_Referencing_Function_AE_toolbox(recording, My_EEG, My_Channel, SamplingRate, leftChannels, rightChannels, midlineChannels, dirPaths)
    % RE_REFERENCING_FUNCTION_AE_TOOLBOX - Re-reference EEG data based on specified channels.
    %
    % Inputs:
    %   recording      - Name of the current recording (string).
    %   My_EEG         - EEG data matrix (channels x samples).
    %   My_Channel      - Cell array of channel names.
    %   SamplingRate   - Sampling rate of the EEG data.
    %   leftChannels   - Cell array of left channel names.
    %   rightChannels  - Cell array of right channel names.
    %   midlineChannels - Cell array of midline channel names.
    %   dirPaths       - Cell array of directory paths for saving results.
    %
    % Outputs:
    %   EEG_reref      - Structure containing re-referenced EEG data and metadata.
    %   Channels       - Cell array of remaining channel names after re-referencing.

    % Initialize output structure
    EEG_reref = struct();

    %% Find indices for left channels
    LeftChannelIndices = findChannelIndices(My_Channel, leftChannels);

    %% Find indices for right channels
    RightChannelIndices = findChannelIndices(My_Channel, rightChannels);

    %% Find indices for midline channels
    MidChannelIndices = findChannelIndices(My_Channel, midlineChannels);

    %% Find indices of reference channels M1 and M2
    M1Index = find(strcmpi(My_Channel, 'M1'));
    M2Index = find(strcmpi(My_Channel, 'M2'));

    %% Re-reference EEG data
    % Subtract M2 channel data from left channels
    EEG_reref.data(LeftChannelIndices, :) = My_EEG(LeftChannelIndices, :) - ...
        repmat(My_EEG(M2Index, :), numel(LeftChannelIndices), 1);

    % Subtract M1 channel data from right channels
    EEG_reref.data(RightChannelIndices, :) = My_EEG(RightChannelIndices, :) - ...
        repmat(My_EEG(M1Index, :), numel(RightChannelIndices), 1);

    % Compute midline data as the average of M1 and M2
    midlineData = My_EEG(MidChannelIndices, :) - ...
        (repmat((My_EEG(M2Index, :) + My_EEG(M1Index, :)), numel(MidChannelIndices), 1) / 2);
    EEG_reref.data(MidChannelIndices, :) = midlineData;

    %% Clean up the data
    % Remove channels M1 and M2 from channel list and data
    My_Channel(M2Index) = [];
    My_Channel(M1Index) = [];
    EEG_reref.data(M2Index, :) = [];
    EEG_reref.data(M1Index, :) = [];

    % Remove rows with all zeros
    EEG_reref.data(~any(EEG_reref.data, 2), :) = [];

    %% Update EEG_reref structure with metadata
    EEG_reref.nbchan = size(EEG_reref.data, 1);  % Number of channels
    EEG_reref.srate = SamplingRate;  % Sampling rate
    EEG_reref.trials = 1;  % Number of trials
    EEG_reref.event = [];  % Event information
    EEG_reref.pnts = size(EEG_reref.data, 2);  % Number of points per epoch

    % Assign remaining channel labels
    Channels = My_Channel;

    %% Save output if the directory path is provided
    if ~isempty(dirPaths) && ~isempty(dirPaths{1})
        % Define output filename
        outputFilename = fullfile(dirPaths{1}, [recording '_EEG_reref.mat']);
        % Save the EEG_reref and Channels variables
        save(outputFilename, 'EEG_reref', 'Channels');
        disp(['Data saved to: ', outputFilename]);
    else
        disp('No directory path provided for saving. Data not saved.');
    end
end

function indices = findChannelIndices(My_Channel, channelNames)
    % FINDCHANNELINDICES - Helper function to find indices of specified channels.
    %
    % Inputs:
    %   My_Channel   - Cell array of channel names.
    %   channelNames - Cell array of channel names to find.
    %
    % Outputs:
    %   indices      - Array of indices corresponding to the found channels.

    indices = zeros(1, length(channelNames)); % Preallocate indices array
    for i = 1:length(channelNames)
        channelName = channelNames{i};  % Get channel name
        indices(i) = find(strcmpi(My_Channel, channelName));  % Find channel index
    end
end
