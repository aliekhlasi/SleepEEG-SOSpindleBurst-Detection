function [starts, ends, nb_starts, nb_ends] = burst_detector2(filtered_Signal, Fs, ignore_cycle, std_tr, band, max_cycles_befor_after, min_cycles_tostart, min_cycles, power_damp_ratio_befor_after)
    % BURST_DETECTOR2 - Find oscillation bursts in a band-pass filtered signal.
    %
    % Method:
    %   1. The amplitude envelope and phase are taken from the Hilbert transform.
    %   2. Threshold = mean + std_tr * SD of the envelope, computed in a 30-s
    %      moving window (so it adapts to slow changes in background power).
    %   3. Periods where the envelope is above the threshold are burst cores.
    %      Cores with fewer than min_cycles_tostart cycles are dropped.
    %   4. Each core is extended cycle by cycle (up to max_cycles_befor_after
    %      cycles on each side) while the envelope stays above
    %      power_damp_ratio_befor_after * threshold. Up to ignore_cycle weaker
    %      cycles may be crossed while extending.
    %   5. Overlapping bursts are merged; bursts with fewer than min_cycles
    %      cycles are dropped.
    %   6. The periods between bursts are returned as non-burst periods.
    %
    % Inputs:
    %   filtered_Signal              - Band-pass filtered signal (row vector) [uV].
    %   Fs                           - Sampling rate [Hz].
    %   ignore_cycle                 - Weak cycles that may be crossed while extending.
    %   std_tr                       - Threshold in SDs above the mean envelope (e.g. 2).
    %   band                         - Frequency band [low high] in Hz.
    %   max_cycles_befor_after       - Maximum cycles added before/after each core.
    %   min_cycles_tostart           - Minimum cycles in a core.
    %   min_cycles                   - Minimum cycles in a final burst.
    %   power_damp_ratio_befor_after - Fraction of the threshold used while extending (e.g. 0.5).
    %
    % Outputs:
    %   starts, ends       - Burst start and end samples.
    %   nb_starts, nb_ends - Start and end samples of the non-burst periods.
    %
    %   The toolbox calls this from A_burst_detector_wrapper.m with:
    %   theta (4-8 Hz) and alpha (8-13 Hz), std_tr = 2, max_cycles_befor_after = 15,
    %   min_cycles_tostart = 0, ignore_cycle = floor(mean(band)/3),
    %   min_cycles = ceil(mean(band)/3), power_damp_ratio_befor_after = 0.5.
    %
    %   Reference: Shuster AE, Chen PC, Niknazar H, McDevitt EA, Lopour B, Mednick SC (2024).
    %              J Neurosci 44(24). doi:10.1523/JNEUROSCI.1517-23.2024
    %
    %   Part of SleepEEG-SOSpindleBurst-Detection
    %   Maintainer: Ali Ekhlasi, Sleep and Cognition (SaC) Lab
    %   https://github.com/aliekhlasi/SleepEEG-SOSpindleBurst-Detection

    nb_starts = [];
    nb_ends = [];

    %% 1. Envelope and phase
    analytic = hilbert(filtered_Signal);
    Pha = angle(analytic);     % Phase (0 = positive peak of the oscillation)
    Amp = abs(analytic);       % Amplitude envelope
    ignore_cycle = ignore_cycle + 1;

    %% 2. Adaptive threshold: mean + std_tr * SD in a 30-s moving window
    window_time = floor(30 * Fs);                  % Window length [samples]
    M = smooth(Amp, window_time);                  % Moving mean of the envelope
    S = (Amp - M') .^ 2;
    S = sqrt(smooth(S, window_time));              % Moving SD of the envelope
    TR = (M + std_tr .* S)';                       % Threshold (row vector)

    %% 3. Burst cores: envelope above the threshold
    Amp_tred = Amp > TR;
    starts = find(Amp_tred(2:end) - Amp_tred(1:end-1) == 1) + 1;  % Rising edges
    ends   = find(Amp_tred(1:end-1) - Amp_tred(2:end) == 1);      % Falling edges

    if isempty(starts) || isempty(ends)
        starts = []; ends = [];
        nb_starts = 1; nb_ends = length(Amp);      % Whole signal is non-burst
        return;
    end

    % Drop an end without a start (signal begins inside a burst) and a
    % start without an end (signal ends inside a burst)
    if starts(1) > ends(1)
        starts = starts(2:end);
    end
    n = min(length(starts), length(ends));
    starts = starts(1:n);
    ends = ends(1:n);

    % Keep cores with at least min_cycles_tostart cycles.
    % A cycle is counted from the phase: a wrap from +pi to -pi (product < -8)
    % and a zero crossing (product between -0.1 and 0).
    inds = zeros(1, length(starts));
    for i = 1:length(starts)
        temp_pha = Pha(starts(i):ends(i));
        M = temp_pha(1:end-1) .* temp_pha(2:end);
        N_pi_to_npi = sum(M < 0 & (M < -8));
        N_ZX = sum(M < 0 & (M > -.1));
        if min(N_pi_to_npi, N_ZX) >= min_cycles_tostart
            inds(i) = 1;
        end
    end
    starts = starts(logical(inds));
    ends = ends(logical(inds));

    % Threshold to use for each core when extending it (its mean threshold)
    new_TR = zeros(1, length(starts));
    for i = 1:length(starts)
        new_TR(i) = mean(TR(starts(i):ends(i)));
    end

    %% 4. Extend each core cycle by cycle
    cycleLen = floor(Fs / band(1));   % Longest cycle in the band [samples]
    for i = 1:length(starts)
        check_start = 0;  check_end = 0;    % Weak cycles crossed so far
        tmp_ZX1 = 0;      tmp_ZX2 = 0;      % Samples added through weak cycles

        for C = 1:max_cycles_befor_after
            % --- Extend the start backwards by one cycle ---
            if check_start < ignore_cycle && starts(i) > cycleLen
                new_start = starts(i) - cycleLen;
                M = Pha(new_start:starts(i)-1) .* Pha(new_start+1:starts(i));
                ZX = find(M <= 0 & (M > -.1));          % Zero crossings of the phase
                if ~isempty(ZX) && Amp(new_start + ZX(end)) > power_damp_ratio_befor_after * new_TR(i)
                    % Strong enough cycle: include it
                    starts(i) = new_start + ZX(end) - 1;
                    check_start = 0;
                    tmp_ZX1 = 0;
                elseif ~isempty(ZX)
                    % Weak cycle: cross it for now, remember how far we went
                    check_start = check_start + 1;
                    temp = starts(i);
                    starts(i) = new_start + ZX(end) - 1;
                    tmp_ZX1 = tmp_ZX1 + temp - starts(i);
                else
                    check_start = ignore_cycle;         % No crossing: stop extending
                end
            end

            % --- Extend the end forwards by one cycle ---
            if check_end < ignore_cycle && ends(i) + cycleLen < length(Amp)
                new_end = ends(i) + cycleLen;
                M = Pha(ends(i):new_end-1) .* Pha(ends(i)+1:new_end);
                ZX = find(M <= 0 & (M > -.1));
                if ~isempty(ZX) && Amp(ends(i) + ZX(end)) > power_damp_ratio_befor_after * new_TR(i)
                    ends(i) = ends(i) + ZX(end) + 1;
                    check_end = 0;
                    tmp_ZX2 = 0;
                elseif ~isempty(ZX)
                    check_end = check_end + 1;
                    ends(i) = ends(i) + ZX(end) + 1;
                    tmp_ZX2 = tmp_ZX2 + ZX(end) + 1;
                else
                    check_end = ignore_cycle;
                end
            end
        end

        % Undo trailing weak cycles that were not followed by a strong one
        if check_start ~= 0
            starts(i) = starts(i) + tmp_ZX1;
        end
        if check_end ~= 0
            ends(i) = ends(i) - tmp_ZX2;
        end
    end

    %% 5. Merge overlapping bursts, then require min_cycles cycles
    k = 1;
    while k < length(starts)
        if starts(k+1) < ends(k)          % Next burst starts before this one ends
            ends(k) = ends(k+1);          % Merge them
            starts(k+1) = [];
            ends(k+1) = [];
        else
            k = k + 1;
        end
    end

    inds = zeros(1, length(starts));
    for i = 1:length(starts)
        temp_pha = Pha(starts(i):ends(i));
        M = temp_pha(1:end-1) .* temp_pha(2:end);
        N_pi_to_npi = sum(M < 0 & (M < -8));
        N_ZX = sum(M < 0 & (M > -.1));
        if min(N_pi_to_npi, N_ZX) >= min_cycles
            inds(i) = 1;
        end
    end
    starts = starts(logical(inds));
    ends = ends(logical(inds));

    if isempty(starts)
        nb_starts = 1; nb_ends = length(Amp);      % Whole signal is non-burst
        return;
    end

    %% 6. Non-burst periods = the gaps between bursts
    if starts(1) == 1                     % Signal starts with a burst
        nb_ends = starts(2:end);
        if ends(end) == length(S)         % Signal also ends with a burst
            nb_starts = ends(1:end-1);
        else
            nb_starts = ends(1:end);
            nb_ends = [nb_ends length(S)];
        end
    else                                  % Signal starts with a non-burst period
        nb_starts = [1 ends];
        nb_ends = starts;
        if ends(end) == length(S)
            nb_starts = nb_starts(1:end-1);
        else
            nb_ends = [nb_ends length(S)];
        end
    end
end
