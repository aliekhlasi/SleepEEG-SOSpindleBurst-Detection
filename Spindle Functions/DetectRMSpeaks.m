function [FoundPeaks] = DetectRMSpeaks(filtchannel, tx, freq, opt)
    % DETECTRMSPEAKS - Spindle step 1: find spindle candidates.
    %
    % The moving RMS (0.1-s window) of the sigma-band (9-16 Hz) signal is
    % z-scored in overlapping 30-s chunks (1-s overlap). Peaks of the z-scored
    % RMS above 3.5 (prominence >= 0.5) are candidates. Peaks that are not
    % separated by a dip below z = 0 belong to the same event, and only the
    % highest one is kept. Candidates are searched in all sleep stages.
    %
    % Inputs:
    %   filtchannel - Sigma-band (9-16 Hz) filtered EEG signal [uV].
    %   tx          - Time vector associated with the filtered signal [seconds].
    %   freq        - Sampling frequency of the EEG signal [Hz].
    %   opt         - Options structure containing plotting preferences.
    %
    % Outputs:
    %   FoundPeaks  - Structure containing details of detected peaks:
    %                 - Zscore: z-scores of detected peaks.
    %                 - Time: time points of detected peaks.
    %                 - tID: indices of detected peaks.
    %
    %   Part of SleepEEG-SOSpindleBurst-Detection
    %   Maintainer: Ali Ekhlasi, Sleep and Cognition (SaC) Lab
    %   https://github.com/aliekhlasi/SleepEEG-SOSpindleBurst-Detection

    %% Initialize Parameters
    PkThreshold = 3.5;  % Minimum z-score height for peaks of RMS
    Trange = [-1, 1];    % Time range around each peak for analysis [seconds]
    
    % Display message indicating RMS computation
    disp('Computing the RMS of the filtered signal...');
    
    % Define window sizes for RMS computation
    wdwT = 0.1;  % RMS window length in seconds
    smWdw = 0.1;  % Smoothing window in seconds

    tic  % Start timer for RMS computation
    [RMSsigma] = ComputeRootMeanSq(filtchannel, wdwT, freq, smWdw);  % Compute RMS
    toc  % Stop timer

    %% Analyze Signal in Chunks
    chunkL = 30 * freq;  % Length of each chunk in samples (30 seconds)
    Nchnk = ceil(length(tx) / chunkL);  % Number of chunks

    % Initialize arrays for storing detected peaks
    PkZ = [];  % Array to hold z-scores of peaks
    PkT = [];  % Array to hold time points of peaks
    PkTx = []; % Array to hold indices of peaks

    % Loop through each chunk of the signal
    for idch = 1:Nchnk
        % Determine the left and right indices for the current chunk
        if idch > 1
            Klft = Klft + chunkL - freq;  % Update left index for sliding window
        else
            Klft = 1;  % Initialize left index for the first chunk
        end
        Krght = Klft + chunkL;  % Calculate right index
        Krght = min(Krght, length(tx));  % Ensure right index does not exceed length

        % Get RMS values for the current chunk
        Xrms = RMSsigma.raw(Klft:Krght);
        
        % Plot the filtered signal and RMS if specified
        if opt.showplots
            figure(1);
            subplot(211);
            plot(tx(Klft:Krght), filtchannel(Klft:Krght), '-k');  % Plot filtered signal
            hold on;
            plot(tx(Klft:Krght), Xrms, '-r');  % Plot RMS
            hold off;
            title('Filtered Signal and RMS');  % Title for the plot
        end
        
        % Calculate z-scores of the RMS
        Zrms = zscore(Xrms);  % Normalize RMS values
        Trms = tx(Klft:Krght);  % Time vector for the current chunk

        % Detect peaks in the z-scored RMS
        [pkall, kpall] = findpeaks(Zrms, 'MinPeakHeight', PkThreshold, 'MinPeakProminence', 0.5);  % Find peaks
        [vall, kvall] = findpeaks(-Zrms, 'MinPeakHeight', 0);  % Find valleys

        % Plot z-scored RMS and detected peaks
        if opt.showplots
            figure(1);
            subplot(212);
            plot(Trms, Zrms, '-k');  % Plot z-scored RMS
            hold on;
            plot(Trms(kpall), pkall, 'gd');  % Plot detected peaks
            plot(Trms(kvall), vall, 'bo');  % Plot detected valleys
            plot(Trms, PkThreshold * ones(size(Trms)), ':k');  % Plot threshold line
            title('Detected Peaks and Valleys');  % Title for the plot
            hold off;
        end

        %% Process Detected Peaks
        % Each detected peak is a candidate spindle
        if ~isempty(kpall)
            kvall = kvall(kvall > min(kpall));  % Exclude valleys before the first peak

            % Identify separate spindle events based on peaks and valleys
            whichEvt = ones(size(kpall));  % Initialize event identifier
            for en = 2:length(kpall)
                % Check for valleys between peaks to distinguish events
                x0 = kvall(kvall > kpall(en-1));
                x1 = x0(x0 < kpall(en));
                if ~isempty(x1)
                    whichEvt(en) = whichEvt(en-1) + 1;  % Increment event counter
                else
                    whichEvt(en) = whichEvt(en-1);
                end
            end

            % Store peaks based on event classification
            if max(whichEvt) == length(whichEvt)  % All peaks are separate events
                PkZ = [PkZ, pkall];  % Store z-scores of peaks
                PkT = [PkT, Trms(kpall)];  % Store time points of peaks
                PkTx = [PkTx, Klft + kpall - 1];  % Store indices of peaks
            else
                % Consolidate peaks into events
                for en = 1:max(whichEvt)
                    x0 = find(whichEvt == en);  % Find peaks belonging to the same event
                    if length(x0) == 1
                        PkZ(end + 1) = pkall(x0);
                        PkT(end + 1) = Trms(kpall(x0));
                        PkTx(end + 1) = Klft + kpall(x0) - 1;
                    else  % Keep the highest peak
                        pkH = pkall(x0);
                        [~, m0] = max(pkH);
                        PkZ(end + 1) = pkall(x0(m0));
                        PkT(end + 1) = Trms(kpall(x0(m0)));
                        PkTx(end + 1) = Klft + kpall(x0(m0)) - 1;
                    end
                end
            end
        end
    end

    %% Store Detected Peaks in Structure
    FoundPeaks.Zscore = PkZ;  % Store z-scores of detected peaks
    FoundPeaks.Time = PkT;    % Store time points of detected peaks
    FoundPeaks.tID = PkTx;    % Store indices of detected peaks

    disp(['Detected ', num2str(length(PkZ)), ' peaks.']);  % Inform user of the number of detected peaks

    return;  % End of function
end
