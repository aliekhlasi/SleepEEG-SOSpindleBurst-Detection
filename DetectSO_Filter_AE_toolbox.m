% %----------------------------------------------------------------------%
% function: DetectSO_Filter_AE_toolbox
%
%           Detects slow oscillations (SO) in one EEG channel.
%           1. The signal is band-passed between 0.1 and 4 Hz
%              (4th-order Butterworth high-pass and low-pass, zero-phase).
%           2. Zero crossings split it into candidate waves:
%              downward crossing -> upward crossing -> next downward crossing
%              (negative half-wave followed by positive half-wave).
%              The first and last 2 s of the signal are skipped.
%           3. A candidate is kept when its negative half-wave lasts
%              duration_min-duration_max s, its positive half-wave is shorter
%              than duration_whole s, its negative peak is deeper than
%              threshold_neg uV and its peak-to-peak amplitude exceeds
%              peak_to_peak uV.
%           With the toolbox defaults (0.3-1 s negative half-wave) this
%           selects waves of roughly 0.5-1.7 Hz. The sleep stage of each SO
%           is assigned afterwards by SO_Detection_Function_AE_toolbox.
%
%           Example usage:
%           [can_events, events_minima, EEG_Filtered_Signal] = ...
%           DetectSO_Filter_AE_toolbox(signal_raw, freq, threshold_neg, peak_to_peak, duration_min, duration_max, duration_whole)
%
% input:   - signal_raw          : Raw EEG signal [uV].
%          - freq                : Frequency of EEG acquisition [Hz].
%          - threshold_neg       : Minimum allowable depth of the negative half of the SO [uV].
%          - peak_to_peak        : Minimum allowable peak-to-peak distance of the SO [uV].
%          - duration_min        : Minimum allowable width of the negative half of the SO [sec].
%          - duration_max        : Maximum allowable width of the negative half of the SO [sec].
%          - duration_whole      : Maximum allowable width of the positive half of the SO [sec].
%
% output:   - can_events         : Matrix of detected events with start, middle, and end timepoints [samples].
%           - events_minima      : Array of timepoints for the minima of each detected slow oscillation [samples].
%           - EEG_Filtered_Signal : Filtered EEG signal used for detection.
%
% WARNING: Detection is performed on the filtered signal, and the returned
%          zero crossings may not correspond exactly to the raw signal.
%
%           written by Mohsen, modified by Daga, Dec 2016
%
%           Reference: Malerba P, Whitehurst LN, Simons SB, Mednick SC (2019). Sleep 42(1):zsy197.
%                      doi:10.1093/sleep/zsy197 (same criteria in Malerba et al. 2022, Sleep 45(8):zsac132)
%
%           Part of SleepEEG-SOSpindleBurst-Detection
%           Maintainer: Ali Ekhlasi, Sleep and Cognition (SaC) Lab
%           https://github.com/aliekhlasi/SleepEEG-SOSpindleBurst-Detection
% %----------------------------------------------------------------------%

function [can_events, events_minima, EEG_Filtered_Signal] = DetectSO_Filter_AE_toolbox(signal_raw, freq, threshold_neg, peak_to_peak, duration_min, duration_max, duration_whole)

    %% Filter the Raw EEG Signal
    % Design Butterworth filters for high-pass and low-pass
    [b_high, a_high] = butter(4, 0.1 / (freq / 2), 'high');  % High-pass filter
    [b_low, a_low] = butter(4, 4 / (freq / 2), 'low');      % Low-pass filter

    % Apply the filters to the raw signal using zero-phase filtering
    filtered_signal_temp = filtfilt(b_low, a_low, double(signal_raw));  % Low-pass filtering
    EEG_Filtered_Signal = filtfilt(b_high, a_high, filtered_signal_temp);  % High-pass filtering

    %% Initialize Outputs
    can_events = [];      % Initialize candidate events matrix
    events_minima = [];   % Initialize array for minima of detected SOs

    %% Detect Zero Crossings
    zero_cross = [];  % Initialize array for zero crossings

    % Loop through the filtered signal to find zero crossings
    for i = 2 * freq + 1:length(EEG_Filtered_Signal) - 2 * freq
        if EEG_Filtered_Signal(i) * EEG_Filtered_Signal(i + 1) < 0  % Check for zero crossing
            zero_cross = [zero_cross, i + 1];  % Store index of crossing
        end
    end

    %% Validate Zero Crossings
    if length(zero_cross) > 1
        % Ensure the first zero crossing is positive-to-negative
        if EEG_Filtered_Signal(zero_cross(1)) < EEG_Filtered_Signal(zero_cross(1) + 1)
            zero_cross(1) = [];  % Remove invalid crossing
        end

        % Limit zero crossings to valid events
        noc = floor(length(zero_cross) / 3);  % Number of complete cycles
        zero_cross = zero_cross(1:3 * noc);  % Trim to valid crossings

        % Extract the start, middle, and end of candidate events
        c1 = zero_cross(1:2:end)';  % Start of negative half-wave
        c2 = zero_cross(2:2:end)';  % End of negative half-wave
        c3 = zero_cross(3:2:end)';  % End of positive half-wave
        l = min([length(c1), length(c2), length(c3)]);  % Limit to the shortest array

        % Compile candidate events
        can_events = [c1(1:l), c2(1:l), c3(1:l)];

        % Auxiliary variable to calculate widths
        prop = [can_events(:, 2) - can_events(:, 1), can_events(:, 3) - can_events(:, 2)];
        
        % Filter candidate events based on width criteria
        can_events = can_events(prop(:, 1) > duration_min * freq & ...
                                prop(:, 1) < duration_max * freq & ...
                                prop(:, 2) < duration_whole * freq, :);
        
        clear prop

        %% Evaluate Candidate Events
        if ~isempty(can_events)
            [rr, ~] = size(can_events);  % Number of candidate events
            prop = zeros(rr, 2);  % Initialize property array

            % Analyze each candidate event
            for i = 1:rr
                prop(i, 1) = abs(min(EEG_Filtered_Signal(can_events(i, 1):can_events(i, 2))));  % Minimum voltage
                prop(i, 2) = abs(max(EEG_Filtered_Signal(can_events(i, 2):can_events(i, 3))));  % Maximum voltage
            end
            
            % Filter events based on voltage criteria
            can_events = can_events(prop(:, 1) > threshold_neg & (prop(:, 1) + prop(:, 2)) > peak_to_peak, :);
        end

        %% Extract Minimums of Detected Events
        if ~isempty(can_events)
            [rr, ~] = size(can_events);  % Update number of candidate events
            events_minima = zeros(rr, 1);  % Initialize minima array
            
            % Extract minimum voltage positions for each detected SO
            for i = 1:rr
                ev_mini = min(signal_raw(can_events(i, 1):can_events(i, 2)));  % Minimum value in the raw signal
                pos = find(signal_raw(can_events(i, 1):can_events(i, 2)) == ev_mini);  % Position of minimum
                events_minima(i) = can_events(i, 1) + pos(1) - 1;  % Store timepoint of minimum
            end
        end
    end
end
