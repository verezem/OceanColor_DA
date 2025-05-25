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

## 🔄 What the Package Does

This package automates the workflow of ocean color data assimilation using an ensemble forecasting system. The following components perform key stages in the assimilation loop:

- **`submit_ensemble.sh`**  
  Automatically sets the correct restart ID and simulation length based on your `submit_year.sh` setup. It modifies the relevant NEMO configuration files (`namelists`, `job.sh`, and `rebuild_job.sh`), then submits SLURM jobs for all ensemble members and the deterministic reference run. Once all jobs complete, it reports successful execution.

- **`process_and_store.sh`**  
  Rebuilds ensemble restart files and organizes outputs into the correct folders, preparing the model state for assimilation.

- **`preprocess_and_assimilate.sh`**  
  Updates assimilation-specific namelists for the given forecast date, converts data to use OAK-compatible `_FillValue` conventions, and submits the data assimilation job — waiting for completion before proceeding.

- **`postprocess.sh`**  
  Integrates the assimilated fields back into the restart files and distributes them to each ensemble member’s input folders for the next forecast cycle.

### 📌 RTPS Inflation Support

To apply **RTPS (Relaxation to Prior Spread)** inflation, use the alternative script `analysis_to_restarts_inflation.py` inside `postprocess.sh`, instead of the default `analysis_to_restarts.py`.

---

## 🚀 Quick Start

1. **Set simulation period and ensemble size:**

   Edit `submit_year.sh` to specify the `start_date`, `end_date`, and number of ensemble members.

2. **Prepare for a clean start:**

   If this is **not your first run**, clear previous outputs by running:
   ```bash
   rm -r ./analysis/*.nc ./analysis_restarts/*.nc ./reflectances/*.nc 
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

## 🧰 System Requirements

OceanColor_DA requires a combination of compiled models and Python tools. Below is a summary of the essential components for running the full workflow.

### 🔧 Compilers and MPI

- **MPI-enabled Fortran compiler** – for NEMO and OAK  
  _(e.g., `mpif90`, `gfortran`, `ifort`)_

- **MPI-enabled C compiler** – for C-based dependencies  
  _(e.g., `mpicc`)_

### 🌿 OAK Toolkit

OceanColor_DA relies on the [OAK toolkit](https://github.com/gher-uliege/OAK) for ensemble data assimilation.

Please refer to the [official OAK GitHub repository](https://github.com/gher-uliege/OAK) for installation instructions, documentation, and source code.

> 📦 Note: You will need to compile OAK manually and ensure it is available in your `$PATH` or properly referenced in your scripts.


### 📦 Libraries and Tools

- **NetCDF-Fortran** ≥ 4.5  
- **NetCDF-C** and **HDF5** (automatically pulled with NetCDF)
- **SuiteSparse** – sparse matrix solvers required by OAK
- **Boost** ≥ 1.74 – utilities for OAK or NEMO modules
- **Perl** – scripting support in model components
- **CDO** – for NetCDF field operations
- **NCO** – used in NetCDF data manipulation and metadata editing

### 🐍 Python Dependencies

The Python-based postprocessing and diagnostics require:

```txt
xarray
numpy
pandas
netCDF4
glob2
matplotlib
```

You can install these with:

```bash
pip install -r requirements.txt
```

Or create a `conda` environment:

```bash
conda create -n oceancolor_da python=3.10 xarray numpy pandas netCDF4 glob2 matplotlib
```

### 📌 Example Module Setup (ULg NIC5 system)

```bash
module load releases/2020b
module load netCDF-Fortran/4.5.3-gompi-2020b
module load SuiteSparse
module load Perl/5.32.0-GCCcore-10.2.0
module load Boost/1.74.0-GCC-10.2.0
module load CDO

export FC=mpif90
export F77=mpif90
export CC=mpicc
```

---

## 📊 Monitoring Progress

- **Check the ensemble state for each day:**
  ```bash
  tail -f ./current_day/assim_<date>.log-000XX
  ```
  (where `000XX` corresponds to the core ID)

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

