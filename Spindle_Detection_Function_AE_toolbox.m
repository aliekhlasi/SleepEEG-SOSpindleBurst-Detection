function Spindle_Detection_Function_AE_toolbox(recording, EEG_reref, Channels, Scoring, SamplingRate, Windows_size_scoring, StageCodes, dirPaths)
    % SPINDLE_DETECTION_FUNCTION_AE_TOOLBOX - Detect sleep spindles in EEG data.
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
    % Outputs (saved in dirPaths{3}):
    %   <recording>_Spindle_events.csv  - One row per detected spindle.
    %   <recording>_Spindle_summary.csv - Count and density per channel for N2, N3 and N2+N3.
    %   <recording>_Spindles.mat        - Both tables, spindle waveforms and parameters.
    %   Figures/<channel>/*.png         - Wavelet map of every candidate spindle.

    fs = SamplingRate;
    epochMin = Windows_size_scoring / 60;  % Epoch length in minutes

    % Epoch boundaries (used for the hypnogram passed to the detector)
    ends = (1:numel(Scoring))' * Windows_size_scoring * fs;

    % Spindle detection parameters
    Params.SigmaBand_Hz   = [9, 16];   % Spindle frequency band
    Params.PreFilter_Hz   = [0.3, 35]; % Band-pass applied before detection (EEGLAB)
    Params.MaxAmplitude_uV = 200;      % Spindles larger than this are rejected (set in SpdlFrequencyInTime.m)

    % Band-pass the data once for all channels
    EEG_Spindle_Fil = pop_eegfiltnew(EEG_reref, 'locutoff', Params.PreFilter_Hz(1), ...
        'hicutoff', Params.PreFilter_Hz(2), 'plotfreqz', 0);

    % Sigma-band filters
    [b1, a1] = butter(6, Params.SigmaBand_Hz(1) / (fs / 2), 'high');
    [b2, a2] = butter(6, Params.SigmaBand_Hz(2) / (fs / 2), 'low');

    % Hypnogram passed to the detector
    Hypno.t = ends / fs;   % End time of each epoch [s]
    Hypno.stg = Scoring;   % Stage code of each epoch

    Spindle_waveforms = cell(numel(Channels), 1);
    evChannel = strings(0, 1); evOn = []; evOff = []; evFreq = []; evPk = []; evRms = [];
    evLevel = []; evNpk = []; evAmp = [];

    for CH = 1:numel(Channels)
        chName = Channels{CH};
        raw = double(EEG_Spindle_Fil.data(CH, :));
        tx = (0:numel(raw) - 1) / fs;  % Time vector [s], first sample = 0 s

        % Sigma-band signal
        ch_sigma = filtfilt(b2, a2, filtfilt(b1, a1, raw));

        % Options: no pop-up plots; save the wavelet map of each candidate
        opt.showplots = 0;
        opt.figDir = fullfile(dirPaths{3}, 'Figures', chName);
        opt.figPrefix = [recording '_' chName];

        % Step 1: candidate events from peaks of the sigma RMS
        FoundPeaks = DetectRMSpeaks(ch_sigma, tx, fs, opt);

        % Step 2: keep candidates with a sigma-band "island" in the wavelet map
        Spdl0 = GetSpindlesFromRMSpeaks(FoundPeaks, raw, tx, fs, Hypno, opt);

        % Step 3: keep candidates with clear oscillation peaks and refine onset/offset
        W = struct('tx', {{}}, 'trace', {{}}, 'Onset_s', [], 'Offset_s', []);
        for spID = 1:Spdl0.n
            [IPIs, SPon, SPoff, keepIT] = SpdlFrequencyInTime(Spdl0.tx{spID}, ...
                Spdl0.trace{spID}, Spdl0.on(spID), Spdl0.off(spID), Spdl0.freq(spID), opt);
            if ~keepIT, continue; end

            seg = Spdl0.trace{spID}(Spdl0.tx{spID} >= SPon & Spdl0.tx{spID} <= SPoff);

            evChannel(end+1, 1) = string(chName);      %#ok<AGROW>
            evOn(end+1, 1)    = SPon;                  %#ok<AGROW>
            evOff(end+1, 1)   = SPoff;                 %#ok<AGROW>
            evFreq(end+1, 1)  = Spdl0.freq(spID);      %#ok<AGROW>
            evPk(end+1, 1)    = Spdl0.pktime(spID);    %#ok<AGROW>
            evRms(end+1, 1)   = Spdl0.RMStime(spID);   %#ok<AGROW>
            evLevel(end+1, 1) = Spdl0.pwLevel(spID);   %#ok<AGROW>
            evNpk(end+1, 1)   = numel(IPIs) + 1;       %#ok<AGROW>
            evAmp(end+1, 1)   = max(seg) - min(seg);   %#ok<AGROW>

            W.tx{end+1} = Spdl0.tx{spID};
            W.trace{end+1} = Spdl0.trace{spID};
            W.Onset_s(end+1) = SPon;
            W.Offset_s(end+1) = SPoff;
        end
        Spindle_waveforms{CH} = W;
        fprintf('%s: %d spindles kept.\n', chName, numel(W.Onset_s));
    end

    % Stage at the power peak of each spindle
    [stageCode, stageName] = stageAtSample(round(evPk * fs) + 1, Scoring, fs, Windows_size_scoring, StageCodes);

    Spindle_events = table(evChannel, stageName, stageCode, evOn, evOff, evOff - evOn, ...
        evFreq, evAmp, evNpk, evPk, evRms, evLevel, ...
        'VariableNames', {'Channel', 'Stage', 'StageCode', 'Onset_s', 'Offset_s', ...
        'Duration_s', 'Frequency_Hz', 'PeakToPeak_uV', 'NumPeaks', 'PowerPeak_s', ...
        'RMSPeak_s', 'PowerLevel'});

    % Summary per channel for N2, N3 and N2+N3
    groups = {'N2', StageCodes.N2; 'N3', StageCodes.N3; 'N2+N3', [StageCodes.N2, StageCodes.N3]};
    sChannel = strings(0, 1); sStage = strings(0, 1); sCount = []; sMin = []; sDens = [];
    sFreq = []; sDur = []; sAmp = [];
    for CH = 1:numel(Channels)
        for g = 1:size(groups, 1)
            minutes = sum(ismember(Scoring, groups{g, 2})) * epochMin;
            sel = Spindle_events.Channel == string(Channels{CH}) & ismember(Spindle_events.StageCode, groups{g, 2});
            sChannel(end+1, 1) = string(Channels{CH}); %#ok<AGROW>
            sStage(end+1, 1)   = string(groups{g, 1}); %#ok<AGROW>
            sCount(end+1, 1)   = sum(sel);             %#ok<AGROW>
            sMin(end+1, 1)     = minutes;              %#ok<AGROW>
            sDens(end+1, 1)    = sum(sel) / minutes;   %#ok<AGROW>
            sFreq(end+1, 1)    = mean(Spindle_events.Frequency_Hz(sel));  %#ok<AGROW>
            sDur(end+1, 1)     = mean(Spindle_events.Duration_s(sel));    %#ok<AGROW>
            sAmp(end+1, 1)     = mean(Spindle_events.PeakToPeak_uV(sel)); %#ok<AGROW>
        end
    end
    Spindle_summary = table(sChannel, sStage, sCount, sMin, sDens, sFreq, sDur, sAmp, ...
        'VariableNames', {'Channel', 'Stage', 'Count', 'StageDuration_min', ...
        'Density_per_min', 'MeanFrequency_Hz', 'MeanDuration_s', 'MeanPeakToPeak_uV'});

    % Save
    outDir = dirPaths{3};
    writetable(Spindle_events,  fullfile(outDir, [recording '_Spindle_events.csv']));
    writetable(Spindle_summary, fullfile(outDir, [recording '_Spindle_summary.csv']));
    save(fullfile(outDir, [recording '_Spindles.mat']), 'Spindle_events', 'Spindle_summary', ...
        'Spindle_waveforms', 'Params', 'Channels', 'SamplingRate', 'StageCodes');

    fprintf('Spindles: %d detected. Results saved in %s\n', height(Spindle_events), outDir);
end
