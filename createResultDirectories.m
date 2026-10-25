function [selectedFolder, dirPaths] = createResultDirectories()
    % CREATERESULTDIRECTORIES - Ask for a results folder and create one
    % subfolder per processing step.
    %
    % Outputs:
    %   selectedFolder - The folder selected by the user.
    %   dirPaths       - 1x4 cell array of subfolder paths:
    %                    {1} 1_Rereferenced
    %                    {2} 2_SlowOscillations
    %                    {3} 3_Spindles
    %                    {4} 4_Bursts
    %
    %   Part of SleepRhythms
    %   Developed at the Sleep and Cognition (SaC) Lab, UC Irvine. Maintainer: Ali Ekhlasi
    %   https://github.com/aliekhlasi/SleepRhythms

    % Prompt the user to select a folder for saving results
    selectedFolder = uigetdir('', 'Select a folder to save the results');

    % Check if the user pressed Cancel
    if isequal(selectedFolder, 0)
        disp('User cancelled the folder selection. No directories were created.');
        dirPaths = {};
        return;
    end
    disp(['Selected folder for saving results: ', selectedFolder]);

    % One subfolder per processing step
    subDirs = {'1_Rereferenced', '2_SlowOscillations', '3_Spindles', '4_Bursts'};
    dirPaths = cell(1, numel(subDirs));

    for i = 1:numel(subDirs)
        dirPaths{i} = fullfile(selectedFolder, subDirs{i});
        if ~exist(dirPaths{i}, 'dir')
            mkdir(dirPaths{i});
        end
        disp(['Results folder: ', dirPaths{i}]);
    end
end
