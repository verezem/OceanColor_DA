#!/bin/bash

# main_driver_process_and_store.sh
# This script performs post-processing and storage of ensemble and reference data

if [[ "$1" == "-h" || -z "$1" || -z "$2" || -z "$3" ]]; then
    echo "Usage: $0 YYYYMMDD RSTID ASSIM_FREQ"
    exit 1
fi

date=$1
rstid=$2
ASSIM_FREQ=$3

size=20
y=${date:0:4}
m=${date:4:2}
d=${date:6:2}

# ----------------------------------------------------------------------
echo "Starting to process ensemble runs..."

start_section2=$(date +%s)

for ii in $(eval echo {01..$size}); do 
    cd /scratch/ulg/mast/pverezem/nemo4.2.0/cfgs/BSFS_NEW/ALL_$ii || exit

    #rm -rf ./outputs/*

    echo "Starting rebuild for member $ii"
    for file_type in "" "sto" "trc" "ben"; do
        file_suffix=""
        [ -n "$file_type" ] && file_suffix="_${file_type}"

        namelist_file="nam_rebuild${file_suffix}"
        namelist_ref="ref_nam_rebuild${file_suffix}"

        cp "$namelist_ref" "$namelist_file"
        sed -i -e "s|<RSTID>|${rstid}|g" "$namelist_file"
    done

    rebuild_job_id=$(sbatch --parsable --job-name=rebuild_$ii ./rebuild_job.sh)
    echo "Submitted rebuild job for member $ii with job ID $rebuild_job_id" 

    # Wait until the Slurm job finishes
    echo "Waiting for rebuild job $rebuild_job_id to finish..."
    
    while true; do
        job_state=$(sacct -j "$rebuild_job_id" --format=State --noheader | head -n 1 | awk '{print $1}')
    
        echo "Job state: $job_state"
    
        if [[ "$job_state" == "COMPLETED" ]]; then
            echo "Rebuild job $rebuild_job_id completed successfully."
            break
        elif [[ "$job_state" =~ (FAILED|CANCELLED|TIMEOUT) ]]; then
            echo "Rebuild job $rebuild_job_id failed or was cancelled (state: $job_state)."
            exit 1
        fi
    
        sleep 5
    done

    # Then proceed
    mkdir -p ./restarts ./outputs
    
    mv BS_${rstid}_restart_???.nc ./restarts/
    mv BS_${rstid}_restart.nc ./restarts/
    mv BS_1*_${date}_*.nc ./outputs/ 

    rm slurm-*

    cp ./restarts/BS_${rstid}_restart_trc.nc /scratch/ulg/mast/pverezem/DA_online/forecast_restarts/PC0${ii}_y${y}m${m}d${d}.nc
    cp ./outputs/BS_1h_${y}${m}${d}_*_opti_T_*.nc /scratch/ulg/mast/pverezem/DA_online/reflectances/C0${ii}_y${y}m${m}d${d}.nc

    ASSIM_FREQ_1=$(echo "$3" | tr -d '[:space:]')

    midday=$(( (ASSIM_FREQ_1 - 1) * 24 + 12 ))
    cd /scratch/ulg/mast/pverezem/DA_online/reflectances/
    cdo seltimestep,$midday C0${ii}_y${y}m${m}d${d}.nc C0${ii}_y${y}m${m}d${d}.nc_day
    mv C0${ii}_y${y}m${m}d${d}.nc_day C0${ii}_y${y}m${m}d${d}.nc
    cd -
done

echo "Ensemble post-processing done. Data stored in forecast_restarts dir."
# ----------------------------------------------------------------------

pwd
echo "Starting to process reference run..."

cd /scratch/ulg/mast/pverezem/nemo4.2.0/cfgs/BSFS_NEW/DOMNEW/
for file_type in "" "sto" "trc" "ben"; do
    file_suffix=""
    [ -n "$file_type" ] && file_suffix="_${file_type}"

    namelist_file="nam_rebuild${file_suffix}"
    namelist_ref="ref_nam_rebuild${file_suffix}"

    cp "$namelist_ref" "$namelist_file"
    sed -i -e "s|<RSTID>|${rstid}|g" "$namelist_file"
done


rebuild_job_id=$(sbatch --parsable --job-name=rebuild_ref ./rebuild_job.sh)
echo "Submitted rebuild job for refrun with job ID $rebuild_job_id"

# Wait until the Slurm job finishes
echo "Waiting for rebuild job $rebuild_job_id to finish..."

while true; do
    job_state=$(sacct -j "$rebuild_job_id" --format=State --noheader | head -n 1 | awk '{print $1}')

    echo "Job state: $job_state"

    if [[ "$job_state" == "COMPLETED" ]]; then
        echo "Rebuild job $rebuild_job_id completed successfully."
        break
    elif [[ "$job_state" =~ (FAILED|CANCELLED|TIMEOUT) ]]; then
        echo "Rebuild job $rebuild_job_id failed or was cancelled (state: $job_state)."
        exit 1
    fi

    sleep 5
done


mv BS_${rstid}_restart_???.nc ./restarts/
mv BS_${rstid}_restart.nc ./restarts/
mv BS_1*_${date}_*.nc ./outputs/

rm slurm-*

cp ./outputs/BS_1h_${date}_${y}${m}*_opti_T_*.nc /scratch/ulg/mast/pverezem/DA_online/reflectances/REF_y${y}m${m}d${d}.nc

cd /scratch/ulg/mast/pverezem/DA_online/reflectances/
midday=$(( (ASSIM_FREQ_1 - 1) * 24 + 12 ))
cdo seltimestep,$midday REF_y${y}m${m}d${d}.nc REF_y${y}m${m}d${d}.nc_day
mv REF_y${y}m${m}d${d}.nc_day REF_y${y}m${m}d${d}.nc
cd -

echo "Reference post-processing done. Data stored in reflectances dir."
# ----------------------------------------------------------------------

end_section2=$(date +%s)
echo "Processing restarts elapsed time: $((end_section2 - start_section2)) seconds"

