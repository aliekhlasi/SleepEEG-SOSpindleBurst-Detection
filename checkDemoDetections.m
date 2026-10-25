function DemoCheck = checkDemoDetections(recording, Truth, selectedFolder)
    % CHECKDEMODETECTIONS - Compare the toolbox results with the events that
    % simulateSleepEEG added to the demo data.
    %
    % For each event type and channel it reports:
    %   Injected      - number of events added to the data
    %   Found         - injected events that were detected
    %   Recall_pct    - Found / Injected * 100
    %   ExtraDetected - detections (same stages) that do not match an injected event
    %
    % Only the stages where each event type was injected are compared:
    %   slow oscillations and spindles in N2/N3, theta and alpha bursts in REM.
    %
    % Matching rules:
    %   Slow oscillation - detected negative peak within 0.3 s of the injected one
    %   Spindle          - injected center lies between detected onset - 0.25 s and offset + 0.25 s
    %   Theta/alpha burst - detected burst (Included = 1) overlaps the injected burst
    %
    % Output: DemoCheck table, also saved as <recording>_DemoCheck.csv in the results folder.
    %
    %   Part of SleepEEG-SOSpindleBurst-Detection
    %   Maintainer: Ali Ekhlasi, Sleep and Cognition (SaC) Lab
    %   https://github.com/aliekhlasi/SleepEEG-SOSpindleBurst-Detection

    SO = readtable(fullfile(selectedFolder, '2_SlowOscillations', [recording '_SO_events.csv']), 'TextType', 'string');
    SP = readtable(fullfile(selectedFolder, '3_Spindles', [recording '_Spindle_events.csv']), 'TextType', 'string');
    BU = readtable(fullfile(selectedFolder, '4_Bursts', [recording '_Burst_events.csv']), 'TextType', 'string');
    BU = BU(BU.Included == 1, :);

    channels = unique([SO.Channel; SP.Channel; BU.Channel], 'stable');
    types = ["SlowOscillation", "Spindle", "ThetaBurst", "AlphaBurst"];

    rows = {};
    nrem = ismember(SO.Stage, ["N2", "N3"]);  SO = SO(nrem, :);
    SP = SP(ismember(SP.Stage, ["N2", "N3"]), :);
    for t = types
        tr = Truth(Truth.Type == t, :);
        if contains(t, "Burst"), tr = tr(tr.Stage == "REM", :);
        else, tr = tr(ismember(tr.Stage, ["N2", "N3"]), :); end
        for c = channels'
            switch t
                case "SlowOscillation"
                    det = SO(SO.Channel == c, :);
                    hit = @(i) abs(det.NegPeak_s - tr.Center_s(i)) < 0.3;
                case "Spindle"
                    det = SP(SP.Channel == c, :);
                    hit = @(i) tr.Center_s(i) >= det.Onset_s - 0.25 & tr.Center_s(i) <= det.Offset_s + 0.25;
                case "ThetaBurst"
                    det = BU(BU.Channel == c & BU.Band == "theta", :);
                    hit = @(i) det.Start_s < tr.End_s(i) & det.End_s > tr.Start_s(i);
                case "AlphaBurst"
                    det = BU(BU.Channel == c & BU.Band == "alpha", :);
                    hit = @(i) det.Start_s < tr.End_s(i) & det.End_s > tr.Start_s(i);
            end
            matched = false(height(det), 1);
            found = 0;
            for i = 1:height(tr)
                h = hit(i);
                if any(h), found = found + 1; matched = matched | h(:); end
            end
            rows(end+1, :) = {t, c, height(tr), found, 100 * found / max(height(tr), 1), sum(~matched)}; %#ok<AGROW>
        end
    end

    DemoCheck = cell2table(rows, 'VariableNames', ...
        {'EventType', 'Channel', 'Injected', 'Found', 'Recall_pct', 'ExtraDetected'});
    writetable(DemoCheck, fullfile(selectedFolder, [recording '_DemoCheck.csv']));

    disp(' ');
    disp('Demo check: detected vs. injected events');
    disp(DemoCheck);
end
