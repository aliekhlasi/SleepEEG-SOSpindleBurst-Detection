function Spdl = GetSpindlesFromRMSpeaks(FoundPeaks, channel, tx, freq, Hypno, opt)
    % GETSPINDLESFROMRMSPEAKS - Spindle step 2: wavelet check of each candidate.
    %
    % For every candidate from DetectRMSpeaks, a Morlet wavelet transform is
    % computed over +/- 1 s (after a 3 Hz high-pass). Contour lines of equal
    % wavelet power are traced. A candidate is a spindle when there is a
    % closed power "island" (contour loop) that is
    %   - centered between 9 and 16 Hz (sigma band),
    %   - centered within 0.5 s of the candidate time,
    %   - at least 4 of the 20 power levels high.
    % Onset/offset are taken from the loop at half that height.
    % Spindles less than 0.1 s apart are counted once.
    %
    % Inputs:
    %   FoundPeaks - Candidates from DetectRMSpeaks (fields Time, tID).
    %   channel    - EEG signal of the channel (0.3-35 Hz filtered) [uV].
    %   tx         - Time vector of the signal [s].
    %   freq       - Sampling rate [Hz].
    %   Hypno      - Hypnogram: Hypno.t (epoch end times [s]), Hypno.stg (stage codes).
    %   opt        - Options: showplots (0/1); figDir and figPrefix to save the
    %                wavelet map of every candidate as a PNG (no pop-ups).
    %
    % Output:
    %   Spdl - Struct with one entry per spindle in each field:
    %          RMStime (candidate time), tx/trace (2-s EEG window), on/off [s],
    %          freq [Hz], pktime (time of max power) [s], pwLevel (0-1), n (count).
    %
    %   Reference: Malerba P, Whitehurst L, Mednick SC (2022). The space-time profiles of
    %              sleep spindles... Sleep 45(8):zsac132. doi:10.1093/sleep/zsac132
    %
    %   Part of SleepRhythms
    %   Developed at the Sleep and Cognition (SaC) Lab, UC Irvine. Maintainer: Ali Ekhlasi
    %   https://github.com/aliekhlasi/SleepRhythms

    %% Initialize Parameters
    Trange = [-1, 1];  % Time range around each detected peak (in seconds)
    
    % Design high-pass Butterworth filter for spindle detection
    [b1, a1] = butter(6, 3 / (freq / 2), 'high');
    
    % Apply high-pass filter to the channel signal
    HPchannel = filtfilt(b1, a1, channel);
    disp('Now detecting spindles using wavelet power spectral level curves...');

    tic  % Start timer for processing

    pktID = FoundPeaks.tID;  % Extract peak IDs
    cnt = 0;  % Initialize spindle count

    % Hidden figure for the wavelet contour map (no pop-up windows).
    % If opt.figDir is set, each map is saved there as a PNG.
    saveFigs = isfield(opt, 'figDir') && ~isempty(opt.figDir);
    if saveFigs && ~exist(opt.figDir, 'dir'), mkdir(opt.figDir); end
    if ~isfield(opt, 'figPrefix'), opt.figPrefix = 'spindle'; end
    figH = figure('Visible', 'off', 'Color', 'w');
    try, theme(figH, 'light'); catch, end   % readable PNGs also when MATLAB uses dark mode
    axH = axes(figH);

    % Loop through each detected peak
    for pkN = 1:length(pktID)
        tpk = FoundPeaks.Time(pkN);  % Get time of current peak
        
        % Determine the sleep stage at the peak time
        n0 = hist(tpk, Hypno.t);
        stgN = Hypno.stg(n0 > 0);  % Identify sleep stage

        % Check for valid sleep stages (ignoring invalid stages)
        if isnan(stgN) || stgN > 9
            disp([num2str(pkN), ' has an invalid sleep stage for spindling.']);
            todiscard = 1;  % Mark for discard
        else
            % Define time range for spindle analysis
            tLft = FoundPeaks.Time(pkN) + Trange(1);
            tRgt = FoundPeaks.Time(pkN) + Trange(2);
            k1 = find(tx >= tLft, 1);  % Find left index
            k2 = find(tx >= tRgt, 1);  % Find right index

            % Compute continuous wavelet transform (CWT) of the filtered channel
            [wtcpx, fx, coi] = cwt(HPchannel(k1:k2), 'amor', freq);  % Use Morlet wavelet
            wPS = sqrt(wtcpx .* conj(wtcpx));  % Compute wavelet power spectrum
            
            % Prepare time and channel trace for spindle analysis
            tabout = tx(k1:k2);
            chtrace = channel(k1:k2);
            pWmax = ceil(max(wPS(:)));  % Maximum power
            pWmu = floor(mean(wPS(:)));   % Mean power
            pWstep = (pWmax - pWmu) / 20;  % Step size for contour levels
            pWc = pWmu:pWstep:pWmax;  % Contour levels

            % Generate contour plot of the wavelet power spectrum (in the hidden figure)
            cla(axH);
            [Cp, Hp] = contour(axH, tabout, log2(fx), wPS, pWc);

            %% Analyze Contour Peaks to Identify Spindle Characteristics
            nLines = 0;  % Counter for contour lines
            LevCrvs = struct('lvID', [], 'flow', [], 'fhigh', [], 'tlow', [], 'thigh', [], 'isLoop', [], 'fctr', [], 'tctr', []);  % Initialize structure for levels

            k0 = 1;  % Initialize index for contour analysis
            while k0 < length(Cp)
                ptscnt = Cp(2, k0);  % Number of points in the current line
                if ptscnt > 0
                    nLines = nLines + 1;  % Increment line counter
                    [~, nx] = ismember(Cp(1, k0), Hp.LevelList);  % Find corresponding level index
                    LevCrvs.lvID(nLines) = nx;  % Store level ID
                    lnpts_t = Cp(1, k0 + (1:ptscnt));  % Time points
                    lnpts_f = Cp(2, k0 + (1:ptscnt));  % Frequency points
                    lnpts_f = 2.^lnpts_f;  % Convert to actual frequencies
                    LevCrvs.flow(nLines) = min(lnpts_f);  % Store min frequency
                    LevCrvs.fhigh(nLines) = max(lnpts_f);  % Store max frequency
                    LevCrvs.tlow(nLines) = min(lnpts_t);  % Store min time
                    LevCrvs.thigh(nLines) = max(lnpts_t);  % Store max time
                    LevCrvs.isLoop(nLines) = (lnpts_f(end) == lnpts_f(1)) && (lnpts_t(end) == lnpts_t(1));  % Check for looping
                    LevCrvs.fctr(nLines) = (min(lnpts_f) + max(lnpts_f)) / 2;  % Center frequency
                    LevCrvs.tctr(nLines) = (min(lnpts_t) + max(lnpts_t)) / 2;  % Center time
                end
                k0 = k0 + ptscnt + 1;  % Move to the next contour line
            end

            %% Validate Detected Spindles
            % Check conditions for spindle validity based on frequency and timing
            isSigma = (LevCrvs.fctr >= 9) & (LevCrvs.fctr <= 16);  % Check if frequency is in sigma range
            isLoop = LevCrvs.isLoop > 0;  % Check for looping
            isTime = abs(LevCrvs.tctr - FoundPeaks.Time(pkN)) < 0.5;  % Check timing proximity
            gdloopN = find(isSigma & isLoop & isTime);  % Identify valid loops

            % Evaluate spindle validity
            if isempty(gdloopN)  % No valid sigma loops around the center time
                todiscard = 1;  % Mark for discard
            else
                [Lfnd, x0] = max(LevCrvs.lvID(gdloopN));  % Find tallest sigma loop
                if Lfnd < 4
                    todiscard = 1;  % Mark for discard if below threshold
                else                
                    Lmed = ceil(Lfnd / 2);  % Center height for spindle definition
                    loopID = gdloopN(x0);  % Get all loops around this one
                    f0 = LevCrvs.fctr(loopID);  % Center frequency
                    t0 = LevCrvs.tctr(loopID);  % Center time

                    % Identify surrounding loops based on frequency and timing
                    abtF = (LevCrvs.fhigh > LevCrvs.fhigh(loopID)) & (LevCrvs.flow < LevCrvs.flow(loopID));
                    abtT = (LevCrvs.thigh > LevCrvs.thigh(loopID)) & (LevCrvs.tlow < LevCrvs.tlow(loopID));
                    gdloopN2 = find(abtF & abtT & isLoop > 0);
                    z0 = abs(LevCrvs.lvID(gdloopN2) - Lmed);
                    nmid = gdloopN2(z0 == min(z0));  % Find the closest matching loop
                    if isempty(nmid)
                        todiscard = 1;  % Mark for discard if no valid match
                    else
                        if length(nmid) > 1  % If multiple matches, choose the best one
                            z0 = abs(t0 - LevCrvs.tctr(nmid));
                            x0 = nmid(z0 == min(z0));  % Get the closest match
                            nmid = x0;
                        end
                        todiscard = 0;  % Valid spindle found
                    end
                end
            end

            %% Save the contour map
            if saveFigs
                if todiscard, status = 'rejected'; else, status = 'spindle'; end
                hold(axH, 'on');
                yline(axH, log2([9 16]), '--r', {'9 Hz', '16 Hz'}, 'LineWidth', 1.5);  % sigma band
                xline(axH, tpk, ':r', 'LineWidth', 1.5);                                % RMS peak time
                hold(axH, 'off');
                fTicks = 2.^(ceil(log2(min(fx))):floor(log2(max(fx))));
                yticks(axH, log2(fTicks));
                yticklabels(axH, string(fTicks));
                xlabel(axH, 'Time (s)');
                ylabel(axH, 'Frequency (Hz, log scale)');
                title(axH, sprintf('%s | peak %d at %.2f s | %s', ...
                    strrep(opt.figPrefix, '_', '\_'), pkN, tpk, status));
                cb = colorbar(axH); cb.Label.String = 'Wavelet power';
                print(figH, fullfile(opt.figDir, sprintf('%s_peak%04d_%.2fs_%s.png', ...
                    opt.figPrefix, pkN, tpk, status)), '-dpng', '-r100');
                colorbar(axH, 'off');
            end

            %% Plotting Results
            if opt.showplots == 1
                figure(1);
                subplot(2, 2, 1);
                imagesc(tabout, log2(fx), (wPS));  % Plot wavelet power spectrum
                ax = gca;
                ax.YDir = 'normal';  % Set Y direction
                yticks(log2(min(fx)):log2(max(fx)));  % Set Y ticks
                Al = 2.^(log2(min(fx)):log2(max(fx)))';
                yticklabels(num2str(Al));  % Set Y labels
                title(num2str(pkN));  % Title with peak number

                subplot(2, 2, 2);
                [Cp, Hp] = contour(tabout, log2(fx), wPS, pWc);  % Contour plot
                ax = gca;
                ax.YDir = 'normal';  % Set Y direction
                yticks(log2(min(fx)):log2(max(fx)));  % Set Y ticks

                subplot(2, 1, 2);
                plot(tabout, chtrace, '-k');  % Plot channel trace
                xlim([min(tabout) max(tabout)]);  % Set X limits
                hold on;
            end

            %% Store Valid Spindles
            if todiscard == 0
                cnt = cnt + 1;  % Increment valid spindle count
                Spdl.RMStime(cnt) = FoundPeaks.Time(pkN);  % Store RMS time
                Spdl.tx{cnt} = tabout;  % Store time points
                Spdl.trace{cnt} = chtrace;  % Store spindle trace
                Spdl.on(cnt) = LevCrvs.tlow(nmid);  % Store onset time
                Spdl.off(cnt) = LevCrvs.thigh(nmid);  % Store offset time
                Spdl.freq(cnt) = f0;  % Store frequency
                Spdl.pktime(cnt) = t0;  % Store peak time
                Spdl.pwLevel(cnt) = Lfnd / 20;  % Store power level

                % Plot spindle detection results
                if opt.showplots == 1
                    figure(1);
                    subplot(2, 1, 2);
                    plot([Spdl.on(cnt), Spdl.off(cnt)], mean(Spdl.trace{cnt}) * ones(1, 2), 'o');  % Mark spindle onset and offset
                    hold off;
                    title(['Stage: ', num2str(stgN), ' Frequency: ', num2str(Spdl.freq(cnt)), ' Height: ', num2str(Spdl.pwLevel(cnt))]);
                end
            else
                if opt.showplots == 1
                    hold off;
                    title(['Discarded spindle (flag): ', num2str(todiscard)]);
                end
            end
        end
    end

    close(figH);  % Close the hidden figure

    %% Remove Duplicate Spindles
    disp('Removing duplicate spindles...');
    allTimes = Spdl.pktime;
    allGaps = diff(allTimes);
    x0 = allGaps < 0.1;  % Identify duplicates based on time gaps
    if sum(x0) > 0
        x0 = [0, x0];  % Prepend zero for correct indexing
        % Remove duplicates from spindle structure
        Spdl.RMStime(x0 > 0) = [];
        Spdl.tx(x0 > 0) = [];
        Spdl.trace(x0 > 0) = [];
        Spdl.on(x0 > 0) = [];
        Spdl.off(x0 > 0) = [];
        Spdl.freq(x0 > 0) = [];
        Spdl.pktime(x0 > 0) = [];
        Spdl.pwLevel(x0 > 0) = [];
    end
    
    % Final spindle count
    Nsp = length(Spdl.freq);
    Spdl.n = Nsp;  % Store number of detected spindles
    toc  % End timing
    disp(['Detected ', num2str(Nsp), ' spindles.']);  % Inform user of detected spindles

    return;  % End of function
end
