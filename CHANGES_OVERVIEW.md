# Quick Reference: What Changed in v3.0?

## Visual Comparison

### Architecture Evolution

```
v1.0 (Jan 2025)                v2.0 (Nov 2025)                v3.0 (Nov 2025 - CURRENT)
├── ExperimentConfig.m         ├── ExperimentCommon.m         ├── ExperimentCommon.m (ENHANCED)
├── DataLogger.m               │   - All utilities            │   - All utilities
├── ExperimentUI.m             │   - Dual-window UI           │   - Dual-window UI (always on)
└── 3 files, 703 lines         └── 1 file, 152 lines         │   - JSON & Parquet output
                                                              │   - Statistical analysis
                                                              │   - Auto visualizations
                                                              │   - Test mode support
                                                              └── 1 file, 528 lines
```

---

## Top 7 Enhancements (v3.0)

### 1. 📊 Multi-Format Data Output
**Before**: CSV only
**After**: CSV + JSON + Parquet

```
Output per session:
├── .csv     - Trial-by-trial data
├── .json    - Summary stats & metadata
└── .parquet - Columnar format (Python/R/Spark)
```

### 2. 📈 Comprehensive Statistics
**Before**: Basic accuracy only
**After**: Full statistical report

```
- Descriptive stats (mean, median, SD)
- Stratified by stimulus, speaker, correctness
- d-prime & response bias
- Chi-square & ANOVA tests
- Confusion matrix analysis
```

### 3. 🖼️ Automated Visualizations
**Before**: Manual post-processing needed
**After**: 4-8 plots auto-generated per session

```
Generated plots:
- Accuracy over time
- Accuracy by stimulus
- Response distribution
- RT histogram
- Confusion matrix (PNG + CSV)
- [CRM] SNR tracking with reversals
```

### 4. 🖥️ Always-Dual-Window UI
**Before**: Single window or inconsistent dual-window
**After**: ALWAYS renders two windows

```
Single Monitor:  Split-screen (Tester | Subject)
Dual Monitor:    Tester Monitor 1 | Subject Monitor 2

Subject window:  Buttons & instructions ONLY (blind to performance)
Tester window:   Plots, stats, progress tracking
```

### 5. 🧪 Test Mode
**Before**: Required hardware to run
**After**: Full test mode for development

```matlab
% Run without TDT PA5 hardware
results = vowels9_refactored('TEST', 9, 'y', 18.0, true);
%                                                    ^^^^
```

### 6. 🔢 Stratified Analysis
**Before**: Overall stats only
**After**: Broken down by every variable

```
- Accuracy by each stimulus
- Accuracy by each speaker
- RT by correctness (correct vs incorrect)
- Response frequency distribution
```

### 7. 📐 Statistical Tests
**Before**: None
**After**: Automatic inferential statistics

```
- Chi-square test (response uniformity)
- One-way ANOVA (accuracy across stimuli)
- Results in JSON output
```

---

## File Count Comparison

| Aspect | Original | v1.0 | v2.0 | v3.0 (Current) |
|--------|---------|------|------|----------------|
| Experiment files | 3 | 6 | 6 | 6 |
| Helper classes | 0 | 3 | 1 | 1 |
| Total utility lines | 0 | 703 | 152 | 528 |
| Output formats | 1 (custom) | 2 (CSV+JSON) | 1 (CSV) | 3 (CSV+JSON+Parquet) |
| Auto plots | 0 | 0 | 0 | 4-8 per session |
| Statistical tests | 0 | 0 | 0 | 2 (Chi²+ANOVA) |
| Dual windows | No | No | Yes | Yes (always) |
| Test mode | No | No | No | Yes |

---

## Output File Comparison

### Before (Original):
```
S001_vow9_L_0.txt              (custom format, hard to parse)
S001_vowch.all                 (appended file)
```

### After (v3.0):
```
S001_vowels_NS_20251122_143025.csv                   # Trial data
S001_vowels_NS_20251122_143025_summary.json          # Full stats
S001_vowels_NS_20251122_143025.parquet               # Big data format
S001_vowels_NS_confmatrix_20251122_143025.png        # Confusion heatmap
S001_vowels_NS_confmatrix_20251122_143025.csv        # Confusion data
S001_vowels_accuracy_20251122_143025.png             # Accuracy plot
S001_vowels_by_stimulus_20251122_143025.png          # Per-stimulus
S001_vowels_responses_20251122_143025.png            # Response dist
S001_vowels_rt_dist_20251122_143025.png              # RT histogram
```

---

## Code Simplification

### Helper Files

| Version | Files | Total Lines | Maintenance |
|---------|-------|-------------|-------------|
| v1.0 | ExperimentConfig.m (135)<br>DataLogger.m (178)<br>ExperimentUI.m (390) | 703 lines<br>3 files | Complex |
| v2.0 | ExperimentCommon.m (152) | 152 lines<br>1 file | Simple |
| **v3.0** | **ExperimentCommon.m (528)** | **528 lines<br>1 file** | **Comprehensive** |

**v3.0 Note**: More lines than v2.0 because it includes:
- Statistical analysis functions
- Visualization generation
- JSON & Parquet output
- Summary statistics computation
- Still maintains single-file simplicity!

---

## Function Signature Changes

### Vowels & Consonants:
```matlab
% v1.0 & v2.0
results = vowels9_refactored(subjID, howmany, feedback, atten);

% v3.0 (added testMode)
results = vowels9_refactored(subjID, howmany, feedback, atten, testMode);
%                                                             ^^^^^^^^
% Backward compatible: testMode defaults to false
```

### CRM:
```matlab
% v1.0 & v2.0
[rundata, runrev] = CRM_refactored(subjID, talker, maskers, nrun, feedback, atten);

% v3.0 (added testMode + results struct)
[rundata, runrev, results] = CRM_refactored(subjID, talker, maskers, nrun, feedback, atten, testMode);
%                 ^^^^^^^^                                                                    ^^^^^^^^
% Backward compatible: can still use [rundata, runrev] = CRM_refactored(...)
```

---

## Feature Matrix

| Feature | Original | v1.0 | v2.0 | v3.0 |
|---------|---------|------|------|------|
| **Data Formats** |
| CSV output | Custom | ✅ | ✅ | ✅ |
| JSON metadata | ❌ | ✅ | ❌ | ✅ |
| Parquet format | ❌ | ❌ | ❌ | ✅ |
| **UI** |
| Basic GUI | ✅ | ✅ | ✅ | ✅ |
| Real-time plots | ❌ | ✅ | ✅ | ✅ |
| Dual-window | ❌ | ❌ | Sometimes | Always |
| Subject blind | ❌ | ❌ | Sometimes | Always |
| **Statistics** |
| Basic accuracy | ✅ | ✅ | ✅ | ✅ |
| Confusion matrix | ❌ | ✅ | ✅ | ✅ (saved) |
| d-prime | ❌ | ❌ | ❌ | ✅ |
| Response bias | ❌ | ❌ | ❌ | ✅ |
| Chi-square test | ❌ | ❌ | ❌ | ✅ |
| ANOVA | ❌ | ❌ | ❌ | ✅ |
| Stratified stats | ❌ | Partial | Partial | Full |
| **Visualizations** |
| Auto-generated plots | ❌ | ❌ | ❌ | ✅ |
| Saved confusion matrix | ❌ | ❌ | ❌ | ✅ |
| RT histograms | ❌ | ❌ | ❌ | ✅ |
| SNR tracking (CRM) | ❌ | ❌ | In-UI | Saved |
| **Development** |
| Hardware required | ✅ | ✅ | ✅ | ❌ |
| Test mode | ❌ | ❌ | ❌ | ✅ |
| **Architecture** |
| Helper files | 0 | 3 | 1 | 1 |
| Code complexity | High | Medium | Low | Low |

---

## What Stayed the Same?

✓ Core experiment logic
✓ Stimulus files & paths
✓ Hardware interface (PA5)
✓ Randomization algorithm
✓ Attenuation levels
✓ Audio scaling factors
✓ Trial presentation order
✓ Response collection

---

## Quick Start Guide (v3.0)

### 1. Run a Test Experiment:
```matlab
% Quick 9-trial test with feedback (no hardware needed)
results = vowels9_refactored('TEST', 9, 'y', 18.0, true);
```

### 2. Run Production Experiment:
```matlab
% Full 180-trial experiment with hardware
results = vowels9_refactored('S001', 180, 'n', 18.0, false);
```

### 3. Check Outputs:
```matlab
% Navigate to data folder
cd C:\Experiments\Data\S001\

% List all output files
dir S001_vowels*

% Load JSON summary
summary = jsondecode(fileread('S001_vowels_NS_20251122_143025_summary.json'));

% Display key stats
fprintf('Accuracy: %.1f%%\n', summary.statistics.overall_accuracy);
fprintf('d-prime: %.2f\n', summary.statistics.d_prime);
fprintf('Chi-square p-value: %.4f\n', summary.statistical_tests.chi2_pval);
```

### 4. Analyze in Python:
```python
import pandas as pd
import json

# Load data
df = pd.read_csv('S001_vowels_NS_20251122_143025.csv')
# or faster:
df = pd.read_parquet('S001_vowels_NS_20251122_143025.parquet')

# Load summary
with open('S001_vowels_NS_20251122_143025_summary.json') as f:
    summary = json.load(f)

# Quick analysis
print(f"Accuracy: {summary['statistics']['overall_accuracy']:.1f}%")
print(f"Mean RT: {df['RT'].mean():.3f}s")
```

---

## Migration from v2.0 to v3.0

### Code Changes Needed:
**None!** All changes are backward compatible.

### Optional Enhancements:
```matlab
% Add testMode parameter (optional - defaults to false)
results = vowels9_refactored(subjID, howmany, feedback, atten, true);

% Use enhanced return values
fprintf('d-prime: %.2f\n', results.summary_statistics.d_prime);
fprintf('ANOVA p-value: %.4f\n', results.statistical_analysis.anova_p);
```

---

## Summary

### v3.0 = v2.0 + Professional Data Science Tools

| What We Kept | What We Added |
|-------------|---------------|
| ✅ Simple 1-file architecture | ✅ JSON & Parquet output |
| ✅ Dual-window UI | ✅ Always-on dual windows |
| ✅ Real-time plots | ✅ Saved visualizations |
| ✅ Clean code | ✅ Statistical tests |
| ✅ Backward compatible | ✅ Test mode |
| | ✅ Stratified analysis |
| | ✅ d-prime & bias |
| | ✅ Auto-generated reports |

**Bottom Line**: Same clean architecture, now with research-grade analytics and publication-ready outputs!
