function [My_EEG, Scoring, Truth] = simulateSleepEEG(My_Channel, SamplingRate, Windows_size_scoring, StageCodes)
    % SIMULATESLEEPEEG - Create 30 minutes of realistic-looking sleep EEG for the demo.
    %
    % The simulated recording contains:
    %   - a fixed hypnogram (Wake -> N1 -> N2 -> N3 -> N2 -> REM -> N2 -> N3 -> N2 -> REM),
    %   - 1/f ("pink") background activity of about 20 uV on every channel,
    %   - known events added at random times on all scalp channels:
    %       slow oscillations (0.7-1.1 Hz)  in N2 and N3,
    %       sleep spindles   (11-15 Hz)     in N2 and N3,
    %       theta bursts     (5-7 Hz)       in REM,
    %       alpha bursts     (9-11 Hz)      in REM and Wake.
    %   The mastoid channels (M1, M2) contain only background activity.
    %
    % Inputs:
    %   My_Channel           - Channel names (must include M1 and M2).
    %   SamplingRate         - Sampling rate [Hz].
    %   Windows_size_scoring - Scoring epoch length [s].
    %   StageCodes           - Struct with the code of each stage.
    %
    % Outputs:
    %   My_EEG  - Simulated EEG, channels x samples [uV].
    %   Scoring - Stage code of each epoch (the hypnogram).
    %   Truth   - Table with one row per injected event (the "ground truth"
    %             that checkDemoDetections compares the results with).
    %
    %   Part of SleepRhythms
    %   Maintainer: Ali Ekhlasi, Sleep and Cognition (SaC) Lab
    %   https://github.com/aliekhlasi/SleepRhythms

    fs = SamplingRate;
    epochLen = Windows_size_scoring * fs;

    %% Hypnogram (60 epochs of 30 s = 30 minutes)
    S = StageCodes;
    blocks = { S.Wake, 2; S.N1, 2; S.N2, 8; S.N3, 10; S.N2, 6; S.REM, 8; ...
               S.N2, 6; S.N3, 6; S.N2, 4; S.REM, 8 };
    Scoring = [];
    for b = 1:size(blocks, 1)
        Scoring = [Scoring, repmat(blocks{b, 1}, 1, blocks{b, 2})]; %#ok<AGROW>
    end
    nEpochs = numel(Scoring);
    nSamples = nEpochs * epochLen;

    %% Background: 1/f noise, ~20 uV on scalp channels, ~8 uV on mastoids
    nCh = numel(My_Channel);
    isMastoid = strcmpi(My_Channel, 'M1') | strcmpi(My_Channel, 'M2');
    My_EEG = zeros(nCh, nSamples);
    for ch = 1:nCh
        x = pinkNoise(nSamples, fs);
        if isMastoid(ch), target = 8; else, target = 20; end
        My_EEG(ch, :) = x / std(x) * target;
    end

    %% Events: type, stages, rate (per minute), frequency range, duration range, amplitude range
    %          (amplitude = peak of the oscillation in uV)
    ev = struct( ...
        'Type',      {'SlowOscillation', 'Spindle',          'ThetaBurst', 'AlphaBurst'}, ...
        'Stages',    {[S.N2 S.N3],       [S.N2 S.N3],        S.REM,        [S.REM S.Wake]}, ...
        'Rate',      {[3 8],             [5 2],              4,            [3 3]}, ...
        'Freq',      {[0.7 1.1],         [11 15],            [5 7],        [9 11]}, ...
        'Dur',       {[NaN NaN],         [0.6 1.5],          [1 2.5],      [0.8 1.8]}, ...
        'Amp',       {[90 130],          [25 35],            [30 40],      [25 35]});

    taken = false(1, nSamples);   % Keeps events apart (no overlap)
    gap = round(1.0 * fs);        % Minimum gap between events [samples]
    rows = {};

    for e = 1:numel(ev)
        for k = 1:nEpochs
            sIdx = find(ev(e).Stages == Scoring(k), 1);
            if isempty(sIdx), continue; end
            nEv = poissrndSimple(ev(e).Rate(min(sIdx, numel(ev(e).Rate))) * Windows_size_scoring / 60);
            for n = 1:nEv
                f = uniform(ev(e).Freq);
                A = uniform(ev(e).Amp);
                if strcmp(ev(e).Type, 'SlowOscillation')
                    dur = 1 / f;                      % One full cycle
                else
                    dur = uniform(ev(e).Dur);
                end
                len = round(dur * fs);
                % Try a few random positions inside the epoch
                for attempt = 1:20
                    s0 = (k - 1) * epochLen + randi(epochLen - len - 2 * gap) + gap;
                    span = max(1, s0 - gap):min(nSamples, s0 + len + gap);
                    if ~any(taken(span)), break; end
                    s0 = [];
                end
                if isempty(s0), continue; end
                taken(span) = true;

                t = (0:len - 1) / fs;
                if strcmp(ev(e).Type, 'SlowOscillation')
                    wave = -A * sin(2 * pi * f * t);  % Negative half-wave first
                    center = s0 + round(fs / (4 * f));  % Time of the negative peak
                else
                    env = sin(pi * t / dur) .^ 2;     % Smooth waxing/waning envelope
                    wave = A * env .* sin(2 * pi * f * t + 2 * pi * rand);
                    center = s0 + round(len / 2);
                end

                % Add to every scalp channel with a slightly different gain
                for ch = find(~isMastoid)
                    gain = 0.85 + 0.3 * rand;
                    My_EEG(ch, s0:s0 + len - 1) = My_EEG(ch, s0:s0 + len - 1) + gain * wave;
                end

                stageName = string(fieldnames(S));
                stageName = stageName(cellfun(@(nm) S.(nm) == Scoring(k), fieldnames(S)));
                rows(end+1, :) = {string(ev(e).Type), stageName(1), (s0 - 1) / fs, ...
                    (s0 + len - 2) / fs, (center - 1) / fs, f, A}; %#ok<AGROW>
            end
        end
    end

    Truth = cell2table(rows, 'VariableNames', {'Type', 'Stage', 'Start_s', 'End_s', ...
        'Center_s', 'Frequency_Hz', 'Amplitude_uV'});
    Truth = sortrows(Truth, 'Start_s');
end

function x = pinkNoise(n, fs)
    % 1/f noise (power ~ 1/f above 0.5 Hz), made in the frequency domain.
    X = fft(randn(1, n));
    f = (0:n - 1) * fs / n;
    f = min(f, fs - f);               % Symmetric frequency axis
    X = X ./ sqrt(max(f, 0.5));
    x = real(ifft(X));
end

function v = uniform(r)
    v = r(1) + (r(2) - r(1)) * rand;
end

function k = poissrndSimple(lambda)
    % Poisson random number without the Statistics Toolbox.
    L = exp(-lambda); k = 0; p = rand;
    while p > L
        k = k + 1; p = p * rand;
    end
end
