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

## Quick start (example with simulated data)

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
   - **Select Left / Right / Midline Channels**: hold ⌘ (Mac) or Ctrl (Windows) to select several. For the example:

     | Window | Select |
     |---|---|
     | Left | `Fp1` and `M1` |
     | Right | `Fp2` and `M2` |
     | Midline | `FPz` and `Fz` |

     Left channels are referenced to M2, right channels to M1, and midline channels to (M1 + M2) / 2. M1 and M2 are removed afterwards.

The example takes about 2 minutes. It uses random noise, so the results are meaningless. The noise is also much larger than real EEG, so almost all spindle candidates are rejected as artifacts (> 200 µV).

### Using your own data

In `Main_Toolbox.m`, replace the simulated data with your own:

| Variable | What to provide |
|---|---|
| `recording` | Name used as the prefix of every output file |
| `My_EEG` | EEG matrix, channels × samples, in **µV** |
| `My_Channel` | Channel names (must include `M1` and `M2`) |
| `SamplingRate` | Sampling rate in Hz |
| `Random_Scoring` | Your hypnogram: one stage code per scoring epoch |
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
| `Channels` | Channel names, in the same order as the rows of `data` (M1/M2 removed) |

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
| `Density_per_min` | `Count / StageDuration_min` |
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

**`<recording>_Bursts.mat`** holds `Burst_events`, `Burst_summary`, `NonBurst_segments` (the periods between bursts, same columns as the burst table), `Params`, `Channels`, `SamplingRate` and `StageCodes`.

---

## Methods in brief

**Re-referencing** (`Re_Referencing_Function_AE_toolbox.m`): left channels − M2, right channels − M1, midline channels − (M1 + M2)/2.

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
