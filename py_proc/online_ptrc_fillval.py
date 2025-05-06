import os
import numpy as np
# import pandas as pd
import xarray as xr
import glob
import sys

mydir   = str(sys.argv[1])
outdir = mydir

date = str(sys.argv[2])

# Define file to use
string = f'PC0*_y{date[0:4]}m{date[4:6]}d{date[6:8]}.nc'
filelist = []
filelist += glob.glob(mydir+ os.sep +string)
filelist.sort()
print(filelist)

for ii,file in enumerate(filelist):
    print(file)
    ds = xr.open_dataset(file, engine='netcdf4')
    BCDI = ds.TRBCDI.values # B means "before"
    BCEM = ds.TRBCEM.values # B means "before"
    BCFL = ds.TRBCFL.values # B means "before"
    NCDI = ds.TRNCDI.values # N means "now"
    NCEM = ds.TRNCEM.values # N means "now"
    NCFL = ds.TRNCFL.values # N means "now"
    BPOC = ds.TRBPOC.values
    NPOC = ds.TRNPOC.values
    lat = ds.y.values
    lon = ds.x.values
    dep = ds.nav_lev.values
    BCDI = np.nan_to_num(BCDI, nan=-999.)
    BCEM = np.nan_to_num(BCEM, nan=-999.)
    BCFL = np.nan_to_num(BCFL, nan=-999.)
    NCDI = np.nan_to_num(NCDI, nan=-999.)
    NCEM = np.nan_to_num(NCEM, nan=-999.)
    NCFL = np.nan_to_num(NCFL, nan=-999.)
    BPOC = np.nan_to_num(BPOC, nan=-999.)
    NPOC = np.nan_to_num(NPOC, nan=-999.)
    # right netcdf
    df = xr.Dataset()
    coords2d = ('y', 'x')
    coords3d = ('z', 'y', 'x')
    df['BCDI'] = (coords3d,BCDI[0])
    df['BCEM'] = (coords3d,BCEM[0])
    df['BCFL'] = (coords3d,BCFL[0])
    df['NCDI'] = (coords3d,NCDI[0])
    df['NCEM'] = (coords3d,NCEM[0])
    df['NCFL'] = (coords3d,NCFL[0])
    df['BPOC'] = (coords3d,BPOC[0])
    df['NPOC'] = (coords3d,NPOC[0])
    df['nav_lon'] = (coords2d, lon)
    df['nav_lat'] = (coords2d, lat)
    df['deptht'] = ('z', dep)
    if len(str(ii+1)) == 1:
        ens_num = '0'+str(ii+1)
    else:
        ens_num = str(ii+1)
    df.to_netcdf(f'PC0{ens_num}_y{date[0:4]}m{date[4:6]}d{date[6:8]}_fill.nc')
