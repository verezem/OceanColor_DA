# 🌊 OceanColor_DA

**OceanColor_DA** is a data assimilation framework built around the **NEMO 4.2 ocean model**, enhanced with the **BAMHBI biogeochemical module**, **RADTRANS optics**, and the **OAK data assimilation toolkit**. It enables online assimilation of ocean color data in an ensemble forecasting setup.

---

## 📦 Contents

- `submit_year.sh`: Main driver script to launch a year-long assimilation sequence.
- `copy_restarts.sh`: Utility to copy the initial restart files from a prepared reference state.
- Folders:
  - `./analysis`: Stores assimilated fields.
  - `./analysis_restarts`: Restart files post-assimilation.
  - `./reflectances`: Stores reflectance outputs.
  - `./current_day`: Daily working directory for data preprocessing and assimilation.

---

## 🚀 Quick Start

1. **Set simulation period and ensemble size:**

   Edit `submit_year.sh` to specify the `start_date`, `end_date`, and number of ensemble members.

2. **Prepare for a clean start:**

   If this is **not your first run**, clear previous outputs by running:
   ```bash
   rm -r ./analysis ./analysis_restarts ./reflectances
   ```

3. **(Optional) Initialize from reference state:**

   If starting from `2016-01-01`, initialize restarts by running in the NEMO config directory:
   ```bash
   cd /scratch/ulg/mast/pverezem/nemo4.2.0/cfgs/BSFS_NEW
   bsn && ./copy_restarts.sh
   ```

4. **Launch assimilation:**
   Run the full workflow in the background:
   ```bash
   ./submit_year.sh >& log.run &
   ```

---

## 🔧 System Requirements

### Software Setup

- **NEMO 4.2 + BAMHBI + RADTRANS** (compiled in `releases/2020b`)
- **OAK** assimilation toolkit
- **Python + xarray + NCO/CDO** tools (provided by `releases/2023b`)

> 📌 Module setup:
> - Load `releases/2023b` for preprocessing and OAK-related tasks
> - `releases/2020b` is loaded automatically within SBATCH jobs for NEMO execution

---

## 📊 Monitoring Progress

- **Check the ensemble state for each day:**
  ```bash
  tail -f ./current_day/assim_date.log-000XX
  ```
  (where `000XX` corresponds to the ensemble member index)

- **Track the main workflow:**
  ```bash
  tail -f log.run
  ```

---

## 🧩 Requirements

- ✅ Functional **NEMO+BAMHBI+RADTRANS** model setup
- ✅ Prepared **reference run** (DOMNEW)
- ✅ Ensemble directory tree (`ALL_XX/outputs`)

---

## 📁 Example Directory Structure

```
OceanColor_DA/
├── submit_year.sh
├── copy_restarts.sh
├── analysis/
├── analysis_restarts/
├── reflectances/
├── current_day/
├── log.run
└── ...
```

---

📬 **For support or contributions**, feel free to open an issue or pull request!

