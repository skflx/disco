# Disco Analysis Pipeline Documentation

**Version:** 4.12
**Last Updated:** November 2025

## Overview

This repository contains the analysis pipeline for auditory perception experiments evaluating speech intelligibility in cochlear implant (CI), hearing aid (HA), and bimodal (BM) device users. The pipeline processes three types of experimental data:

1. **Consonants** - Phoneme recognition in quiet
2. **Vowels** - Vowel discrimination across 20 talkers
3. **CRM (Coordinate Response Measure)** - Sentence recognition in competing speech noise

---

## Repository Structure

```
Disco/
├── analysis_v4.12_cc.ipynb      # Main analysis notebook (current version)
├── README_cc.md                  # This file
├── CRM.m                         # MATLAB reference: CRM staircase procedure
├── consonants.m                  # MATLAB reference: Consonant testing
├── vowels9.m                     # MATLAB reference: 9-vowel testing
├── Data/                         # Subject data directories (user-created)
│   ├── CI148/                    # Example subject folder
│   │   ├── CI148_cons_BM_0.out
│   │   ├── CI148_vow9_BM_0.txt
│   │   ├── CI148_crm_1.txt
│   │   └── ...
│   └── [SubjectID]/
└── [SubjectID]_[cvc]_[date].csv # Aggregated output files
```

---

## File Naming Convention

### Input Data Files (Expected Format)

| Task | Pattern | Example |
|------|---------|---------|
| **Consonants** | `*cons*.[txt\|out]` | `CI148_cons_BM_0.out` |
| **Vowels** | `*vow*.[txt\|out]` | `CI148_vow9_CI_0.txt` |
| **CRM** | `*_crm_*.txt` | `CI148_crm_3.txt` |

### Output Aggregated Files

**Format:** `[SubjectID]_[cvc]_[yy.mm.dd].csv`

**Nomenclature Logic:**
- **C** (uppercase) = Consonants data **present**
- **V** (uppercase) = Vowels data **present**
- **C** (uppercase) = CRM data **present**
- **c** (lowercase) = Consonants data **absent**
- **v** (lowercase) = Vowels data **absent**
- **c** (lowercase) = CRM data **absent**

**Examples:**
- `CI148_CVC_25.11.19.csv` → All three datasets present
- `CI149_cVC_25.11.19.csv` → Only vowels and CRM (no consonants)
- `CI150_Cvc_25.11.19.csv` → Only consonants (no vowels/CRM)

**Date:** Uses file creation date in `yy.mm.dd` format.

---

## Quick Start Guide

### 1. Setup Your Environment

```python
# Required libraries
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from scipy import stats
import statsmodels.api as sm
```

### 2. Configure Data Path

In the notebook, locate the **USER CONFIGURATION** section (Cell 3) and set:

```python
DATA_DIR = "/path/to/your/Data/SubjectID"
```

### 3. Run All Cells

Execute the notebook sequentially. The pipeline will:
- Load all available data files
- Calculate performance metrics
- Generate visualizations
- Compute statistical comparisons

### 4. Generate Subject Aggregates (Optional)

To create merged CSV files for batch analysis:

```python
# Single subject
filename, has_c, has_v, has_crm = create_subject_aggregate('/path/to/Data/CI148')

# All subjects in directory
results_df = aggregate_all_subjects('/path/to/Data/')
```

---

## Theoretical Framework

### Miller-Nicely Phonetic Features

Consonants are decomposed into three binary/categorical acoustic features:

| Feature | Dimension | Values |
|---------|-----------|--------|
| **Voicing** | Binary | 0 = Voiceless (p, t, k, f, s), 1 = Voiced (b, d, g, v, z) |
| **Place of Articulation** | Categorical | 0 = Labial (b, p, m, f, v)<br>1 = Alveolar (d, t, n, s, z)<br>2 = Velar (g, k)<br>3 = Palatal (sh, zh, ch, j) |
| **Manner of Articulation** | Categorical | 0 = Stop (b, p, d, t, g, k)<br>1 = Nasal (m, n)<br>2 = Fricative (f, v, s, z, sh, zh)<br>3 = Affricate (ch, j) |

This framework allows feature-level accuracy analysis beyond simple phoneme accuracy.

**Reference:** Miller, G. A., & Nicely, P. E. (1955). An analysis of perceptual confusions among some English consonants. *JASA*, 27(2), 338-352.

### Adaptive Staircase Method

The CRM task uses a 1-up/1-down adaptive staircase to find the **50% performance threshold**:

**Algorithm (from CRM.m):**
1. Start at initial SNR (e.g., -15 dB)
2. **Correct response** → Decrease SNR by step size (harder)
3. **Incorrect response** → Increase SNR by step size (easier)
4. **Reversal** = Transition point (correct→incorrect or incorrect→correct)
5. **Convergence:** After 4 reversals, reduce step size (e.g., 4 dB → 2 dB)
6. **Threshold:** Mean SNR at reversals 5-14

**Key Metrics:**
- **SRT (Speech Reception Threshold):** Mean reversal SNR (dB)
- **SNR 50% Threshold:** Psychometric function midpoint (50% accuracy)
- **VGRM (Voice Gender Release from Masking):** SRT(Same Gender) - SRT(Different Gender)

**Interpretation:**
- Lower SRT = Better performance (less signal needed)
- Positive VGRM = Benefit from gender cue (easier with different gender maskers)

---

## Data Structure

### Consonants DataFrame

| Column | Description |
|--------|-------------|
| `talker_id` | Talker ID (1-4 in dataset) |
| `target_id` | Target consonant ID (1-16) |
| `response_id` | Subject response ID (1-16) |
| `score` | Correct (1) or incorrect (0) |
| `rt` | Reaction time (seconds) |
| `condition` | Device condition (BM, CI, HA) |
| `target_label` | Consonant label (b, d, f, etc.) |
| `response_label` | Response label |
| `talker_gender` | Talker gender (M/F) |

### Vowels DataFrame

| Column | Description |
|--------|-------------|
| `talker_id` | Talker ID (1-20) |
| `target_id` | Target vowel ID (1-9) |
| `response_id` | Subject response ID (1-9) |
| `score` | Correct (1) or incorrect (0) |
| `rt` | Reaction time (seconds) |
| `condition` | Device condition (BM, CI, HA) |
| `target_label` | Vowel label (AE, AH, AW, etc.) |
| `response_label` | Response label |
| `talker_gender` | **Talker gender from vowels9.m** (M/F) |

**Vowel Talker Gender Mapping:**
- **Male (M):** Talkers 1-10 (M01, M03, M06, M08, M11, M24, M30, M33, M39, M41)
- **Female (F):** Talkers 11-20 (W01, W04, W09, W14, W15, W23, W25, W26, W44, W47)

### CRM DataFrame

| Column | Description |
|--------|-------------|
| `run` | Trial number within run |
| `tc` | Target color (0-3) |
| `rc` | Response color (0-3) |
| `tn` | Target number (0-7) |
| `rn` | Response number (0-7) |
| `snr` | Signal-to-noise ratio (dB) |
| `rt` | Reaction time (seconds) |
| `run_id` | Run identifier (0-10) |
| `condition` | Device condition (BM, CI, HA, Practice) |
| `masker_type` | Same/Diff (talker gender vs masker gender) |
| `gender_config` | Format: "M-MF" (talker-masker1+masker2) |
| `talker_gender` | Target talker gender (M/F, IDs 0-3=M, 4-7=F) |
| `masker_gender` | Masker talker gender |
| `correct` | Both color AND number correct |
| `error_type` | Correct, Color Error, Number Error, Both Error |

### CRM Summary DataFrame

| Column | Description |
|--------|-------------|
| `run_id` | Run identifier |
| `condition` | Device condition |
| `masker_type` | Same/Diff gender |
| `srt` | Speech reception threshold (dB) |
| `srt_sd` | SRT standard deviation |
| **`snr_50_threshold`** | **Primary metric: SNR at 50% accuracy** |
| **`snr_50_sd`** | **SNR 50% standard deviation** |
| `n_reversals` | Number of reversals detected |
| `accuracy` | Overall run accuracy |

---

## Key Analysis Sections

### 1. Phonetic Feature Analysis
- Calculates voicing, place, and manner accuracy
- Compares feature transmission across conditions
- Bootstrap 95% confidence intervals

### 2. Confusion Matrix Analysis
- Shows which phonemes are confused with each other
- Stratified by condition (CI, BM, HA)
- Composite figures for overall patterns

### 3. CRM Performance Metrics
- **SRT Analysis:** Traditional reversal-based threshold
- **SNR 50% Threshold:** MATLAB-exact psychometric midpoint
- VGRM calculation (gender cue benefit)
- Error type stratification (color vs number errors)

### 4. Talker-Specific Performance
- Individual talker accuracy (vowels: 20 talkers)
- Gender aggregate comparisons (male vs female talkers)
- Statistical testing with effect sizes

### 5. Temporal Trends
- Performance changes across trial progression
- Learning/fatigue detection
- Moving average smoothing

### 6. Cumulative Distribution Functions (CDFs)
- Reaction time distributions
- Accuracy distributions by talker/feature
- Error rate distributions
- SNR 50% threshold distributions

---

## Statistical Testing

The pipeline automatically selects appropriate statistical tests:

| Test | Conditions |
|------|-----------|
| **Student's t-test** | Parametric, equal variance |
| **Welch's t-test** | Parametric, unequal variance |
| **Mann-Whitney U** | Non-parametric |
| **One-way ANOVA** | Multiple groups, parametric |
| **Tukey HSD** | Post-hoc pairwise comparisons |

**Normality:** Shapiro-Wilk test (α = 0.05)
**Variance:** Levene's test
**Effect Size:** Cohen's d for t-tests
**Confidence Intervals:** Bootstrap resampling (1000 iterations)

---

## Visualization Standards

- **Figure DPI:** 150 (display), 300 (saved)
- **Figure Size:** 12×6 inches (default)
- **Font Size:** 10pt (body), 12pt (titles)
- **Color Palette:** Seaborn Set2, muted, RdYlGn_r
- **Error Bars:** 95% confidence intervals (bootstrap)

All stratified visualizations include corresponding **composite figures** showing combined data across conditions.

---

## Troubleshooting

### Common Issues

**1. File Not Found Errors**
- Verify `DATA_DIR` path is correct
- Check file naming matches expected patterns (`*cons*.txt`, `*vow*.txt`, `*_crm_*.txt`)

**2. Empty DataFrames**
- Ensure subject folder contains data files
- Check file permissions (read access required)

**3. Reversal Calculation Returns NaN**
- Requires minimum 5 reversals
- Check if adaptive staircase converged properly
- Inspect raw trial data for correct/incorrect patterns

**4. Gender Mapping Issues**
- CRM uses talker IDs 0-7 (0-3=M, 4-7=F)
- Vowels use talker IDs 1-20 (different mapping based on vowels9.m)
- Ensure correct function is used: `get_gender()` for CRM, `get_vowel_talker_gender()` for vowels

---

## Version History

### v4.12 (Current)
- **Added:** Vowel talker gender mapping from vowels9.m (20 talkers)
- **Added:** MATLAB-exact staircase reversal algorithm
- **Added:** SNR 50% threshold calculation (primary metric)
- **Added:** Subject data aggregator with cVC nomenclature
- **Added:** Composite figures for all stratified visualizations
- **Added:** 6 additional CDF analyses
- **Enhanced:** Cross-reference with MATLAB source code (CRM.m, vowels9.m, consonants.m)

### v4.11
- Enhanced analysis pipeline with comprehensive visualizations
- Statistical testing automation
- Bootstrap confidence intervals

### v4.1
- Merged analysis components
- Added Miller-Nicely feature analysis

---

## References

1. **Miller-Nicely Framework:**
   Miller, G. A., & Nicely, P. E. (1955). An analysis of perceptual confusions among some English consonants. *Journal of the Acoustical Society of America*, 27(2), 338-352.

2. **CRM Corpus:**
   Bolia, R. S., Nelson, W. T., Ericson, M. A., & Simpson, B. D. (2000). A speech corpus for multitalker communications research. *JASA*, 107(2), 1065-1066.

3. **Adaptive Staircase:**
   Levitt, H. (1971). Transformed up-down methods in psychoacoustics. *JASA*, 49(2B), 467-477.

---

## Contact & Support

For questions about the analysis pipeline or experimental procedures:
- Review inline documentation in `analysis_v4.12_cc.ipynb`
- Check MATLAB source files (CRM.m, vowels9.m, consonants.m) for algorithm details
- Consult the theoretical framework sections above

**Recommended Citation Format:**
```
Analysis Pipeline v4.12 (2025). Disco Repository.
Auditory perception analysis for cochlear implant and hearing aid research.
```

---

## License

Research code for academic use. See repository for details.
