function setupToolbox()
    % SETUPTOOLBOX - Add the toolbox function folders to the MATLAB path.
    % Prompts the user to select the toolbox folder (the one containing
    % Main_Toolbox.m) and adds its 'Spindle Functions' and
    % 'Burst Detection Functions' subfolders to the path.
    %
    %   Part of SleepRhythms
    %   Developed at the Sleep and Cognition (SaC) Lab, UC Irvine. Maintainer: Ali Ekhlasi
    %   https://github.com/aliekhlasi/SleepRhythms

    % Prompt user to select the toolbox directory
    toolboxDir = uigetdir('', 'Select the Toolbox Directory');

    % Check if the user pressed Cancel
    if isequal(toolboxDir, 0)
        disp('User cancelled the selection. Toolbox setup aborted.');
        return;
    end
    disp(['Selected Toolbox Directory: ', toolboxDir]);

    % Add the function folders to the MATLAB path
    subFolders = {'Spindle Functions', 'Burst Detection Functions'};
    for k = 1:numel(subFolders)
        folder = fullfile(toolboxDir, subFolders{k});
        if ~exist(folder, 'dir')
            error('Folder not found: %s\nDid you select the folder that contains Main_Toolbox.m?', folder);
        end
        addpath(folder);
        disp(['Added to path: ', folder]);
    end

    % Check that the required external functions are available
    required = {'pop_eegfiltnew', 'EEGLAB'; 'butter', 'Signal Processing Toolbox'; ...
                'findpeaks', 'Signal Processing Toolbox'; 'cwt', 'Wavelet Toolbox'; ...
                'zscore', 'Statistics and Machine Learning Toolbox'; 'smooth', 'Curve Fitting Toolbox'};
    for k = 1:size(required, 1)
        if isempty(which(required{k, 1}))
            warning('%s not found. Please install/add %s.', required{k, 1}, required{k, 2});
        end
    end
end
