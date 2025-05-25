import os
import numpy as np
import xarray as xr
import sys

def apply_rtps(analysis, forecast, alpha=1.0):
    """
    Apply RTPS inflation to analysis data.
    analysis: ndarray (N, ...)
    forecast: ndarray (N, ...)
    """
    mean_a = np.nanmean(analysis, axis=0)
    std_a = np.nanstd(analysis, axis=0)
    std_f = np.nanstd(forecast, axis=0)

    std_a = np.where(std_a == 0, 1e-12, std_a)
    inflated = mean_a + alpha * (std_f / std_a) * (analysis - mean_a)
    return inflated

# --- CONFIG ---
mydir = str(sys.argv[1])
date = str(sys.argv[2])
outdir = mydir
mems = [f"{i:02d}" for i in range(1, 21)]
alpha = float(os.getenv("RTPS_ALPHA", "0.8"))

# Variables
BEFORE_VARS = ['BCDI', 'BCEM', 'BCFL', 'BPOC', 'BMES', 'BMIC', 'BGEL']
TRB_VARS = ['TRBCDI', 'TRBCEM', 'TRBCFL', 'TRBPOC', 'TRBMES', 'TRBMIC', 'TRBGEL']
TRN_VARS = ['TRNCDI', 'TRNCEM', 'TRNCFL', 'TRNPOC', 'TRNMES', 'TRNMIC', 'TRNGEL']

# --- Load ensembles ---
before_ens = []
forecast_ens = []

for ii in mems:
    beffile = os.path.join(mydir, f'analysis/C0{ii}_Ea_{date}_before.nc')
    restfile = os.path.join(mydir, f'forecast_restarts/PC0{ii}_y{date[:4]}m{date[4:6]}d{date[6:]}.nc')
    before_ens.append(xr.open_dataset(beffile))
    forecast_ens.append(xr.open_dataset(restfile))

# --- Apply RTPS ---
inflated = {}

for var_bef, var_rest in zip(BEFORE_VARS, TRB_VARS):  # Only apply to background variables
    analysis_stack = np.stack([ds[var_bef].values for ds in before_ens])
    forecast_stack = np.stack([ds[var_rest].values for ds in forecast_ens])
    inflated[var_bef] = apply_rtps(analysis_stack, forecast_stack, alpha)

# --- Write mixed outputs ---
for idx, ii in enumerate(mems):
    restdat = forecast_ens[idx]
    befdat = before_ens[idx]
    restdat_updated = restdat.copy()

    # Mixed: 50% inflated background + 50% forecast
    for var_bef, var_rest, newname in zip(BEFORE_VARS, TRB_VARS, TRB_VARS):
        mixed = 0.5 * inflated[var_bef][idx] + 0.5 * restdat[var_rest].values
        restdat_updated[newname] = (restdat[var_rest].dims, mixed)

    # NOW state: 100% inflated analysis
    for var_bef, newname in zip(BEFORE_VARS, TRN_VARS):
        restdat_updated[newname] = (restdat[newname].dims, inflated[var_bef][idx])

    outname = os.path.join(mydir, f'analysis_restarts/PC0{ii}_analysed_y{date[:4]}m{date[4:6]}d{date[6:]}.nc')
    restdat_updated.to_netcdf(outname, format='NETCDF4', engine='netcdf4')
    print(f"✅ Updated and saved {outname}")

