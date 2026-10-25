function [leftChannels, rightChannels, midlineChannels] = assignChannels(My_Channel)
    % ASSIGNCHANNELS - Ask the user which scalp channels are left, right and midline.
    %
    % The mastoid reference channels (M1, M2) are not shown: they are found
    % automatically by the re-referencing step.
    %
    % Outputs:
    %   leftChannels    - Selected left channels (referenced to M2).
    %   rightChannels   - Selected right channels (referenced to M1).
    %   midlineChannels - Selected midline channels (referenced to (M1+M2)/2).
    %
    %   Part of SleepRhythms
    %   Developed at the Sleep and Cognition (SaC) Lab, UC Irvine. Maintainer: Ali Ekhlasi
    %   https://github.com/aliekhlasi/SleepRhythms

    allChannels = cellstr(My_Channel);
    scalp = allChannels(~(strcmpi(allChannels, 'M1') | strcmpi(allChannels, 'M2')));

    leftChannels    = pick(scalp, 'Select LEFT channels (referenced to M2):');
    rightChannels   = pick(scalp, 'Select RIGHT channels (referenced to M1):');
    midlineChannels = pick(scalp, 'Select MIDLINE channels (referenced to (M1+M2)/2):');

    if isempty([leftChannels, rightChannels, midlineChannels])
        error('No channels selected.');
    end

    disp('Selected channels:');
    fprintf('  Left:    %s\n', strjoin(leftChannels, ', '));
    fprintf('  Right:   %s\n', strjoin(rightChannels, ', '));
    fprintf('  Midline: %s\n', strjoin(midlineChannels, ', '));
end

function chosen = pick(list, prompt)
    % One selection window. An empty selection (or Cancel) gives an empty group.
    sel = listdlg('PromptString', prompt, 'SelectionMode', 'multiple', ...
                  'ListString', list, 'ListSize', [320 300]);
    chosen = list(sel);
    chosen = chosen(:)';
end
