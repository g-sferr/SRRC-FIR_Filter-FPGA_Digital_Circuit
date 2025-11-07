# SRRC Filter Analysis & Boundary Tests Description

This directory contains two Python scripts developed as part of the project for the *"Electronics & Communications Systems"* course at the **University of Pisa**.  
Both scripts are designed to analyze and verify the behavior of a **Square Root Raised Cosine (SRRC)** filter implemented in hardware (VHDL) through **high-level functional tests** in Python.

These scripts serve as **reference tools** for comparison with hardware simulation results obtained via **ModelSim** testbenches:
- `SRRC_Filter_boundery_tb` → compared with `srrc_boundery_tests.py`
- `SRRC_Filter_waveform_tb` → compared with `srrc_waveform_analysis.py`

---

## Contents

### (1) `srrc_boundery_tests.py`
This script allows testing the **fixed-point implementation** of the SRRC FIR filter in various *boundary* and *limit* conditions (overflow, saturation, etc.).  
It provides both **single input** and **sequence-based** test cases, reproducing the expected arithmetic behavior of the digital filter.

#### How to Run
```bash
python srrc_boundery_tests.py
```

Once executed, a **menu will appear**, allowing you to choose which test to visualize.  
Follow the on-screen prompts to navigate between different test categories.

#### Available Tests

- **Single Input Tests**
  1. All input values = 1  
  2. All input values = -1  
  3. All input values = 2  
  4. All input values = -2  
  5. Maximum positive representable value (+255.9921875)  
  6. Minimum negative representable value (-256.0)

- **Variable Input Sequences**
  7. Increasing sequence (1, 2, 3, …, 23)  
  8. Alternating sequence (-2, 4, -2, 4, …)  
  9. Alternating sequence (-1, -2, -1, -2, …)

Each test prints detailed intermediate results, including:
- Fixed-point (Q-format) representations  
- Binary values (pre/post truncation)  
- Expected real outputs (for comparison with ModelSim)

---

### (2) `srrc_waveform_analysis.py`
This script focuses on **frequency-domain verification** and waveform analysis of the SRRC filter.  
It allows visualizing how the filter responds to different input signals — such as sinusoids and pulse trains — to validate properties like **bandwidth control** and **zero inter-symbol interference (ISI)**.

#### Configuration
Before execution, edit the variable `TEST_MODE` at the beginning of the `test_waveform()` function to select the desired test case:

```python
TEST_MODE = 1  # Change to 1, 2, 3, or 4
```

#### Available Tests

| **1** | Impulse response visualization |
| **2** | Zero-ISI test (alternating +1/-1 pulses every T symbols) |
| **3** | Out-of-band sinusoid (strongly attenuated) — freq = 0.8 / T |
| **4** | In-band sinusoid (low attenuation) — freq = 0.1 / T |

#### How to Run
```bash
python srrc_waveform_analysis.py
```

A plot window will appear showing:
- The **input waveform** (upsampled signal)
- The **SRRC filter output**  
This helps to visually confirm the expected filtering effect.

---

## Notes
- Both scripts were developed in Python 3 and require the following packages:
  ```bash
  pip install numpy matplotlib scipy fxpmath
  ```
- These tools were used to **validate hardware behavior** at a high level and ensure consistency with digital simulation results.
