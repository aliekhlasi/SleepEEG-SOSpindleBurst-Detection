function Detected = A_burst_detector_wrapper(EEG_Burst, freq_band)
    % A_BURST_DETECTOR_WRAPPER - Detect oscillation bursts in one frequency band.
    %
    % Inputs:
    %   EEG_Burst - EEGLAB-style structure (fields data, srate, ...).
    %   freq_band - Frequency band [low, high] in Hz.
    %
    % Output:
    %   Detected  - Struct array, one element per channel, with fields:
    %       starts, ends      - Burst start/end sample indices (column vectors).
    %       nb_starts, nb_ends - Start/end sample indices of the non-burst
    %                           periods between bursts.
    %       filtered          - Band-pass filtered signal of the channel.
    %
    %   Reference: Shuster AE, Chen PC, Niknazar H, McDevitt EA, Lopour B, Mednick SC (2024).
    %              J Neurosci 44(24). doi:10.1523/JNEUROSCI.1517-23.2024
    %
    %   Part of SleepRhythms
    %   Maintainer: Ali Ekhlasi, Sleep and Cognition (SaC) Lab
    %   https://github.com/aliekhlasi/SleepRhythms

    % Band-pass filter all channels (EEGLAB)
    EEG = pop_eegfiltnew(EEG_Burst, 'locutoff', freq_band(1), 'hicutoff', freq_band(2), 'plotfreqz', 0);

    nCh = size(EEG.data, 1);
    Detected = struct('starts', cell(nCh, 1), 'ends', [], 'nb_starts', [], 'nb_ends', [], 'filtered', []);

    for ch = 1:nCh
        filtered_data = double(EEG.data(ch, :));

        % Amplitude-envelope threshold detector (mean + 2 SD in 30-s windows)
        [starts, ends, nb_starts, nb_ends] = burst_detector2( ...
            filtered_data, ...
            EEG.srate, ...
            floor(mean(freq_band) / 3), ...  % ignore_cycle
            2, ...                           % std_tr: threshold = mean + 2*SD
            freq_band, ...                   % band
            15, ...                          % max_cycles_befor_after
            0, ...                           % min_cycles_tostart
            ceil(mean(freq_band) / 3), ...   % min_cycles
            0.5);                            % power_damp_ratio_befor_after

        Detected(ch).starts    = starts(:);
        Detected(ch).ends      = ends(:);
        Detected(ch).nb_starts = nb_starts(:);
        Detected(ch).nb_ends   = nb_ends(:);
        Detected(ch).filtered  = filtered_data;
    end
end
