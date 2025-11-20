# MATLAB Auditory Experiments - Refactoring Summary

## Overview

This document summarizes the refactoring of three MATLAB auditory perception experiments:
- `vowels9.m` → `vowels9_refactored.m`
- `consonants.m` → `consonants_refactored.m`
- `CRM.m` → `CRM_refactored.m`

**Date**: January 20, 2025

---

## Key Improvements

### 1. **Modern UI with Real-Time Visualization**

#### Before:
- Used pre-compiled `ark1.mat` GUI (difficult to modify)
- No visual feedback during experiment
- No confusion matrix
- Basic button interface

#### After:
- Modern `uifigure`-based interface
- **Real-time plots:**
  - **Vowels/Consonants**: Running accuracy + confusion matrix heatmap
  - **CRM**: Adaptive SNR track with reversal markers
- Progress indicators
- Clean, professional appearance
- Larger, more accessible buttons

### 2. **Standardized Data Output**

#### Before:
```
S001_vow9_L_0.txt          (custom format, hard to parse)
S001_vowch.all             (appended summary file)
```

#### After:
```
S001_vowels_L_20250120_143025.csv         (standard CSV)
S001_vowels_L_20250120_143025_summary.json (metadata + summary)
```

**CSV Format** (easy to load in Python/R):
```csv
trial,timestamp,speaker_id,vowel_id,response_id,correct,rt_sec
1,2025-01-20 14:30:25.123,5,3,3,1,1.2340
2,2025-01-20 14:30:28.456,12,7,6,0,1.5670
```

**JSON Summary** (experiment metadata):
```json
{
  "percent_correct": 85.6,
  "mean_rt_sec": 1.42,
  "total_trials": 180,
  "config": {...},
  "confusion_matrix": [...]
}
```

### 3. **Code Quality Improvements**

| Issue | Before | After |
|-------|--------|-------|
| Global variables | `global shp` | Passed via objects |
| Random seed | `rand('state',sum(100*clock))` | `rng('shuffle')` |
| File paths | `'C:/Data/' subjID '/'` | `fullfile('C:', 'Data', subjID)` |
| Magic numbers | `y = target * 1.982` | Documented, configurable |
| Error handling | Minimal | Try-catch, validation |
| Comments | Sparse | Comprehensive documentation |

### 4. **Modular Architecture**

#### New Helper Classes:

**`ExperimentConfig.m`** - Configuration management
```matlab
config = ExperimentConfig('vowels', 'S001');
config.numTrials = 180;
config.attenuation = 18.0;
config.setupPaths();
```

**`DataLogger.m`** - Standardized data logging
```matlab
logger = DataLogger(config);
logger.initialize();
logger.logTrial(trialData);
logger.finalize(summary);
```

**`ExperimentUI.m`** - Modern UI with plotting
```matlab
ui = ExperimentUI(config);
ui.initialize();
ui.updateAccuracyPlot(trial, accuracy);
ui.updateConfusionMatrix(confMatrix, labels);
```

### 5. **Better Error Handling**

- Validates inputs (subject ID, file paths, hardware)
- Graceful degradation if hardware not available
- Clear error messages
- Experiment can continue if UI closed early

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
│   ├── vowels9_refactored.m
│   ├── consonants_refactored.m
│   └── CRM_refactored.m
│
├── Helper classes:
│   ├── ExperimentConfig.m      # Configuration management
│   ├── DataLogger.m            # Standardized data output
│   └── ExperimentUI.m          # Modern UI with real-time plots
│
└── Documentation:
    └── REFACTORING_SUMMARY.md  # This file
```

---

## Usage Examples

### Vowel Recognition Test
```matlab
% Basic usage (180 trials, no feedback)
results = vowels9_refactored('S001');

% Custom settings
results = vowels9_refactored('S001', 50, 'y', 18.0);
%                            subjID  trials fb  atten
```

### Consonant Recognition Test
```matlab
% Basic usage (64 trials, no feedback)
results = consonants_refactored('S001');

% With feedback
results = consonants_refactored('S001', 64, 'y', 22.0);
```

### CRM Adaptive Test
```matlab
% Basic usage: target=talker0, maskers=talkers 1 and 3
[rundata, runrev] = CRM_refactored('S001', 0, [1 3]);

% With feedback and custom settings
[rundata, runrev] = CRM_refactored('S001', 0, [1 3], 'y', 15, 2);
%                                   subjID  tgt maskers fb  att runs
```

---

## Real-Time Visualizations

### Vowels/Consonants:
- **Left plot**: Running accuracy (updates every 5 trials)
- **Right plot**: Confusion matrix heatmap
- **Progress bar**: Trial count and current accuracy
- **Instruction panel**: Current task/feedback

### CRM:
- **Main plot**: SNR track over trials with reversal markers (red triangles)
- **Progress**: Run number, trial count
- **32-button grid**: 4 colors × 8 numbers

---

## Data Analysis

### Loading CSV Data in Python:
```python
import pandas as pd

# Load vowel data
df = pd.read_csv('S001_vowels_L_20250120_143025.csv')
accuracy = df['correct'].mean()
mean_rt = df['rt_sec'].mean()

# Plot accuracy over time
df['running_acc'] = df['correct'].expanding().mean()
df.plot(x='trial', y='running_acc')
```

### Loading in R:
```r
# Load data
df <- read.csv('S001_vowels_L_20250120_143025.csv')

# Calculate accuracy by vowel
library(dplyr)
df %>%
  group_by(vowel_id) %>%
  summarize(accuracy = mean(correct))
```

### Loading in MATLAB:
```matlab
% Load CSV
data = readtable('S001_vowels_L_20250120_143025.csv');

% Load JSON summary
summary = jsondecode(fileread('S001_vowels_L_20250120_143025_summary.json'));

% Access data
accuracy = mean(data.correct);
confMatrix = summary.confusion_matrix;
```

---

## Backward Compatibility

### Original vs Refactored Function Signatures:

**Vowels:**
```matlab
% Original
percCorrect = vowels9(subjID, howmany, feedback, atten);

% Refactored (added results structure)
results = vowels9_refactored(subjID, howmany, feedback, atten);
percentCorrect = results.percentCorrect;  % Same output
```

**Consonants:**
```matlab
% Original
percCorrect = consonants(subjID, howmany, feedback, atten);

% Refactored
results = consonants_refactored(subjID, howmany, feedback, atten);
percentCorrect = results.percentCorrect;
```

**CRM:**
```matlab
% Original
[rundata, runrev] = CRM(subjID, talker, maskers, fdback, baseatten, nrun);

% Refactored (identical outputs)
[rundata, runrev] = CRM_refactored(subjID, talker, maskers, feedback, baseatten, nrun);
```

---

## Hardware Requirements

- **TDT PA5 Programmable Attenuators** (USB connections)
  - PA5 #1: Signal attenuation
  - PA5 #2: Backup channel (muted at 90dB)

- **Graceful Degradation**: Code runs without hardware (for testing/development)

---

## Configuration

### Default Paths (modify in `ExperimentConfig.m` if needed):
```matlab
% Vowels
soundPath = 'C:/SoundFiles/Vowels/'
dataPath = 'C:/Experiments/Data/{subjID}/'

% Consonants
soundPath = 'C:/SoundFiles/Multi/Full/'

% CRM
soundPath = 'C:/SoundFiles/CRMCorpus/'
```

### Default Attenuations:
- **Vowels**: 18.0 dB (produces 65 dBA at red tab)
- **Consonants**: 22.0 dB (produces 65 dBA)
- **CRM**: 15.0 dB (base level)

---

## Testing Workflow

1. **Test with minimal trials:**
   ```matlab
   vowels9_refactored('TEST', 9, 'y', 18.0)  % 9 trials with feedback
   ```

2. **Verify output files created:**
   ```
   C:/Experiments/Data/TEST/
     ├── TEST_vowels_NS_YYYYMMDD_HHMMSS.csv
     └── TEST_vowels_NS_YYYYMMDD_HHMMSS_summary.json
   ```

3. **Check plots update in real-time**

4. **Verify hardware connection** (if available)

---

## Migration Guide

### To switch from original to refactored:

1. **Replace function calls:**
   ```matlab
   % OLD:
   vowels9('S001', 180, 'n', 18.0);

   % NEW:
   vowels9_refactored('S001', 180, 'n', 18.0);
   ```

2. **Update analysis scripts to read CSV instead of custom format:**
   ```matlab
   % OLD:
   data = load('S001_vow9_L_0.txt');

   % NEW:
   data = readtable('S001_vowels_L_20250120_143025.csv');
   ```

3. **Access confusion matrix from summary:**
   ```matlab
   summary = jsondecode(fileread('..._summary.json'));
   confMatrix = summary.confusion_matrix;
   ```

---

## Benefits Summary

✅ **Real-time feedback**: See accuracy and confusion matrix during testing
✅ **Better data format**: CSV + JSON work with Python, R, Excel
✅ **Easier analysis**: Standardized column names across experiments
✅ **Modern code**: Uses current MATLAB best practices
✅ **Better UX**: Clearer instructions, progress tracking
✅ **Maintainable**: Modular design, well-documented
✅ **Testable**: Can run without hardware

---

## Future Enhancements (Optional)

- [ ] Export confusion matrix as figure
- [ ] Add pause/resume capability
- [ ] Support for remote/web-based testing
- [ ] Integration with REDCap or other databases
- [ ] Automated data quality checks
- [ ] Multi-language support

---

## Questions?

For questions about the refactored code, see inline documentation in each file:
- Function headers have detailed usage instructions
- Helper functions are documented
- Comments explain non-obvious logic

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| Original | 2021-06-10 | vowels9.m last update |
| Original | 2021-11-23 | consonants.m last update |
| Refactored v1.0 | 2025-01-20 | Complete refactoring with modern UI and standardized output |
