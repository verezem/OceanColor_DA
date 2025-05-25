import os
import numpy as np
import pandas as pd
import xarray as xr
import glob
import sys

mydir   = str(sys.argv[1])
outdir = mydir
date = str(sys.argv[2])

mems = ['01','02','03','04','05','06','07','08','09','10','11','12','13','14','15','16','17','18','19','20']

# Define file to use
for ii in mems:
    num_mem = ii
    restfile = mydir+f'forecast_restarts/PC0{ii}_y{date[0:4]}m{date[4:6]}d{date[6:8]}.nc'
    beffile = mydir+f'analysis/C0{ii}_Ea_{date}_before.nc'
    
    restdat = xr.open_dataset(restfile, engine='netcdf4')
    befdat = xr.open_dataset(beffile)

    # Now read restart file variables
    old_TRBCDI = restdat.TRBCDI.values
    old_TRBCEM = restdat.TRBCEM.values
    old_TRBCFL = restdat.TRBCFL.values
    old_TRBPOC = restdat.TRBPOC.values
    old_TRBMES = restdat.TRBMES.values
    old_TRBMIC = restdat.TRBMIC.values
    old_TRBGEL = restdat.TRBGEL.values

    # Now read BEFORE variables from analysis
    BCDI = befdat.BCDI.values
    BCEM = befdat.BCEM.values
    BCFL = befdat.BCFL.values
    BPOC = befdat.BPOC.values
    BMES = befdat.BMES.values
    BMIC = befdat.BMIC.values
    BGEL = befdat.BGEL.values

    # Now we can start mixing:
    # We compute 50/50% FOR BEFORE step and 100% for NOW step
    new_TRBCDI = BCDI*0.5 + old_TRBCDI*0.5
    new_TRBCEM = BCEM*0.5 + old_TRBCEM*0.5
    new_TRBCFL = BCFL*0.5 + old_TRBCFL*0.5
    new_TRBPOC = BPOC*0.5 + old_TRBPOC*0.5
    new_TRBMES = BMES*0.5 + old_TRBMES*0.5
    new_TRBMIC = BMIC*0.5 + old_TRBMIC*0.5
    new_TRBGEL = BGEL*0.5 + old_TRBGEL*0.5

    # Mix NOW step
    new_TRNCDI = BCDI
    new_TRNCEM = BCEM
    new_TRNCFL = BCFL
    new_TRNPOC = BPOC
    new_TRNMES = BMES
    new_TRNMIC = BMIC
    new_TRNGEL = BGEL
    
    # Update the dataset
    restdat_updated = restdat.copy()

    restdat_updated['TRBCDI'] = (restdat['TRBCDI'].dims, new_TRBCDI)
    restdat_updated['TRBCEM'] = (restdat['TRBCEM'].dims, new_TRBCEM)
    restdat_updated['TRBCFL'] = (restdat['TRBCFL'].dims, new_TRBCFL)
    restdat_updated['TRBPOC'] = (restdat['TRBPOC'].dims, new_TRBPOC)
    restdat_updated['TRBMES'] = (restdat['TRBMES'].dims, new_TRBMES)
    restdat_updated['TRBMIC'] = (restdat['TRBMIC'].dims, new_TRBMIC)
    restdat_updated['TRBGEL'] = (restdat['TRBGEL'].dims, new_TRBGEL)

    restdat_updated['TRNCDI'] = (restdat['TRNCDI'].dims, new_TRNCDI)
    restdat_updated['TRNCEM'] = (restdat['TRNCEM'].dims, new_TRNCEM)
    restdat_updated['TRNCFL'] = (restdat['TRNCFL'].dims, new_TRNCFL)
    restdat_updated['TRNPOC'] = (restdat['TRNPOC'].dims, new_TRNPOC)
    restdat_updated['TRNMES'] = (restdat['TRNMES'].dims, new_TRNMES)
    restdat_updated['TRNMIC'] = (restdat['TRNMIC'].dims, new_TRNMIC)
    restdat_updated['TRNGEL'] = (restdat['TRNGEL'].dims, new_TRNGEL)

    # Write to a new file
    output_file = mydir + f'analysis_restarts/PC0{ii}_analysed_y{date[0:4]}m{date[4:6]}d{date[6:8]}.nc'
    restdat_updated.to_netcdf(output_file, format='NETCDF4', engine='netcdf4')

    print(f"Updated file saved as {output_file}")
