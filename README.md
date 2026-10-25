# SleepEEG-SOSpindleBurst-Detection

A MATLAB toolbox that detects three kinds of sleep EEG events:

- **Slow oscillations (SO)**: 0.1–4 Hz waves, reported for N2, N3 and N2+N3
- **Sleep spindles**: 9–16 Hz bursts, reported for N2, N3 and N2+N3
- **Theta (4–8 Hz) and alpha (8–13 Hz) bursts**: reported for REM sleep, per quarter and half of the night

The EEG is first re-referenced to the mastoids. Every detected event is saved in a table (CSV and `.mat`) with its channel, sleep stage, timing and amplitude. A summary table gives counts and densities per channel.

---

## Requirements

| Software | Used for |
|---|---|
| MATLAB (tested on R2026a) | |
| Signal Processing Toolbox | `butter`, `filtfilt`, `hilbert`, `findpeaks` |
| Wavelet Toolbox | `cwt` (spindle detection) |
| Statistics and Machine Learning Toolbox | `zscore` |
| Curve Fitting Toolbox | `smooth` (burst detection) |
| [EEGLAB](https://sccn.ucsd.edu/eeglab/) | `pop_eegfiltnew` (band-pass filtering) |

---

## Quick start (demo with simulated data)

1. Start MATLAB and load EEGLAB:
   ```matlab
   addpath('/path/to/eeglab'); eeglab nogui;
   ```
2. Go to the toolbox folder and run the main script:
   ```matlab
   cd('/path/to/SleepEEG-SOSpindleBurst-Detection')
   Main_Toolbox
   ```
3. Answer the pop-up windows:
   - **Select the Toolbox Directory**: the folder that contains `Main_Toolbox.m`.
   - **Select a folder to save the results**: any folder *outside* the toolbox folder.
   - **Select LEFT / RIGHT / MIDLINE channels**: hold ⌘ (Mac) or Ctrl (Windows) to select several. For the demo:

     | Window | Select |
     |---|---|
     | LEFT | `Fp1` |
     | RIGHT | `Fp2` |
     | MIDLINE | `FPz` and `Fz` |

The demo takes about 2–3 minutes. When it finishes, it prints a table comparing what the toolbox found with what was put into the data (see [The demo data](#the-demo-data)).

### Channel selection and re-referencing

The data are re-referenced to the mastoids:

| Group | Reference |
|---|---|
| Left channels | − M2 (opposite mastoid) |
| Right channels | − M1 (opposite mastoid) |
| Midline channels | − (M1 + M2) / 2 |

- The mastoid channels are found **automatically by name** (`M1` and `M2`, any upper/lower case). They aren't shown in the selection windows, and the recording must contain them.
- Only the channels you select are analyzed and saved. You can leave a group empty, for example a recording with only midline channels.
- Selecting the same channel in two groups gives a clear error message.

### The demo data

`simulateSleepEEG.m` creates 30 minutes of simulated sleep EEG at 250 Hz, so you can try the toolbox and see that it works:

- **Hypnogram** (60 × 30-s epochs): Wake → N1 → N2 → N3 → N2 → REM → N2 → N3 → N2 → REM. The first quarter of the night contains no REM, as in real sleep.
- **Background**: 1/f ("pink") noise of about 20 µV on the scalp channels and 8 µV on M1/M2.
- **Injected events** at random, non-overlapping times on all scalp channels, with a slightly different size on each channel:

  | Event | Stages | Rate | Frequency | Duration | Peak amplitude |
  |---|---|---|---|---|---|
  | Slow oscillation | N2 / N3 | 3 / 8 per min | 0.7–1.1 Hz | one cycle | 90–130 µV |
  | Spindle | N2 / N3 | 5 / 2 per min | 11–15 Hz | 0.6–1.5 s | 25–35 µV |
  | Theta burst | REM | 4 per min | 5–7 Hz | 1–2.5 s | 30–40 µV |
  | Alpha burst | REM, Wake | 3 per min | 9–11 Hz | 0.8–1.8 s | 25–35 µV |

At the end of the demo, `checkDemoDetections.m` compares the results with the injected events. Slow oscillations and spindles are compared in N2/N3, bursts in REM. It saves two files in the results folder:

- `<recording>_SimulatedEvents.csv`: every injected event (`Type`, `Stage`, `Start_s`, `End_s`, `Center_s`, `Frequency_Hz`, `Amplitude_uV`).
- `<recording>_DemoCheck.csv`: per event type and channel, `Injected`, `Found`, `Recall_pct` (found / injected × 100) and `ExtraDetected` (detections that don't match an injected event).

A typical demo run finds about 80–90% of the injected slow oscillations, spindles and bursts. Some misses are expected:
- Some injected slow oscillations are deliberately close to the 80 µV threshold.
- The burst detector's threshold adapts to the background.
- The "extra" detections come from the random background, which by chance sometimes looks like an event.

The results differ slightly from run to run because the data are random. Use `rng(1)` before `Main_Toolbox` for identical runs.

### Using your own data

In `Main_Toolbox.m`, replace the *Prepare EEG Data* section with your own data, and delete the *Demo only* section at the end:

| Variable | What to provide |
|---|---|
| `recording` | Name used as the prefix of every output file |
| `My_EEG` | EEG matrix, channels × samples, in **µV** |
| `My_Channel` | Channel names (must include `M1` and `M2`) |
| `SamplingRate` | Sampling rate in Hz |
| `Scoring` | Your hypnogram: one stage code per scoring epoch |
| `Windows_size_scoring` | Scoring epoch length in seconds (usually 30) |
| `StageCodes` | The number your scoring uses for each stage (see below) |

### Sleep stage codes

Set these once at the top of `Main_Toolbox.m` to match your scoring software:

```matlab
StageCodes = struct('Wake', 0, 'N1', 1, 'N2', 2, 'N3', 3, 'REM', 5);
```

---

## Output files

All times are in **seconds from the start of the recording**. All amplitudes are in **µV**. Each `.csv` file opens directly in Excel, R, Python or SPSS. Each `.mat` file contains the same tables as MATLAB `table` variables, plus the parameters used.

```
<results folder>/
├── <recording>_SimulatedEvents.csv      (demo only)
├── <recording>_DemoCheck.csv            (demo only)
├── 1_Rereferenced/
│   └── <recording>_EEG_reref.mat
├── 2_SlowOscillations/
│   ├── <recording>_SO_events.csv
│   ├── <recording>_SO_summary.csv
│   └── <recording>_SO.mat
├── 3_Spindles/
│   ├── <recording>_Spindle_events.csv
│   ├── <recording>_Spindle_summary.csv
│   ├── <recording>_Spindles.mat
│   └── Figures/<channel>/*.png
└── 4_Bursts/
    ├── <recording>_Burst_events.csv
    ├── <recording>_Burst_summary.csv
    └── <recording>_Bursts.mat
```

### 1. Re-referenced EEG: `1_Rereferenced/<recording>_EEG_reref.mat`

| Variable | Description |
|---|---|
| `EEG_reref.data` | Re-referenced EEG, channels × samples (µV) |
| `EEG_reref.srate` | Sampling rate (Hz) |
| `EEG_reref.nbchan`, `EEG_reref.pnts` | Number of channels and samples |
| `Channels` | Names of the selected channels, in the same order as the rows of `data` |

### 2. Slow oscillations: `2_SlowOscillations/`

**`<recording>_SO_events.csv`**: one row per slow oscillation (all stages).

| Column | Description |
|---|---|
| `Channel` | Channel name |
| `Stage`, `StageCode` | Sleep stage at the negative peak (name and code) |
| `Start_s` | Start of the negative half-wave (downward zero-crossing) |
| `NegPeak_s` | Time of the negative peak (trough) |
| `ZeroCross_s` | Upward zero-crossing between the negative and positive half-waves |
| `End_s` | End of the positive half-wave |
| `Duration_s` | `End_s − Start_s` |
| `NegPeak_uV` | Amplitude of the negative peak (0.1–4 Hz filtered signal) |
| `PosPeak_uV` | Amplitude of the positive peak |
| `PeakToPeak_uV` | `PosPeak_uV − NegPeak_uV` |

**`<recording>_SO_summary.csv`**: one row per channel and stage group (`N2`, `N3`, `N2+N3`).

| Column | Description |
|---|---|
| `Channel`, `Stage` | Channel and stage group |
| `Count` | Number of slow oscillations |
| `StageDuration_min` | Minutes scored as that stage |
| `Density_per_min` | `Count / StageDuration_min` (`NaN` if the stage doesn't occur) |
| `MeanNegPeak_uV`, `MeanPeakToPeak_uV` | Mean amplitudes |

**`<recording>_SO.mat`** holds `SO_events`, `SO_summary`, `Params` (detection settings), `Channels`, `SamplingRate` and `StageCodes`.

### 3. Spindles: `3_Spindles/`

**`<recording>_Spindle_events.csv`**: one row per spindle (all stages).

| Column | Description |
|---|---|
| `Channel` | Channel name |
| `Stage`, `StageCode` | Sleep stage at the spindle's power peak |
| `Onset_s`, `Offset_s` | Start and end of the spindle |
| `Duration_s` | `Offset_s − Onset_s` |
| `Frequency_Hz` | Spindle frequency (center of the wavelet power island) |
| `PeakToPeak_uV` | Peak-to-peak amplitude between onset and offset |
| `NumPeaks` | Number of oscillation peaks within the spindle |
| `PowerPeak_s` | Time of maximum wavelet power |
| `RMSPeak_s` | Time of the sigma-RMS peak that triggered the detection |
| `PowerLevel` | Relative wavelet power level, 0–1 (higher = stronger spindle) |

**`<recording>_Spindle_summary.csv`**: one row per channel and stage group (`N2`, `N3`, `N2+N3`).

| Column | Description |
|---|---|
| `Channel`, `Stage` | Channel and stage group |
| `Count` | Number of spindles |
| `StageDuration_min` | Minutes scored as that stage |
| `Density_per_min` | `Count / StageDuration_min` |
| `MeanFrequency_Hz`, `MeanDuration_s`, `MeanPeakToPeak_uV` | Averages over those spindles |

**`<recording>_Spindles.mat`** holds `Spindle_events`, `Spindle_summary`, `Spindle_waveforms` (one cell per channel with the 2-s EEG window `tx`/`trace` and `Onset_s`/`Offset_s` of each spindle), `Params`, `Channels`, `SamplingRate` and `StageCodes`.

**`Figures/<channel>/<recording>_<channel>_peakNNNN_<time>s_<status>.png`**: wavelet power map of each spindle candidate (step 2 below). The red dashed lines mark 9 and 16 Hz, and the dotted line marks the candidate's time. `<status>` is `spindle` if the candidate passed the wavelet check and `rejected` if it didn't. Candidates that pass this check can still be removed in step 3, so the final list is always `Spindle_events.csv`.

### 4. Theta and alpha bursts: `4_Bursts/`

**`<recording>_Burst_events.csv`**: one row per detected burst, all stages, both bands.

| Column | Description |
|---|---|
| `Band` | `theta` or `alpha` |
| `Channel` | Channel name |
| `Start_s`, `End_s`, `Duration_s` | Burst timing |
| `MeanPower_uV2` | Mean squared amplitude of the band-pass filtered signal during the burst |
| `Stage`, `StageCode` | Sleep stage at the burst start |
| `NightQuarter` | 1–4: which quarter of the scored night the burst starts in |
| `InREM` | 1 if the burst starts in REM |
| `DurationOK` | 1 if 0.5 s < duration < 3 s (theta) or 2 s (alpha) |
| `Included` | 1 if `InREM` and `DurationOK`; only these bursts are counted in the summary |

**`<recording>_Burst_summary.csv`**: REM bursts, one row per band, channel and part of the night.

| Column | Description |
|---|---|
| `Band`, `Channel` | Frequency band and channel |
| `Period` | `Q1`–`Q4` (night quarters), `FirstHalf`, `SecondHalf` or `WholeNight` |
| `REM_min` | Minutes of REM in that period |
| `Count` | Number of included bursts |
| `Density_per_min` | `Count / REM_min` |
| `MeanDuration_s`, `MeanPower_uV2` | Averages over those bursts |
| `NonBurst_MeanPower_uV2` | Mean power of the REM periods between bursts (baseline) |

A period with no REM (for example `Q1` early in the night) has `REM_min = 0`, so its density and averages are `NaN`.

**`<recording>_Bursts.mat`** holds `Burst_events`, `Burst_summary`, `NonBurst_segments` (the periods between bursts, same columns as the burst table), `Params`, `Channels`, `SamplingRate` and `StageCodes`.

---

## Files in this toolbox

| File | Role |
|---|---|
| `Main_Toolbox.m` | Main script: run this |
| `setupToolbox.m` | Adds the function folders to the MATLAB path and checks the requirements |
| `createResultDirectories.m` | Creates the four result folders |
| `assignChannels.m` | Pop-up windows for choosing left / right / midline channels |
| `simulateSleepEEG.m` | Creates the demo data (demo only) |
| `checkDemoDetections.m` | Compares the demo results with the injected events (demo only) |
| `Re_Referencing_Function_AE_toolbox.m` | Step 1: re-referencing |
| `SO_Detection_Function_AE_toolbox.m`, `DetectSO_Filter_AE_toolbox.m` | Step 2: slow oscillations |
| `Spindle_Detection_Function_AE_toolbox.m`, `Spindle Functions/` | Step 3: spindles |
| `Burst_Detection_Theta_Alpha_toolbox.m`, `Burst Detection Functions/` | Step 4: theta and alpha bursts |
| `stageAtSample.m` | Helper: finds the sleep stage at a given time |

---

## Methods in brief

**Re-referencing** (`Re_Referencing_Function_AE_toolbox.m`): left channels − M2, right channels − M1, midline channels − (M1 + M2)/2. M1 and M2 are found by name.

**Slow oscillations** (`SO_Detection_Function_AE_toolbox.m`, `DetectSO_Filter_AE_toolbox.m`): the signal is band-passed at 0.1–4 Hz (4th-order Butterworth, zero-phase). Zero-crossings split it into candidate waves. A wave is kept if:
- its negative half-wave lasts 0.3–1 s,
- the negative peak is deeper than −80 µV,
- and the peak-to-peak amplitude is above 80 µV.

**Spindles** (`Spindle_Detection_Function_AE_toolbox.m` and `Spindle Functions/`) run in three steps:
1. *Candidates*: the RMS of the 9–16 Hz signal (0.1-s window) is z-scored. Peaks above z = 3.5 become candidates (`DetectRMSpeaks.m`).
2. *Wavelet check*: a Morlet wavelet transform of ±1 s around each candidate must contain a closed power "island" centered within 9–16 Hz and within 0.5 s of the candidate (`GetSpindlesFromRMSpeaks.m`).
3. *Waveform check*: the spindle must show clear oscillation peaks and stay below 200 µV. Onset and offset are refined to the first and last peak (`SpdlFrequencyInTime.m`).

**Bursts** (`Burst_Detection_Theta_Alpha_toolbox.m` and `Burst Detection Functions/`): the signal is band-passed (EEGLAB) and its Hilbert amplitude envelope is computed. A burst is a period where the envelope exceeds mean + 2 SD of a 30-s moving window. The burst edges are extended while the amplitude stays above half the threshold, and a minimum number of cycles is required (`burst_detector2.m`).

---

## Credits

Developed at the Sleep and Cognition (SaC) Lab.

## License

MIT. See [LICENSE](LICENSE).
