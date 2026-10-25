% MAIN_TOOLBOX - Run the full SleepEEG-SOSpindleBurst-Detection pipeline.
%
% Steps: re-referencing -> slow oscillations (0.1-4 Hz; N2, N3) ->
% spindles (9-16 Hz; N2, N3) -> theta (4-8 Hz) and alpha (8-13 Hz)
% bursts (REM). Runs a demo with simulated data; see README.md for
% how to use your own recording and for every output file.
%
% Part of SleepEEG-SOSpindleBurst-Detection
% Maintainer: Ali Ekhlasi, Sleep and Cognition (SaC) Lab
% https://github.com/aliekhlasi/SleepEEG-SOSpindleBurst-Detection

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
% ---------------------------------------------------------------------
% DEMO: 30 minutes of simulated sleep EEG with known events.
% To analyze your own recording, replace this section with your data:
%   recording            - name used as the prefix of every output file
%   My_Channel           - channel names (must include M1 and M2)
%   My_EEG               - EEG matrix, channels x samples, in uV
%   SamplingRate         - sampling rate in Hz
%   Windows_size_scoring - scoring epoch length in seconds
%   Scoring              - hypnogram: one stage code per epoch
% ---------------------------------------------------------------------
recording = 'Sample';
My_Channel = {'Fp1', 'Fp2', 'FPz', 'Fz', 'M1', 'M2'};
SamplingRate = 250;           % Hz
Windows_size_scoring = 30;    % s
[My_EEG, Scoring, Truth] = simulateSleepEEG(My_Channel, SamplingRate, Windows_size_scoring, StageCodes);

%% Assign Channels
% Choose left, right and midline scalp channels (M1/M2 are found automatically)
[leftChannels, rightChannels, midlineChannels] = assignChannels(My_Channel);

%% Perform Data Processing
% Re-reference to the mastoids (left - M2, right - M1, midline - (M1+M2)/2)
[EEG_reref, Channels] = Re_Referencing_Function_AE_toolbox(recording, My_EEG, My_Channel, SamplingRate, leftChannels, rightChannels, midlineChannels, dirPaths);

% Detect events on the re-referenced EEG data
SO_Detection_Function_AE_toolbox(recording, EEG_reref, Channels, Scoring, SamplingRate, Windows_size_scoring, StageCodes, dirPaths);
Spindle_Detection_Function_AE_toolbox(recording, EEG_reref, Channels, Scoring, SamplingRate, Windows_size_scoring, StageCodes, dirPaths);
Burst_Detection_Theta_Alpha_toolbox(recording, EEG_reref, Channels, Scoring, SamplingRate, Windows_size_scoring, StageCodes, dirPaths);

%% Demo only: compare the detections with the injected events
% (remove this section when analyzing your own data)
writetable(Truth, fullfile(selectedFolder, [recording '_SimulatedEvents.csv']));
checkDemoDetections(recording, Truth, selectedFolder);

disp('All steps finished. See README.md for a description of every output file.');
