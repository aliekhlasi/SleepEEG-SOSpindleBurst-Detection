function [leftChannels, rightChannels, midlineChannels] = assignChannels(My_Channel)
    % ASSIGNCHANNELS - Assign channels based on user selection from a cell array.
    % Outputs:
    %   leftChannels - Selected left channels.
    %   rightChannels - Selected right channels.
    %   midlineChannels - Selected midline channels.

    % Example cell array with 24 elements
    allChannels = My_Channel;

    % Ask the user to select left channels
    leftSelection = listdlg('PromptString', 'Select Left Channels:', ...
                             'SelectionMode', 'multiple', ...
                             'ListString', allChannels);
    
    % Check if the user made a selection for left channels
    if isempty(leftSelection)
        disp('No left channels selected. Exiting.');
        leftChannels = {};
        rightChannels = {};
        midlineChannels = {};
        return; % Exit the function
    end

    % Assign selected left channels
    leftChannels = allChannels(leftSelection);
    
    % Ask the user to select right channels
    rightSelection = listdlg('PromptString', 'Select Right Channels:', ...
                              'SelectionMode', 'multiple', ...
                              'ListString', allChannels);
    
    % Check if the user made a selection for right channels
    if isempty(rightSelection)
        disp('No right channels selected. Exiting.');
        rightChannels = {};
        midlineChannels = {};
        return; % Exit the function
    end

    % Assign selected right channels
    rightChannels = allChannels(rightSelection);
    
    % Ask the user to select midline channels
    midlineSelection = listdlg('PromptString', 'Select Midline Channels:', ...
                                'SelectionMode', 'multiple', ...
                                'ListString', allChannels);
    
    % Check if the user made a selection for midline channels
    if isempty(midlineSelection)
        disp('No midline channels selected. Exiting.');
        midlineChannels = {};
        return; % Exit the function
    end

    % Assign selected midline channels
    midlineChannels = allChannels(midlineSelection);

    % Display selected channels
    disp('Final Selected Channels:');
    disp('Left Channels:');
    disp(leftChannels);
    disp('Right Channels:');
    disp(rightChannels);
    disp('Midline Channels:');
    disp(midlineChannels);
end