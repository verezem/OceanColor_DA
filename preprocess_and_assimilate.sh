#!/bin/bash

# ----------------------------------------------------------------------
# main_driver_assimilate.sh
# Assimilation preprocessing and launching the OAK system
# ----------------------------------------------------------------------

if [[ "$1" == "-h" || -z "$1" ]]; then
    echo "Usage: $0 YYYYMMDD"
    exit 1
fi

date=$1
y=${date:0:4}
m=${date:4:2}
d=${date:6:2}
size=20

start_section3=$(date +%s)

echo "Start data preprocessing for DA."

cd /scratch/ulg/mast/pverezem/DA_online/current_day

# Clean the directory just in case
rm -rf ./*${y}*.nc *.tmp *.swp slurm* assim.${y}${m}* *log*

echo "Get reference experiment data as observations"
cp ../reflectances/REF_y${y}m${m}d${d}.nc ./REF_y${y}m${m}d${d}.nc
python /scratch/ulg/mast/pverezem/DEV/programs/online_ref_fillval.py $date ./
ncatted -a _FillValue,,o,f,-999 REF_y${y}m${m}d${d}_refl.nc

mv REF_y${y}m${m}d${d}_refl.nc REF_y${y}m${m}d${d}.nc

cp REF_stds_${m}.nc REF_stds.nc

# Now get the model data
echo "Copy model data to current day dir"

cp ../forecast_restarts/PC0??_y${y}m${m}d${d}.nc ./
cp ../reflectances/C0??_y${y}m${m}d${d}.nc ./

echo "Change fill value with python online_model_fillval.py"
python /scratch/ulg/mast/pverezem/DEV/programs/online_ptrc_fillval.py ./ ${date}
python /scratch/ulg/mast/pverezem/DEV/programs/online_model_fillval.py ./ ${date}

for num in $(eval echo {01..$size}); do
    ncatted -a _FillValue,,o,f,-999 PC0${num}_y${y}m${m}d${d}_fill.nc
    ncatted -a _FillValue,,o,f,-999 C0${num}_y${y}m${m}d${d}_refl.nc
    mv PC0${num}_y${y}m${m}d${d}_fill.nc PC0${num}_y${y}m${m}d${d}.nc
    mv C0${num}_y${y}m${m}d${d}_refl.nc C0${num}_y${y}m${m}d${d}.nc
done

# ------------------------------------------------------------------------
# Setting the namelist for OAK

echo 'Rewrite assimilation namelist'
echo '${y}-${m}-${d}T11:30:00.00'

cp assim.date assim.${date}
echo 'assim.${date}'

sed -i -e "s|<DATETIME>|${y}-${m}-${d}T11:30:00.00|g" -e "s|<DATE>|${y}${m}${d}|g" "assim.${date}"
sed -i -e "s|<DRADATE>|y${y}m${m}d${d}|g" "assim.${date}"

echo 'We are ready! Lets start the assimilation!'

# ------------------------------------------------------------------------
# Sbatch the assimilation job to server and wait :)

job_id=$(sbatch --parsable ./job.sh ${date})
echo "Submitted job for ${date} with job ID $job_id"

# Wait for the last job of the month to finish before proceeding to the next month
echo "Waiting for the job ($job_id) to complete..."
while squeue -u $USER | grep -q "$job_id"; do
    sleep 60  # Check every 60 seconds
done

echo "Assimilation done! Now we can prepare data for the model."

end_section3=$(date +%s)
echo "Data assimilation elapsed time: $((end_section3 - start_section3)) seconds"

