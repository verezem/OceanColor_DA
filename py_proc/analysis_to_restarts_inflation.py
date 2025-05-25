import xarray as xr
import numpy as np
import os
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

    std_a = np.where(std_a == 0, 1e-12, std_a)  # prevent division by zero
    inflated = mean_a + alpha * (std_f / std_a) * (analysis - mean_a)
    return inflated

def main(use_rtps=False, rtps_alpha=1.0):
    EN_SIZE = 20
    date = os.environ.get("ASSIM_DATE")
    if date is None:
        print("Please set ASSIM_DATE as an environment variable")
        sys.exit(1)

    analysis_files = [f"analysis/C{str(i+1).zfill(3)}_y{date[:4]}m{date[4:6]}d{date[6:]}.nc" for i in range(EN_SIZE)]
    forecast_files = [f"current_day/C{str(i+1).zfill(3)}_y{date[:4]}m{date[4:6]}d{date[6:]}.nc" for i in range(EN_SIZE)]

    analysis_ens = [xr.open_dataset(f) for f in analysis_files]
    forecast_ens = [xr.open_dataset(f) for f in forecast_files]

    variables = ['TRBCDI', 'TRBCEM', 'TRBCFL', 'TRBPOC', 'TRNCDI', 'TRNCEM', 'TRNCFL', 'TRNPOC']  # update as needed

    for var in variables:
        a_stack = np.stack([ds[var].values for ds in analysis_ens])
        f_stack = np.stack([ds[var].values for ds in forecast_ens])

        if use_rtps:
            a_stack = apply_rtps(a_stack, f_stack, alpha=rtps_alpha)

        for i in range(EN_SIZE):
            analysis_ens[i][var].values = a_stack[i]

    for i in range(EN_SIZE):
        outname = f"analysis_restarts/PC{str(i+1).zfill(3)}_y{date[:4]}m{date[4:6]}d{date[6:]}.nc"
        analysis_ens[i].to_netcdf(outname)

if __name__ == "__main__":
    USE_RTPS = os.getenv("USE_RTPS", "False") == "True"
    ALPHA = float(os.getenv("RTPS_ALPHA", "0.8"))
    main(use_rtps=USE_RTPS, rtps_alpha=ALPHA)

