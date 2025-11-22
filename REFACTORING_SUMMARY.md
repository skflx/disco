# MATLAB Auditory Experiments - Enhanced Refactoring Summary

## Overview

This document summarizes the comprehensive refactoring of three MATLAB auditory perception experiments:
- `vowels9.m` → `vowels9_refactored.m`
- `consonants.m` → `consonants_refactored.m`
- `CRM.m` → `CRM_refactored.m`

**Latest Update**: November 22, 2025

---

## Key Improvements

### 1. **Always-On Dual-Window UI**

#### Architecture:
- **Subject Window** (Monitor 2): Response buttons and instructions ONLY
  - Subject is **always blind** to performance data
  - Black background for vision accessibility
  - Large, clear instruction text
  - No accuracy feedback or confusion matrices visible

- **Tester Window** (Monitor 1): Control panel with real-time analytics
  - Live accuracy plots (updated every 5 trials for vowels/consonants, every trial for CRM)
  - Confusion matrices with heatmaps
  - Progress indicators
  - Summary statistics display

#### Monitor Handling:
- **Dual Monitor**: Subject on Monitor 2, Tester on Monitor 1
- **Single Monitor**: Split-screen rendering (Tester left, Subject right)
- **Always renders two windows** - subject never sees performance

### 2. **Multi-Format Data Output**

#### Before:
```
S001_vow9_L_0.txt          (custom format)
S001_vowch.all             (appended)
```

#### After (Three Formats):

**CSV** - Standard tabular format:
```csv
Subject,Trial,Speaker,Vowel,Response,Correct,RT,Condition
S001,1,M01,AE,AE,1,1.234,NS
S001,2,W04,IH,IY,0,1.567,NS
```

**JSON** - Comprehensive metadata and statistics:
```json
{
  "subject_id": "S001",
  "experiment": "vowels",
  "condition": "NS",
  "timestamp": "20251122_143025",
  "statistics": {
    "overall_accuracy": 85.6,
    "mean_rt": 1.42,
    "d_prime": 2.34,
    "accuracy_by_stimulus": [...],
    "accuracy_by_speaker": {...},
    "confusion_matrix": [[...]]
  },
  "statistical_tests": {
    "chi2_pval": 0.045,
    "anova_p": 0.023
  }
}
```

**Parquet** - Apache Parquet for big data analysis:
```
S001_vowels_NS_20251122_143025.parquet
(columnar format, works with Python pandas, R, Spark)
```

### 3. **Comprehensive Statistical Analysis**

#### Summary Statistics:
- Overall accuracy, RT mean/median/SD
- **Stratified by every variable:**
  - Accuracy by stimulus
  - Accuracy by speaker
  - RT by correctness (correct vs incorrect trials)
  - Response distribution
- **Psychometric measures:**
  - d' (d-prime): sensitivity measure
  - Response bias (beta)

#### Statistical Tests:
- **Chi-square test**: Response uniformity
- **One-way ANOVA**: Accuracy differences across stimuli
- All results included in JSON output

#### CRM-Specific:
- Adaptive threshold estimation (mean of last 6 reversals)
- SNR tracking across runs
- Reversal analysis

### 4. **Automated Visualization Reports**

All experiments automatically generate:

1. **Accuracy over time** - Running accuracy with overall mean line
2. **Accuracy by stimulus** - Bar plot showing per-stimulus performance
3. **Response distribution** - Histogram of response frequencies
4. **RT distribution** - Reaction time histogram with mean
5. **Confusion matrix** - Saved as PNG with annotated counts AND CSV data

CRM additional plots:
- **SNR tracking** - Adaptive track for each run with reversal markers
- **Multi-run comparison** - Subplot grid showing all runs

All saved with timestamps for easy organization.

### 5. **Test Mode for Development**

```matlab
% Run without hardware (for development/testing)
results = vowels9_refactored('TEST', 9, 'y', 18.0, true);
%                                                    ^^^^ testMode
```

Features:
- Skips TDT PA5 hardware initialization
- Simulates audio playback with realistic delays
- Full UI and data output for testing
- Perfect for development without lab equipment

### 6. **Simplified Architecture**

#### Before (First Refactor):
```
ExperimentConfig.m      (135 lines)
DataLogger.m            (178 lines)
ExperimentUI.m          (390 lines)
------------------------
Total: 703 lines, 3 files
```

#### After (Enhanced Refactor):
```
ExperimentCommon.m      (528 lines)
------------------------
Total: 528 lines, 1 file
```

**Benefits:**
- 25% fewer lines
- Single file to maintain
- Easier to find functions
- All utilities in one place

---

## File Structure

```
Disco/
├── Original files (preserved):
│   ├── vowels9.m
│   ├── consonants.m
│   └── CRM.m
│
├── Refactored files:
│   ├── vowels9_refactored.m       (287 lines)
│   ├── consonants_refactored.m    (300 lines)
│   └── CRM_refactored.m          (442 lines)
│
├── Shared utilities:
│   └── ExperimentCommon.m         (528 lines - all utilities)
│
└── Documentation:
    ├── REFACTORING_SUMMARY.md     (this file)
    └── CHANGES_OVERVIEW.md
```

---

## Usage Examples

### Vowel Recognition Test
```matlab
% Basic usage (180 trials, no feedback)
results = vowels9_refactored('S001');

% With all options
results = vowels9_refactored('S001', 180, 'y', 18.0, false);
%                            subjID trials fb  atten testMode

% Test mode (no hardware)
results = vowels9_refactored('TEST', 9, 'y', 18.0, true);
```

### Consonant Recognition Test
```matlab
% Basic usage (64 trials)
results = consonants_refactored('S001');

% With feedback and test mode
results = consonants_refactored('S001', 64, 'y', 22.0, true);
```

### CRM Adaptive Test
```matlab
% Basic usage: target=talker0, maskers=talkers 1 and 3
[rundata, runrev, results] = CRM_refactored('S001', 0, [1 3]);

% With all options
[rundata, runrev, results] = CRM_refactored('S001', 0, [1 3], 2, 'y', 15, false);
%                                           subjID  tgt maskers runs fb att testMode
```

---

## Output Files (Per Session)

For a vowels experiment with subject S001, condition NS, you get:

```
C:/Experiments/Data/S001/
├── S001_vowels_NS_20251122_143025.csv                      # Trial data
├── S001_vowels_NS_20251122_143025_summary.json             # Statistics
├── S001_vowels_NS_20251122_143025.parquet                  # Parquet format
├── S001_vowels_NS_confmatrix_20251122_143025.png          # Confusion heatmap
├── S001_vowels_NS_confmatrix_20251122_143025.csv          # Confusion CSV
├── S001_vowels_accuracy_20251122_143025.png               # Accuracy plot
├── S001_vowels_by_stimulus_20251122_143025.png            # Stimulus accuracy
├── S001_vowels_responses_20251122_143025.png              # Response distribution
└── S001_vowels_rt_dist_20251122_143025.png                # RT histogram
```

---

## Data Analysis Workflows

### Loading in Python:
```python
import pandas as pd
import json

# Load CSV data
df = pd.read_csv('S001_vowels_NS_20251122_143025.csv')

# Load JSON summary
with open('S001_vowels_NS_20251122_143025_summary.json', 'r') as f:
    summary = json.load(f)

print(f"Accuracy: {summary['statistics']['overall_accuracy']:.1f}%")
print(f"d-prime: {summary['statistics']['d_prime']:.2f}")

# Load Parquet (fastest for large datasets)
df_parquet = pd.read_parquet('S001_vowels_NS_20251122_143025.parquet')
```

### Loading in R:
```r
library(jsonlite)
library(arrow)

# Load CSV
df <- read.csv('S001_vowels_NS_20251122_143025.csv')

# Load JSON
summary <- fromJSON('S001_vowels_NS_20251122_143025_summary.json')

# Load Parquet
df_parquet <- read_parquet('S001_vowels_NS_20251122_143025.parquet')
```

### Loading in MATLAB:
```matlab
% Load CSV
data = readtable('S001_vowels_NS_20251122_143025.csv');

% Load JSON
summary = jsondecode(fileread('S001_vowels_NS_20251122_143025_summary.json'));

% Load Parquet
dataParquet = parquetread('S001_vowels_NS_20251122_143025.parquet');

% Access statistics
fprintf('Accuracy: %.1f%%\n', summary.statistics.overall_accuracy);
confMatrix = summary.statistics.confusion_matrix;
```

---

## ExperimentCommon.m Functions

### UI Functions:
- `setupDualUI()` - Create subject & tester windows (always dual)
- `createGridButtons()` - Generate response button grids
- `waitForResponse()` - Enable/disable buttons

### Hardware Functions:
- `initHardware(atten, testMode)` - Initialize PA5 or skip for testing

### Data Functions:
- `initLogFile()` - Create CSV file with headers
- `saveJSON()` - Save summary as JSON
- `saveParquet()` - Save data as Parquet
- `saveConfusionMatrix()` - Save confusion matrix as PNG + CSV

### Analysis Functions:
- `computeSummaryStats()` - Comprehensive descriptive statistics
- `performStatisticalAnalysis()` - Chi-square, ANOVA tests
- `computeDPrime()` - Calculate d' from confusion matrix
- `computeBias()` - Calculate response bias
- `createVisualizationReport()` - Generate all plots

---

## Backward Compatibility

### Function Signatures:

**Vowels/Consonants:**
```matlab
% Original
percCorrect = vowels9(subjID, howmany, feedback, atten);

% Refactored (added testMode, enhanced return value)
results = vowels9_refactored(subjID, howmany, feedback, atten, testMode);
percentCorrect = results.summary_statistics.overall_accuracy;
```

**CRM:**
```matlab
% Original
[rundata, runrev] = CRM(subjID, talker, maskers, feedback, baseatten, nrun);

% Refactored (added testMode, enhanced return value)
[rundata, runrev, results] = CRM_refactored(subjID, talker, maskers, nrun, feedback, atten, testMode);
```

---

## Hardware Requirements

- **TDT PA5 Programmable Attenuators** (USB connections)
  - PA5 #1: Signal attenuation
  - PA5 #2: Backup channel (muted at 120dB)

- **Graceful Fallback**:
  - Auto-detects hardware failure
  - Runs in simulation mode if not available
  - Explicit test mode via parameter

---

## Configuration

### Default Paths:
```matlab
% Vowels
soundPath = 'C:/SoundFiles/Vowels/'
dataPath = 'C:/Experiments/Data/{subjID}/'

% Consonants
soundPath = 'C:/SoundFiles/Multi/Full/'

% CRM
soundPath = 'C:/SoundFiles/CRMCorpus/original/'
```

### Default Attenuations:
- **Vowels**: 18.0 dB (produces 65 dBA at red tab)
- **Consonants**: 22.0 dB (produces 65 dBA)
- **CRM**: 15.0 dB (base level)

---

## Testing Workflow

### 1. Quick Test (9 trials):
```matlab
% Run in test mode with feedback
results = vowels9_refactored('TEST', 9, 'y', 18.0, true);
```

### 2. Verify Outputs:
```
C:/Experiments/Data/TEST/
  ├── TEST_vowels_NS_YYYYMMDD_HHMMSS.csv
  ├── TEST_vowels_NS_YYYYMMDD_HHMMSS_summary.json
  ├── TEST_vowels_NS_YYYYMMDD_HHMMSS.parquet
  └── [visualization PNGs]
```

### 3. Check Dual Windows:
- Subject window shows only buttons and instructions
- Tester window shows plots and stats
- Both windows render even on single monitor

### 4. Verify Statistics:
```matlab
% Check JSON output
summary = jsondecode(fileread('TEST_vowels_NS_YYYYMMDD_HHMMSS_summary.json'));
disp(summary.statistics);
```

---

## Benefits Summary

✅ **Dual-window UI**: Subject always blind to performance
✅ **Multi-format output**: CSV + JSON + Parquet
✅ **Comprehensive stats**: Descriptive + inferential statistics
✅ **Stratified analysis**: By stimulus, speaker, correctness
✅ **Auto visualizations**: Plots saved automatically
✅ **Test mode**: Develop without hardware
✅ **Simplified code**: One utility file instead of three
✅ **Better UX**: Clear instructions, progress tracking
✅ **Analysis-ready**: Works with Python, R, MATLAB, Excel

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| Original | 2021-06-10 | vowels9.m last update |
| Original | 2021-11-23 | consonants.m last update |
| Refactored v1.0 | 2025-01-20 | First refactoring with 3 helper classes |
| Refactored v2.0 | 2025-11-21 | Dual-window UI, consolidated to 1 utility file |
| **Refactored v3.0** | **2025-11-22** | **Multi-format output (CSV+JSON+Parquet), comprehensive stats, visualizations, test mode** |

---

## Summary of Latest Enhancements (v3.0)

### What Changed:
1. **Multi-format output**: Added JSON and Parquet alongside CSV
2. **Comprehensive statistics**: Descriptive stats, d-prime, bias, stratified analysis
3. **Statistical tests**: Chi-square and ANOVA automatically performed
4. **Auto visualizations**: 4-8 plots generated per session
5. **Test mode**: Run experiments without hardware
6. **Always dual-window**: Even on single monitor, subject stays blind
7. **Confusion matrices**: Saved as annotated PNG + CSV data

### What Stayed the Same:
✓ Core experiment logic
✓ Stimulus files and paths
✓ Hardware interface (PA5)
✓ Randomization procedure
✓ Attenuation levels
✓ Audio scaling
✓ Response collection

### Bottom Line:
**Same rigorous science, professional-grade data output and analysis!**
