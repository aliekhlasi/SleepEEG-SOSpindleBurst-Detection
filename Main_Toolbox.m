clc;  % Clear the command window
clear;  % Clear all variables from the workspace
close all;  % Close all figure windows

%% Setup Toolbox
% Ask for the toolbox folder and add its function folders to the MATLAB path
setupToolbox;

%% Create Directories for Saving Results
% Prompt the user to select a folder for saving analysis results and create
% one subfolder per step (1_Rereferenced, 2_SlowOscillations, 3_Spindles, 4_Bursts)
[selectedFolder, dirPaths] = createResultDirectories();

%% Sleep Stage Codes
% The number used for each stage in your scoring file.
% Change these to match your own scoring software.
StageCodes = struct('Wake', 0, 'N1', 1, 'N2', 2, 'N3', 3, 'REM', 5);

%% Prepare EEG Data
% Define a sample recording name (used as the prefix of every output file)
recording = 'Sample';

% Define the channel names for the EEG recording
My_Channel = {
    'Fp1', 'Fp2', 'FPz', 'Fz', 'M1', 'M2'
};

% Define parameters for the simulated EEG data
duration_min = 30;     % Total duration in minutes
SamplingRate = 250;    % Sampling rate in Hz
num_channels = length(My_Channel);  % Number of EEG channels
total_samples = duration_min * 60 * SamplingRate; % Total number of samples

% Generate simulated noise with three different amplitudes
noise_level_1 = (randn(num_channels, total_samples) * 1) * 200 - 100;
noise_level_2 = (randn(num_channels, total_samples) * 0.5) * 200 - 100;
noise_level_3 = (randn(num_channels, total_samples) * 0.2) * 200 - 100;

% Create a random pattern: each sample gets one of the three noise levels
sample_pattern = randi([0, 3], 1, total_samples);

% Combine the simulated data based on the pattern
My_EEG = zeros(num_channels, total_samples);  % Initialize the EEG matrix
for i = 1:total_samples
    switch sample_pattern(i)
        case {0, 1}
            My_EEG(:, i) = noise_level_1(:, i);
        case 2
            My_EEG(:, i) = noise_level_2(:, i);
        case 3
            My_EEG(:, i) = noise_level_3(:, i);
    end
end

% Define the window size for scoring in seconds
Windows_size_scoring = 30;  % Duration of each scoring epoch

% Generate a random hypnogram: one stage code per 30-s epoch
% (replace this with your own scoring when using real data)
stage_values = [StageCodes.Wake, StageCodes.N1, StageCodes.N2, StageCodes.N3, StageCodes.REM];
num_epochs = floor(size(My_EEG, 2) / (SamplingRate * Windows_size_scoring));
Random_Scoring = stage_values(randi(numel(stage_values), 1, num_epochs));

%% Assign Channels
% Assign EEG channels to left, right, and midline groups
[leftChannels, rightChannels, midlineChannels] = assignChannels(My_Channel);

%% Perform Data Processing
% Re-reference to the mastoids (left - M2, right - M1, midline - (M1+M2)/2)
[EEG_reref, Channels] = Re_Referencing_Function_AE_toolbox(recording, My_EEG, My_Channel, SamplingRate, leftChannels, rightChannels, midlineChannels, dirPaths);

% Detect events on the re-referenced EEG data
SO_Detection_Function_AE_toolbox(recording, EEG_reref, Channels, Random_Scoring, SamplingRate, Windows_size_scoring, StageCodes, dirPaths);
Spindle_Detection_Function_AE_toolbox(recording, EEG_reref, Channels, Random_Scoring, SamplingRate, Windows_size_scoring, StageCodes, dirPaths);
Burst_Detection_Theta_Alpha_toolbox(recording, EEG_reref, Channels, Random_Scoring, SamplingRate, Windows_size_scoring, StageCodes, dirPaths);

disp('All steps finished. See README.md for a description of every output file.');
