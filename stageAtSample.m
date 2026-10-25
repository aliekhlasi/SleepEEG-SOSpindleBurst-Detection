function [stageCode, stageName] = stageAtSample(samples, Scoring, SamplingRate, Windows_size_scoring, StageCodes)
    % STAGEATSAMPLE - Look up the sleep stage at given sample positions.
    %
    % Inputs:
    %   samples              - Sample indices (1 = first sample of the recording).
    %   Scoring              - Stage code of each scoring epoch (vector).
    %   SamplingRate         - Sampling rate [Hz].
    %   Windows_size_scoring - Epoch length [s].
    %   StageCodes           - Struct mapping stage names to codes,
    %                          e.g. StageCodes.N2 = 2.
    %
    % Outputs:
    %   stageCode - Stage code at each sample (NaN outside the scored part).
    %   stageName - Stage name at each sample (string, "Unscored" if unknown).

    samples = samples(:);
    epochLen = SamplingRate * Windows_size_scoring;
    epochIdx = floor((samples - 1) / epochLen) + 1;

    stageCode = nan(size(samples));
    valid = epochIdx >= 1 & epochIdx <= numel(Scoring);
    stageCode(valid) = Scoring(epochIdx(valid));

    stageName = repmat("Unscored", size(samples));
    names = fieldnames(StageCodes);
    for k = 1:numel(names)
        stageName(stageCode == StageCodes.(names{k})) = string(names{k});
    end
end
