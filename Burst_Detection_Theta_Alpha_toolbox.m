function Burst_Detection_Theta_Alpha_toolbox(recording, EEG_reref, Channels, Scoring, SamplingRate, Windows_size_scoring, StageCodes, dirPaths)
    % BURST_DETECTION_THETA_ALPHA_TOOLBOX - Detect theta and alpha bursts and
    % summarize the bursts that occur during REM sleep.
    %
    % What:   Bursts of oscillation where the amplitude envelope rises above
    %         mean + 2 SD (30-s moving window), see burst_detector2.m:
    %           theta bursts: 4-8 Hz,  0.5-3 s long
    %           alpha bursts: 8-13 Hz, 0.5-2 s long
    % Where:  Detected in the whole recording (all listed in Burst_events with
    %         their stage). The summary counts only bursts that start in REM
    %         and have a valid duration, per night quarter, half and whole night.
    %
    % Inputs:
    %   recording            - Name of the current recording (string).
    %   EEG_reref            - Structure containing re-referenced EEG data.
    %   Channels             - Cell array of channel names.
    %   Scoring              - Stage code of each scoring epoch.
    %   SamplingRate         - Sampling rate of the EEG data [Hz].
    %   Windows_size_scoring - Length of a scoring epoch [s].
    %   StageCodes           - Struct with the code of each stage (Wake, N1, N2, N3, REM).
    %   dirPaths             - Result folders from createResultDirectories.
    %
    % Outputs (saved in dirPaths{4}):
    %   <recording>_Burst_events.csv  - Every detected burst (all stages), with flags
    %                                   showing which ones are counted in the summary.
    %   <recording>_Burst_summary.csv - REM bursts per band, channel and part of the night.
    %   <recording>_Bursts.mat        - Both tables, the non-burst periods and parameters.
    %
    %   Reference: Shuster AE, Chen PC, Niknazar H, McDevitt EA, Lopour B, Mednick SC (2024).
    %              J Neurosci 44(24). doi:10.1523/JNEUROSCI.1517-23.2024
    %
    %   Part of SleepRhythms
    %   Developed at the Sleep and Cognition (SaC) Lab, UC Irvine. Maintainer: Ali Ekhlasi
    %   https://github.com/aliekhlasi/SleepRhythms

    fs = SamplingRate;
    epochLen = Windows_size_scoring * fs;      % Epoch length [samples]
    epochMin = Windows_size_scoring / 60;      % Epoch length [min]
    nEpochs = numel(Scoring);
    nightSamples = nEpochs * epochLen;

    % Band definitions
    Params.Bands = struct( ...
        'Name',          {'theta', 'alpha'}, ...
        'Range_Hz',      {[4, 8],  [8, 13]}, ...
        'MaxDuration_s', {3,       2});
    Params.MinDuration_s = 0.5;   % Bursts must be longer than this
    Params.SummaryStage = 'REM';  % Stage used for the summary

    % Night quarters: the scored night is split into 4 equal parts
    quarterOf = @(s) min(4, floor((s - 1) / (nightSamples / 4)) + 1);
    epochQuarter = quarterOf((0:nEpochs - 1)' * epochLen + 1);
    isSummaryStage = Scoring(:) == StageCodes.(Params.SummaryStage);

    Periods = {'Q1', 1; 'Q2', 2; 'Q3', 3; 'Q4', 4; ...
               'FirstHalf', [1 2]; 'SecondHalf', [3 4]; 'WholeNight', 1:4};

    Burst_events = table();
    NonBurst_segments = table();
    Burst_summary = table();

    for b = 1:numel(Params.Bands)
        band = Params.Bands(b);
        fprintf('Detecting %s bursts (%g-%g Hz)...\n', band.Name, band.Range_Hz);
        Detected = A_burst_detector_wrapper(EEG_reref, band.Range_Hz);

        for CH = 1:numel(Channels)
            D = Detected(CH);
            chName = string(Channels{CH});

            % --- Bursts ---
            ev = describeSegments(D.starts, D.ends, D.filtered, fs, Scoring, ...
                Windows_size_scoring, StageCodes, quarterOf);
            ev.InREM = ev.StageCode == StageCodes.(Params.SummaryStage);
            ev.DurationOK = ev.Duration_s > Params.MinDuration_s & ev.Duration_s < band.MaxDuration_s;
            ev.Included = ev.InREM & ev.DurationOK;
            ev = [table(repmat(string(band.Name), height(ev), 1), repmat(chName, height(ev), 1), ...
                'VariableNames', {'Band', 'Channel'}), ev]; %#ok<AGROW>
            Burst_events = [Burst_events; ev]; %#ok<AGROW>

            % --- Non-burst periods ---
            nb = describeSegments(D.nb_starts, D.nb_ends, D.filtered, fs, Scoring, ...
                Windows_size_scoring, StageCodes, quarterOf);
            nb.InREM = nb.StageCode == StageCodes.(Params.SummaryStage);
            nb = [table(repmat(string(band.Name), height(nb), 1), repmat(chName, height(nb), 1), ...
                'VariableNames', {'Band', 'Channel'}), nb]; %#ok<AGROW>
            NonBurst_segments = [NonBurst_segments; nb]; %#ok<AGROW>

            % --- Summary per part of the night ---
            for p = 1:size(Periods, 1)
                q = Periods{p, 2};
                remMin = sum(isSummaryStage & ismember(epochQuarter, q)) * epochMin;
                selB = ev.Included & ismember(ev.NightQuarter, q);
                selN = nb.InREM & ismember(nb.NightQuarter, q);
                row = table(string(band.Name), chName, string(Periods{p, 1}), remMin, ...
                    sum(selB), sum(selB) / remMin, mean(ev.Duration_s(selB)), ...
                    mean(ev.MeanPower_uV2(selB)), mean(nb.MeanPower_uV2(selN)), ...
                    'VariableNames', {'Band', 'Channel', 'Period', 'REM_min', 'Count', ...
                    'Density_per_min', 'MeanDuration_s', 'MeanPower_uV2', 'NonBurst_MeanPower_uV2'});
                Burst_summary = [Burst_summary; row]; %#ok<AGROW>
            end
        end
    end

    % Save
    outDir = dirPaths{4};
    writetable(Burst_events,  fullfile(outDir, [recording '_Burst_events.csv']));
    writetable(Burst_summary, fullfile(outDir, [recording '_Burst_summary.csv']));
    save(fullfile(outDir, [recording '_Bursts.mat']), 'Burst_events', 'Burst_summary', ...
        'NonBurst_segments', 'Params', 'Channels', 'SamplingRate', 'StageCodes');

    fprintf('Bursts: %d detected, %d in REM with valid duration. Results saved in %s\n', ...
        height(Burst_events), sum(Burst_events.Included), outDir);
end

function T = describeSegments(starts, ends, x, fs, Scoring, Windows_size_scoring, StageCodes, quarterOf)
    % Timing, power, stage and night quarter of each segment [start, end] (samples).
    starts = starts(:); ends = ends(:);
    n = numel(starts);
    power = zeros(n, 1);
    for k = 1:n
        power(k) = mean(x(starts(k):ends(k)).^2);  % Mean squared amplitude [uV^2]
    end
    [stageCode, stageName] = stageAtSample(starts, Scoring, fs, Windows_size_scoring, StageCodes);
    T = table((starts - 1) / fs, (ends - 1) / fs, (ends - starts) / fs, power, ...
        stageName, stageCode, quarterOf(starts), ...
        'VariableNames', {'Start_s', 'End_s', 'Duration_s', 'MeanPower_uV2', ...
        'Stage', 'StageCode', 'NightQuarter'});
end
