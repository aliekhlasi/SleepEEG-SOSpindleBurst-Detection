function SO_Detection_Function_AE_toolbox(recording, EEG_reref, Channels, Scoring, SamplingRate, Windows_size_scoring, StageCodes, dirPaths)
    % SO_DETECTION_FUNCTION_AE_TOOLBOX - Detect slow oscillations (SO) in EEG data.
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
    % Outputs (saved in dirPaths{2}):
    %   <recording>_SO_events.csv  - One row per detected slow oscillation.
    %   <recording>_SO_summary.csv - Count and density per channel for N2, N3 and N2+N3.
    %   <recording>_SO.mat         - Both tables plus the detection parameters.

    fs = SamplingRate;
    epochMin = Windows_size_scoring / 60;  % Epoch length in minutes

    % SO detection parameters
    Params.Band_Hz           = [0.1, 4];  % Band-pass used before detection
    Params.MinNegAmp_uV      = 80;        % Minimum depth of the negative half-wave [uV]
    Params.MinPeakToPeak_uV  = 80;        % Minimum peak-to-peak amplitude [uV]
    Params.MinNegDuration_s  = 0.3;       % Minimum duration of the negative half-wave [s]
    Params.MaxNegDuration_s  = 1;         % Maximum duration of the negative half-wave [s]
    Params.MaxPosDuration_s  = 10;        % Maximum duration of the positive half-wave [s]

    % Collect one row per SO across channels
    evChannel = strings(0, 1); evStart = []; evTrough = []; evZero = []; evEnd = [];
    evNeg = []; evPos = [];

    for CH = 1:numel(Channels)
        signal = EEG_reref.data(CH, :);
        [ev, troughs, filtSig] = DetectSO_Filter_AE_toolbox(signal, fs, ...
            Params.MinNegAmp_uV, Params.MinPeakToPeak_uV, Params.MinNegDuration_s, ...
            Params.MaxNegDuration_s, Params.MaxPosDuration_s);
        if isempty(ev), continue; end

        n = size(ev, 1);
        negAmp = zeros(n, 1); posAmp = zeros(n, 1);
        for k = 1:n
            negAmp(k) = min(filtSig(ev(k, 1):ev(k, 2)));  % Negative peak of filtered signal
            posAmp(k) = max(filtSig(ev(k, 2):ev(k, 3)));  % Positive peak of filtered signal
        end

        evChannel = [evChannel; repmat(string(Channels{CH}), n, 1)]; %#ok<AGROW>
        evStart  = [evStart;  ev(:, 1)];   %#ok<AGROW>
        evZero   = [evZero;   ev(:, 2)];   %#ok<AGROW>
        evEnd    = [evEnd;    ev(:, 3)];   %#ok<AGROW>
        evTrough = [evTrough; troughs(:)]; %#ok<AGROW>
        evNeg    = [evNeg;    negAmp];     %#ok<AGROW>
        evPos    = [evPos;    posAmp];     %#ok<AGROW>
    end

    % Stage at the negative peak of each SO
    [stageCode, stageName] = stageAtSample(evTrough, Scoring, fs, Windows_size_scoring, StageCodes);

    toSec = @(s) (s - 1) / fs;  % Sample index -> seconds from recording start
    SO_events = table(evChannel, stageName, stageCode, toSec(evStart), toSec(evTrough), ...
        toSec(evZero), toSec(evEnd), (evEnd - evStart) / fs, evNeg, evPos, evPos - evNeg, ...
        'VariableNames', {'Channel', 'Stage', 'StageCode', 'Start_s', 'NegPeak_s', ...
        'ZeroCross_s', 'End_s', 'Duration_s', 'NegPeak_uV', 'PosPeak_uV', 'PeakToPeak_uV'});

    % Summary per channel for N2, N3 and N2+N3
    groups = {'N2', StageCodes.N2; 'N3', StageCodes.N3; 'N2+N3', [StageCodes.N2, StageCodes.N3]};
    sChannel = strings(0, 1); sStage = strings(0, 1); sCount = []; sMin = []; sDens = [];
    sNeg = []; sP2P = [];
    for CH = 1:numel(Channels)
        for g = 1:size(groups, 1)
            minutes = sum(ismember(Scoring, groups{g, 2})) * epochMin;
            sel = SO_events.Channel == string(Channels{CH}) & ismember(SO_events.StageCode, groups{g, 2});
            sChannel(end+1, 1) = string(Channels{CH}); %#ok<AGROW>
            sStage(end+1, 1)   = string(groups{g, 1}); %#ok<AGROW>
            sCount(end+1, 1)   = sum(sel);             %#ok<AGROW>
            sMin(end+1, 1)     = minutes;              %#ok<AGROW>
            sDens(end+1, 1)    = sum(sel) / minutes;   %#ok<AGROW>
            sNeg(end+1, 1)     = mean(SO_events.NegPeak_uV(sel));    %#ok<AGROW>
            sP2P(end+1, 1)     = mean(SO_events.PeakToPeak_uV(sel)); %#ok<AGROW>
        end
    end
    SO_summary = table(sChannel, sStage, sCount, sMin, sDens, sNeg, sP2P, ...
        'VariableNames', {'Channel', 'Stage', 'Count', 'StageDuration_min', ...
        'Density_per_min', 'MeanNegPeak_uV', 'MeanPeakToPeak_uV'});

    % Save
    outDir = dirPaths{2};
    writetable(SO_events,  fullfile(outDir, [recording '_SO_events.csv']));
    writetable(SO_summary, fullfile(outDir, [recording '_SO_summary.csv']));
    save(fullfile(outDir, [recording '_SO.mat']), 'SO_events', 'SO_summary', 'Params', ...
        'Channels', 'SamplingRate', 'StageCodes');

    fprintf('Slow oscillations: %d detected. Results saved in %s\n', height(SO_events), outDir);
end
