% MAKE_README_FIGURES - Recreate the figures shown in README.md.
%
% Runs the SleepRhythms demo without pop-up windows (simulated data,
% rng(1), channels Fp1 | Fp2 | FPz + Fz) and saves these figures in
% docs/images/:
%   1_hypnogram_events.png  - hypnogram and detected events across the night (Fz)
%   2_example_events.png    - one example of each event type
%   3_spindle_wavelet.png   - wavelet map of one detected spindle
%   4_summary_density.png   - densities from the summary tables
%   5_demo_check.png        - detected vs. injected events
%
% Usage (from the toolbox folder, with EEGLAB on the path):
%   run('docs/make_readme_figures.m')
%
%   Part of SleepRhythms
%   Developed at the Sleep and Cognition (SaC) Lab, UC Irvine. Maintainer: Ali Ekhlasi
%   https://github.com/aliekhlasi/SleepRhythms

clearvars; close all;
root = fileparts(fileparts(mfilename('fullpath')));
addpath(root, fullfile(root, 'Spindle Functions'), fullfile(root, 'Burst Detection Functions'));
imgDir = fullfile(root, 'docs', 'images');
if ~exist(imgDir, 'dir'), mkdir(imgDir); end

%% Colors (validated categorical palette; text in neutral inks)
C.blue   = [42 120 214] / 255;   % slow oscillations
C.orange = [235 104 52] / 255;   % spindles
C.aqua   = [27 175 122] / 255;   % theta bursts
C.yellow = [237 161 0] / 255;    % alpha bursts
C.violet = [98 80 214] / 255;    % N2 (summary densities)
C.magenta = [232 123 164] / 255; % N3 (summary densities)
C.raw    = [0.60 0.60 0.58];     % raw EEG
C.text   = [0.04 0.04 0.04];
C.text2  = [0.32 0.32 0.31];
C.grid   = [0.90 0.90 0.89];
C.rem    = [0.95 0.93 0.86];     % REM shading
set(groot, 'defaultAxesFontSize', 10, 'defaultAxesXColor', C.text2, ...
    'defaultAxesYColor', C.text2, 'defaultTextColor', C.text, ...
    'defaultAxesTickDir', 'out', 'defaultAxesBox', 'off', ...
    'defaultAxesGridColor', C.grid, 'defaultAxesGridAlpha', 1, ...
    'defaultFigureColor', 'w', 'defaultAxesColor', 'w');

%% Run the demo (no pop-ups)
rng(1);
StageCodes = struct('Wake', 0, 'N1', 1, 'N2', 2, 'N3', 3, 'REM', 5);
recording = 'Sample';
My_Channel = {'Fp1', 'Fp2', 'FPz', 'Fz', 'M1', 'M2'};
fs = 250; epochS = 30;
[My_EEG, Scoring, Truth] = simulateSleepEEG(My_Channel, fs, epochS, StageCodes);

resDir = tempname; mkdir(resDir);
dirPaths = cellfun(@(d) fullfile(resDir, d), ...
    {'1_Rereferenced', '2_SlowOscillations', '3_Spindles', '4_Bursts'}, 'UniformOutput', false);
cellfun(@mkdir, dirPaths);

[EEG_reref, Channels] = Re_Referencing_Function_AE_toolbox(recording, My_EEG, My_Channel, fs, ...
    {'Fp1'}, {'Fp2'}, {'FPz', 'Fz'}, dirPaths);
SO_Detection_Function_AE_toolbox(recording, EEG_reref, Channels, Scoring, fs, epochS, StageCodes, dirPaths);
Spindle_Detection_Function_AE_toolbox(recording, EEG_reref, Channels, Scoring, fs, epochS, StageCodes, dirPaths);
Burst_Detection_Theta_Alpha_toolbox(recording, EEG_reref, Channels, Scoring, fs, epochS, StageCodes, dirPaths);
DemoCheck = checkDemoDetections(recording, Truth, resDir);

SO = load(fullfile(dirPaths{2}, [recording '_SO.mat']));
SP = load(fullfile(dirPaths{3}, [recording '_Spindles.mat']));
BU = load(fullfile(dirPaths{4}, [recording '_Bursts.mat']));

ch = 'Fz';  chIdx = find(strcmp(Channels, ch));
x = EEG_reref.data(chIdx, :);
t = (0:numel(x) - 1) / fs;
tMin = t / 60;
nightMin = numel(Scoring) * epochS / 60;

% REM periods (for shading), in minutes
isREM = Scoring == StageCodes.REM;
remOn  = (find(diff([0 isREM]) == 1) - 1) * epochS / 60;
remOff = find(diff([isREM 0]) == -1) * epochS / 60;

%% Figure 1: hypnogram and detected events across the night (Fz)
f = newFig([100 100 1000 520]);
tl = tiledlayout(f, 6, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

% Hypnogram: Wake at the top, N3 at the bottom
ax = nexttile(tl, [2 1]); hold(ax, 'on');
order = [StageCodes.N3, StageCodes.N2, StageCodes.N1, StageCodes.REM, StageCodes.Wake];
names = {'N3', 'N2', 'N1', 'REM', 'Wake'};
[~, level] = ismember(Scoring, order);
shadeREM(ax, remOn, remOff, [0.5 5.5], C.rem);
stairs(ax, [0, (1:numel(Scoring)) * epochS / 60], [level level(end)], 'Color', C.text, 'LineWidth', 2);
for k = find(isREM)
    plot(ax, [(k - 1) k] * epochS / 60, [4 4], 'Color', C.text, 'LineWidth', 5);
end
set(ax, 'YTick', 1:5, 'YTickLabel', names, 'XTickLabel', [], 'YLim', [0.5 5.5], 'XLim', [0 nightMin]);
ax.YGrid = 'on';
title(ax, 'Hypnogram and detected events (channel Fz, demo data)', 'FontWeight', 'normal', 'FontSize', 12);

rows = {
    'Slow oscillations', SO.SO_events.NegPeak_s(SO.SO_events.Channel == ch), C.blue;
    'Spindles',          SP.Spindle_events.PowerPeak_s(SP.Spindle_events.Channel == ch), C.orange;
    'Theta bursts (REM)', BU.Burst_events.Start_s(BU.Burst_events.Channel == ch & BU.Burst_events.Band == "theta" & BU.Burst_events.Included), C.aqua;
    'Alpha bursts (REM)', BU.Burst_events.Start_s(BU.Burst_events.Channel == ch & BU.Burst_events.Band == "alpha" & BU.Burst_events.Included), C.yellow};
for r = 1:size(rows, 1)
    ax = nexttile(tl); hold(ax, 'on');
    shadeREM(ax, remOn, remOff, [0 1], C.rem);
    ev = rows{r, 2} / 60;
    plot(ax, [ev ev]', repmat([0.15; 0.85], 1, numel(ev)), 'Color', rows{r, 3}, 'LineWidth', 1.2);
    set(ax, 'YTick', [], 'YLim', [0 1], 'XLim', [0 nightMin]);
    ax.YAxis.Color = 'w';
    ylabel(ax, sprintf('%s\n(%d)', rows{r, 1}, numel(ev)), 'Rotation', 0, ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', 'Color', C.text, 'FontSize', 9);
    if r < size(rows, 1), ax.XTickLabel = []; else, xlabel(ax, 'Time (min)'); end
end
exportgraphics(f, fullfile(imgDir, '1_hypnogram_events.png'), 'Resolution', 150, 'BackgroundColor', 'white');

%% Figure 2: one example of each event type (Fz)
f = newFig([100 100 1100 480]);
tl = tiledlayout(f, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

% Slow oscillation: largest one in N3
E = SO.SO_events(SO.SO_events.Channel == ch & SO.SO_events.Stage == "N3", :);
[~, i] = max(E.PeakToPeak_uV);  e = E(i, :);
[bL, aL] = butter(4, 4 / (fs / 2), 'low'); [bH, aH] = butter(4, 0.1 / (fs / 2), 'high');
xSO = filtfilt(bH, aH, filtfilt(bL, aL, x));
exampleColumn(tl, 1, t, x, xSO, e.Start_s, e.End_s, e.NegPeak_s + [-2.5 2.5], ...
    'Slow oscillation (N3)', '0.1–4 Hz', C.blue, C);

% Spindle: strongest one in N2
E = SP.Spindle_events(SP.Spindle_events.Channel == ch & SP.Spindle_events.Stage == "N2", :);
[~, i] = max(E.PowerLevel);  e = E(i, :);
[b1, a1] = butter(6, 9 / (fs / 2), 'high'); [b2, a2] = butter(6, 16 / (fs / 2), 'low');
xSP = filtfilt(b2, a2, filtfilt(b1, a1, x));
exampleColumn(tl, 2, t, x, xSP, e.Onset_s, e.Offset_s, e.PowerPeak_s + [-2 2], ...
    sprintf('Spindle (N2, %.1f Hz)', e.Frequency_Hz), '9–16 Hz', C.orange, C);
spindleExample = e;

% Theta burst: an included REM burst of typical length
E = BU.Burst_events(BU.Burst_events.Channel == ch & BU.Burst_events.Band == "theta" & BU.Burst_events.Included, :);
[~, i] = min(abs(E.Duration_s - 1.5));  e = E(i, :);
EEGf = pop_eegfiltnew(struct('data', x, 'srate', fs, 'nbchan', 1, 'pnts', numel(x), 'trials', 1, 'event', []), ...
    'locutoff', 4, 'hicutoff', 8, 'plotfreqz', 0);
xTH = double(EEGf.data);
ax = exampleColumn(tl, 3, t, x, xTH, e.Start_s, e.End_s, mean([e.Start_s e.End_s]) + [-3 3], ...
    sprintf('Theta burst (REM, %.1f s)', e.Duration_s), '4–8 Hz', C.aqua, C);
env = abs(hilbert(xTH));
w = t >= e.Start_s - 3 & t <= e.End_s + 3;
plot(ax, t(w), env(w), 'Color', C.text2, 'LineWidth', 1);
text(ax, e.End_s + 0.15, max(env(w)) * 0.95, 'envelope', 'Color', C.text2, 'FontSize', 9);
title(tl, 'Example detections (channel Fz, demo data)', 'FontSize', 12);
exportgraphics(f, fullfile(imgDir, '2_example_events.png'), 'Resolution', 150, 'BackgroundColor', 'white');

%% Figure 3: wavelet map of the example spindle (saved by the toolbox)
pngs = dir(fullfile(dirPaths{3}, 'Figures', ch, '*_spindle.png'));
tt = cellfun(@(s) str2double(regexprep(s, '.*_(\d+\.\d+)s_spindle\.png', '$1')), {pngs.name});
[~, i] = min(abs(tt - spindleExample.RMSPeak_s));
copyfile(fullfile(pngs(i).folder, pngs(i).name), fullfile(imgDir, '3_spindle_wavelet.png'));

%% Figure 4: densities from the summary tables (mean over channels in panel 3)
f = newFig([100 100 1100 360]);
tl = tiledlayout(f, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
densityPanel(nexttile(tl), SO.SO_summary, Channels, 'Slow oscillations', C);
densityPanel(nexttile(tl), SP.Spindle_summary, Channels, 'Spindles', C);

ax = nexttile(tl); hold(ax, 'on');
P = {'Q1', 'Q2', 'Q3', 'Q4'};
D = zeros(4, 2);
bands = ["theta", "alpha"];
for b = 1:2
    for q = 1:4
        S = BU.Burst_summary(BU.Burst_summary.Band == bands(b) & BU.Burst_summary.Period == P{q}, :);
        D(q, b) = mean(S.Density_per_min);
    end
end
h = bar(ax, D, 'BarWidth', 0.8, 'EdgeColor', 'w', 'LineWidth', 1.5);
h(1).FaceColor = C.aqua; h(2).FaceColor = C.yellow;
set(ax, 'XTick', 1:4, 'XTickLabel', P);
ax.YGrid = 'on';
ylabel(ax, 'Bursts per min of REM');
title(ax, 'REM bursts by night quarter', 'FontWeight', 'normal');
text(ax, 1, 0.4, {'no REM', 'in Q1'}, 'HorizontalAlignment', 'center', 'Color', C.text2, 'FontSize', 9);
legend(ax, {'Theta (4–8 Hz)', 'Alpha (8–13 Hz)'}, 'Location', 'northoutside', 'Orientation', 'horizontal', 'Box', 'off');
title(tl, 'Densities from the summary tables (demo data)', 'FontSize', 12);
exportgraphics(f, fullfile(imgDir, '4_summary_density.png'), 'Resolution', 150, 'BackgroundColor', 'white');

%% Figure 5: detected vs. injected events (demo check)
f = newFig([100 100 720 340]);
ax = axes(f); hold(ax, 'on');
types = ["SlowOscillation", "Spindle", "ThetaBurst", "AlphaBurst"];
labels = {'Slow oscillations', 'Spindles', 'Theta bursts', 'Alpha bursts'};
cols = [C.blue; C.orange; C.aqua; C.yellow];
for k = 1:4
    r = DemoCheck.Recall_pct(DemoCheck.EventType == types(k));
    bar(ax, k, mean(r), 0.6, 'FaceColor', cols(k, :), 'EdgeColor', 'none');
    plot(ax, k + linspace(-0.15, 0.15, numel(r)), r, 'o', 'MarkerSize', 6, ...
        'MarkerFaceColor', 'w', 'MarkerEdgeColor', C.text, 'LineWidth', 1);
    text(ax, k, max(r) + 7, sprintf('%.0f%%', mean(r)), 'HorizontalAlignment', 'center', ...
        'FontWeight', 'bold', 'Color', C.text);
end
set(ax, 'XTick', 1:4, 'XTickLabel', labels, 'YLim', [0 110], 'YTick', 0:20:100);
ax.YGrid = 'on';
ylabel(ax, 'Injected events found (%)');
title(ax, {'Demo check: how many injected events were detected', ...
    '\fontsize{9}\color[rgb]{0.32,0.32,0.31}bar = mean of 4 channels, circles = each channel'}, 'FontWeight', 'normal');
exportgraphics(f, fullfile(imgDir, '5_demo_check.png'), 'Resolution', 150, 'BackgroundColor', 'white');

rmdir(resDir, 's');
fprintf('Figures saved in %s\n', imgDir);

%% ---------- helper functions ----------
function f = newFig(pos)
    % White figure with the light theme (also when MATLAB uses dark mode)
    f = figure('Position', pos, 'Color', 'w');
    try, theme(f, 'light'); catch, end
end

function shadeREM(ax, on, off, yl, col)
    for k = 1:numel(on)
        patch(ax, [on(k) off(k) off(k) on(k)], [yl(1) yl(1) yl(2) yl(2)], col, ...
            'EdgeColor', 'none', 'HandleVisibility', 'off');
    end
end

function axF = exampleColumn(tl, col, t, x, xf, t0, t1, win, ttl, bandLabel, color, C)
    w = t >= win(1) & t <= win(2);
    axR = nexttile(tl, col); hold(axR, 'on');
    patch(axR, [t0 t1 t1 t0], [-1 -1 1 1] * 400, color, 'FaceAlpha', 0.12, 'EdgeColor', 'none');
    plot(axR, t(w), x(w), 'Color', C.raw, 'LineWidth', 0.8);
    yl = max(abs(x(w))) * 1.1; ylim(axR, [-yl yl]); xlim(axR, win);
    axR.XTickLabel = []; ylabel(axR, 'µV');
    title(axR, ttl, 'FontWeight', 'normal');
    text(axR, win(1) + 0.05 * diff(win), yl * 0.85, 'raw EEG', 'Color', C.text2, 'FontSize', 9);

    axF = nexttile(tl, col + 3); hold(axF, 'on');
    patch(axF, [t0 t1 t1 t0], [-1 -1 1 1] * 400, color, 'FaceAlpha', 0.12, 'EdgeColor', 'none');
    plot(axF, t(w), xf(w), 'Color', color, 'LineWidth', 1.5);
    yl = max(abs(xf(w))) * 1.15; ylim(axF, [-yl yl]); xlim(axF, win);
    xlabel(axF, 'Time (s)'); ylabel(axF, 'µV');
    text(axF, win(1) + 0.05 * diff(win), -yl * 0.85, bandLabel, 'Color', C.text, 'FontSize', 9);
    text(axF, (t0 + t1) / 2, yl * 0.92, 'detected', 'HorizontalAlignment', 'center', ...
        'Color', C.text2, 'FontSize', 9);
end

function densityPanel(ax, S, Channels, ttl, C)
    hold(ax, 'on');
    D = zeros(numel(Channels), 2);
    for c = 1:numel(Channels)
        D(c, 1) = S.Density_per_min(S.Channel == Channels{c} & S.Stage == "N2");
        D(c, 2) = S.Density_per_min(S.Channel == Channels{c} & S.Stage == "N3");
    end
    h = bar(ax, D, 'BarWidth', 0.8, 'EdgeColor', 'w', 'LineWidth', 1.5);
    h(1).FaceColor = C.violet; h(2).FaceColor = C.magenta;
    set(ax, 'XTick', 1:numel(Channels), 'XTickLabel', Channels);
    ax.YGrid = 'on';
    ylabel(ax, 'Events per min of that stage');
    title(ax, ttl, 'FontWeight', 'normal');
    legend(ax, {'N2', 'N3'}, 'Location', 'northoutside', 'Orientation', 'horizontal', 'Box', 'off');
end
