function [rms_signal] = ComputeRootMeanSq(signal, wdwT, sampling_freq, smoothingWdw)
    % COMPUTEROOTMEANSQ - Moving root-mean-square (RMS) of a signal.
    %
    % Used by the spindle detector on the sigma-band (9-16 Hz) signal: the
    % RMS rises when a spindle is present.
    %
    % Inputs:
    %   signal        - Signal (vector) [uV].
    %   wdwT          - Length of the centered RMS window [s] (made odd in samples).
    %   sampling_freq - Sampling rate [Hz].
    %   smoothingWdw  - Length of an optional Gaussian smoothing window [s]
    %                   (0 = no smoothing).
    %
    % Output:
    %   rms_signal.raw    - Moving RMS, same length as the signal
    %                       (0 within half a window of the edges).
    %   rms_signal.smooth - Gaussian-smoothed RMS (empty if smoothingWdw = 0).
    %
    %   Part of SleepRhythms
    %   Maintainer: Ali Ekhlasi, Sleep and Cognition (SaC) Lab
    %   https://github.com/aliekhlasi/SleepRhythms

    %% Moving RMS over a centered window
    rms = zeros(size(signal));
    bins = round(wdwT * sampling_freq);   % Window length [samples]
    if mod(bins, 2) == 0                  % Use an odd length so the window is centered
        bins = bins + 1;
    end
    bL = (bins - 1) / 2;                  % Half window [samples]
    for idt = 1:length(rms)
        xt = (idt - bL):(idt + bL);
        if min(xt) >= 1 && max(xt) <= length(rms)   % Skip the edges
            xs = signal(xt);
            rms(idt) = sqrt(mean(xs .^ 2));
        end
    end
    rms_signal.raw = rms;

    %% Optional Gaussian smoothing
    if smoothingWdw > 0
        bins = round(smoothingWdw * sampling_freq);
        Wb = gausswin(bins);
        y = conv(rms, Wb, 'same');
    else
        y = [];
    end
    rms_signal.smooth = y;
end
