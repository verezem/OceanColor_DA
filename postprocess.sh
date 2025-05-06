#!/bin/bash

# ----------------------------------------------------------------------
# main_driver_finalize.sh
# Post-assimilation analysis processing and injection into restart files
# ----------------------------------------------------------------------

if [[ "$1" == "-h" || -z "$1"  || -z "$2" ]]; then
    echo "Usage: $0 YYYYMMDD RSTID"
    exit 1
fi

date=$1
rstid=$2
y=${date:0:4}
m=${date:4:2}
d=${date:6:2}

# Process analysis carefully

cd /scratch/ulg/mast/pverezem/DA_online/analysis/
for ii in {01..20} ; do
    ncks -A -v RRS412,RRS443,RRS490,RRS510,RRS555,RRS670 ${date}_Ea_C0${ii}.nc C0${ii}_Ea_${date}_reflectances.nc
    ncks -A -v BCDI,BCEM,BCFL,BPOC ${date}_Ea_C0${ii}.nc C0${ii}_Ea_${date}_before.nc
    ncks -A -v NCDI,NCEM,NCFL,NPOC ${date}_Ea_C0${ii}.nc C0${ii}_Ea_${date}_now.nc
done

rm yo_* xf_*

cd ../

echo 'Start mixing the analysis to restarts'
python /scratch/ulg/mast/pverezem/DA_online/py_proc/analysis_to_restarts.py /scratch/ulg/mast/pverezem/DA_online/ $date

# ------------------------------------------------------------------------
# Now we put analysed values back to restarts

cd /scratch/ulg/mast/pverezem/nemo4.2.0/cfgs/BSFS_NEW/
for ii in {01..20} ; do
    cp /scratch/ulg/mast/pverezem/DA_online/analysis_restarts/PC0${ii}_analysed_y${y}m${m}d${d}.nc ./ALL_${ii}/restarts/BS_${rstid}_restart_trc.nc
done

# ------------------------------------------------------------------------
# We are ready to run the model again! 
echo "We are ready to run the model again!"

