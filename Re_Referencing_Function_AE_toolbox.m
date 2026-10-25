function [EEG_reref, Channels] = Re_Referencing_Function_AE_toolbox(recording, My_EEG, My_Channel, SamplingRate, leftChannels, rightChannels, midlineChannels, dirPaths)
    % RE_REFERENCING_FUNCTION_AE_TOOLBOX - Re-reference EEG to the mastoids.
    %
    %   Left channels    - M2   (contralateral mastoid)
    %   Right channels   - M1   (contralateral mastoid)
    %   Midline channels - (M1 + M2) / 2
    %
    % The mastoid channels are found by name ('M1' and 'M2', not case
    % sensitive), so they do not need to be selected. If they are selected
    % in one of the groups they are simply ignored.
    %
    % Inputs:
    %   recording       - Name of the current recording (string).
    %   My_EEG          - EEG data matrix (channels x samples) [uV].
    %   My_Channel      - Cell array of channel names (must include M1 and M2).
    %   SamplingRate    - Sampling rate of the EEG data [Hz].
    %   leftChannels    - Cell array of left channel names.
    %   rightChannels   - Cell array of right channel names.
    %   midlineChannels - Cell array of midline channel names.
    %   dirPaths        - Result folders from createResultDirectories.
    %
    % Outputs:
    %   EEG_reref - EEGLAB-style structure with the re-referenced data
    %               (one row per selected scalp channel, in recording order).
    %   Channels  - Names of the channels in EEG_reref.data, same order.
    %
    %   Part of SleepEEG-SOSpindleBurst-Detection
    %   Maintainer: Ali Ekhlasi, Sleep and Cognition (SaC) Lab
    %   https://github.com/aliekhlasi/SleepEEG-SOSpindleBurst-Detection

    My_Channel = cellstr(My_Channel);

    %% Find the mastoid channels by name
    M1Index = find(strcmpi(My_Channel, 'M1'));
    M2Index = find(strcmpi(My_Channel, 'M2'));
    if isempty(M1Index) || isempty(M2Index)
        error(['Re-referencing needs channels named ''M1'' and ''M2''. ', ...
               'Channels found: %s'], strjoin(My_Channel, ', '));
    end

    %% Clean up the channel groups
    isMastoid = @(c) strcmpi(c, 'M1') | strcmpi(c, 'M2');
    groups = {cellstr(leftChannels), cellstr(rightChannels), cellstr(midlineChannels)};
    for g = 1:3
        groups{g} = groups{g}(~isMastoid(groups{g}));  % Ignore M1/M2 if selected
    end
    allSelected = [groups{:}];
    if isempty(allSelected)
        error('No scalp channels were selected for re-referencing.');
    end
    [uniqueSel, ~, idx] = unique(lower(allSelected));
    counts = accumarray(idx(:), 1);
    if any(counts > 1)
        error('Channel(s) selected in more than one group: %s', strjoin(uniqueSel(counts > 1), ', '));
    end

    %% Reference signal for each group
    refs = { My_EEG(M2Index, :), ...                          % left  -> M2
             My_EEG(M1Index, :), ...                          % right -> M1
             (My_EEG(M1Index, :) + My_EEG(M2Index, :)) / 2 }; % midline -> mean of mastoids

    %% Re-reference, keeping the original channel order
    keep = false(numel(My_Channel), 1);
    data = zeros(size(My_EEG));
    for g = 1:3
        for c = 1:numel(groups{g})
            k = find(strcmpi(My_Channel, groups{g}{c}), 1);
            if isempty(k)
                error('Channel ''%s'' not found in the recording.', groups{g}{c});
            end
            data(k, :) = My_EEG(k, :) - refs{g};
            keep(k) = true;
        end
    end

    %% Build the output structure
    EEG_reref = struct();
    EEG_reref.data = data(keep, :);
    EEG_reref.nbchan = sum(keep);
    EEG_reref.srate = SamplingRate;
    EEG_reref.trials = 1;
    EEG_reref.event = [];
    EEG_reref.pnts = size(My_EEG, 2);
    Channels = My_Channel(keep);
    Channels = Channels(:)';

    fprintf('Re-referenced %d channels: %s\n', numel(Channels), strjoin(Channels, ', '));

    %% Save
    if ~isempty(dirPaths) && ~isempty(dirPaths{1})
        outputFilename = fullfile(dirPaths{1}, [recording '_EEG_reref.mat']);
        save(outputFilename, 'EEG_reref', 'Channels');
        disp(['Data saved to: ', outputFilename]);
    else
        disp('No directory path provided for saving. Data not saved.');
    end
end
