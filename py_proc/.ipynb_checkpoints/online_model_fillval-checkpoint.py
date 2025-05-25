import os
import numpy as np
import pandas as pd
import xarray as xr
import glob
import sys

mydir   = str(sys.argv[1])
outdir = mydir

date = str(sys.argv[2])

# Define file to use
string = f'C0*_y{date[0:4]}m{date[4:6]}d{date[6:8]}.nc'
filelist = []
filelist += glob.glob(mydir+ os.sep +string)
filelist.sort()
print(filelist)

for ii,file in enumerate(filelist):
    print(file)
    ds = xr.open_dataset(file)
    rrs412 = ds.RRS_412nm.values
    rrs443 = ds.RRS_443nm.values
    rrs490 = ds.RRS_490nm.values
    rrs510 = ds.RRS_510nm.values
    rrs555 = ds.RRS_555nm.values
    rrs670 = ds.RRS_670nm.values
    eu490 = ds.Eu_490nm.values
    ed490 = ds.Ed_490nm.values
    es490 = ds.Es_490nm.values
    PAR = ds.PAR.values
    lat = ds.nav_lat.values
    lon = ds.nav_lon.values
    dep = ds.deptht.values
    rrs412 = np.nan_to_num(rrs412, nan=-999.)
    rrs443 = np.nan_to_num(rrs443, nan=-999.)
    rrs490 = np.nan_to_num(rrs490, nan=-999.)
    rrs510 = np.nan_to_num(rrs510, nan=-999.)
    rrs555 = np.nan_to_num(rrs555, nan=-999.)
    rrs670 = np.nan_to_num(rrs670, nan=-999.)
    eu490 = np.nan_to_num(eu490, nan=-999.)
    ed490 = np.nan_to_num(ed490, nan=-999.)
    es490 = np.nan_to_num(es490, nan=-999.)
    PAR = np.nan_to_num(PAR, nan=-999.)
    # right netcdf
    df = xr.Dataset()
    coords2d = ('y', 'x')
    coords3d = ('z', 'y', 'x')
    df['RRS_412nm'] = (coords2d,rrs412[0])
    df['RRS_443nm'] = (coords2d,rrs443[0])
    df['RRS_490nm'] = (coords2d,rrs490[0])
    df['RRS_510nm'] = (coords2d,rrs510[0])
    df['RRS_555nm'] = (coords2d,rrs555[0])
    df['RRS_670nm'] = (coords2d,rrs670[0])
    df['Eu_490nm'] = (coords3d,eu490[0])
    df['Ed_490nm'] = (coords3d,ed490[0])
    df['Es_490nm'] = (coords3d,es490[0])
    df['PAR'] = (coords3d,PAR[0])
    df['nav_lon'] = (coords2d, lon)
    df['nav_lat'] = (coords2d, lat)
    df['deptht'] = ('z', dep)
    if len(str(ii+1)) == 1:
        ens_num = '0'+str(ii+1)
    else:
        ens_num = str(ii+1)
    df.to_netcdf(f'C0{ens_num}_y{date[0:4]}m{date[4:6]}d{date[6:8]}_refl.nc')
