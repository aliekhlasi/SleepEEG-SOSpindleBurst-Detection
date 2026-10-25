function [IPIs, SPon, SPoff, keepIT] = SpdlFrequencyInTime(tx_sp, ch_sp, SPstart, SPend, SPf, opt)
    % SPDLFREQUENCYINTIME - Spindle step 3: waveform check and onset/offset refinement.
    %
    % Within the spindle window, oscillation peaks are found on the z-scored
    % EEG (minimum prominence 0.3). The spindle is rejected if no peaks are
    % found or if the EEG exceeds 200 uV (artifact). Otherwise onset/offset
    % are moved to 0.09 s before the first / after the last peak when the
    % window has more than 0.1 s of extra signal at either end.
    %
    % Inputs:
    %   tx_sp     - Time vector associated with the spindle event [seconds].
    %   ch_sp     - Channel signal corresponding to the time vector [uV].
    %   SPstart   - Start time of the spindle event [seconds].
    %   SPend     - End time of the spindle event [seconds].
    %   SPf       - Frequency of the spindle (used for plotting/title).
    %   opt       - Options structure containing plotting preferences.
    %
    % Outputs:
    %   IPIs      - Inter-Peak Intervals of the detected peaks [seconds].
    %   SPon      - Adjusted onset time of the spindle event [seconds].
    %   SPoff     - Adjusted offset time of the spindle event [seconds].
    %   keepIT    - Flag indicating whether the spindle is valid (1) or not (0).
    %
    %   Reference: Malerba P, Whitehurst L, Mednick SC (2022). The space-time profiles of
    %              sleep spindles... Sleep 45(8):zsac132. doi:10.1093/sleep/zsac132
    %
    %   Part of SleepEEG-SOSpindleBurst-Detection
    %   Maintainer: Ali Ekhlasi, Sleep and Cognition (SaC) Lab
    %   https://github.com/aliekhlasi/SleepEEG-SOSpindleBurst-Detection

    % Extract time and channel data within the spindle event window
    tx = tx_sp(and(tx_sp >= SPstart, tx_sp <= SPend));  % Time vector within the spindle window
    cx = ch_sp(and(tx_sp >= SPstart, tx_sp <= SPend));  % Channel signal within the spindle window

    % Detect peaks in the z-scored channel signal
    [pkv, pkid] = findpeaks(zscore(cx), 'MinPeakProminence', 0.3);  % Find peaks with minimum prominence

    % Check for peak detection validity
    if isempty(pkv) || max(abs(cx)) > 200  % If no peaks detected or signal is too large
        keepIT = 0;  % Mark as invalid spindle
        IPIs = [];  % No inter-peak intervals
        SPon = [];  % No onset time
        SPoff = []; % No offset time
        if isempty(pkv)
            fprintf('Spindle candidate at %.2f s rejected: no clear oscillation peaks.\n', SPstart);
        else
            fprintf('Spindle candidate at %.2f s rejected: amplitude %.0f uV > 200 uV (artifact).\n', SPstart, max(abs(cx)));
        end
    else
        keepIT = 1;  % Valid spindle detected
        pkt = tx(pkid);  % Time points of detected peaks

        % Adjust the onset time of the spindle
        if pkt(1) - tx(1) > 0.1  % If there is a long gap before the spindle starts
            SPon = pkt(1) - 0.09;  % Set onset to slightly before the first peak
        else
            SPon = SPstart;  % Use the original start time
        end

        % Adjust the offset time of the spindle
        if tx(end) - pkt(end) > 0.1  % If there is a long gap after the spindle ends
            SPoff = pkt(end) + 0.09;  % Set offset to slightly after the last peak
        else
            SPoff = SPend;  % Use the original end time
        end

        % Calculate inter-peak intervals
        IPIs = diff(pkt);  % Time differences between peaks
        ipi_t = [0 diff(pkt)];  % Include zero for the first peak's interval

        % Plotting if enabled in options
        if opt.showplots
            figure(2);
            
            % Plot channel signal with spindle start and end
            subplot(3, 1, 1);
            plot(tx_sp, ch_sp); hold on;
            plot([SPstart SPend], zeros(1, 2), 'bd');  % Mark spindle start and end
            title(['Spindle Frequency: ', num2str(SPf)]);  % Title with spindle frequency
            xlim([min(tx_sp) max(tx_sp)]);
            hold off;

            % Plot inter-peak intervals
            subplot(3, 1, 2);
            plot(pkt, ipi_t, '-x'); hold on;
            plot(pkt, [ones(size(pkt)) * 1 / 18; ones(size(pkt)) * 1 / 8], 'k:');  % Reference lines
            xlim([min(tx_sp) max(tx_sp)]);
            hold off;

            % Plot z-scored channel signal with peaks marked
            subplot(3, 1, 3);
            plot(tx, zscore(cx)); hold on;
            plot(pkt, pkv, 'rx', [SPon SPoff], zeros(1, 2), 'bd');  % Mark peaks and spindle window
            xlim([min(tx_sp) max(tx_sp)]);
            hold off;
        end
    end

    return;  % End of function
end
