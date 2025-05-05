#!/bin/bash

# ================================
# SUBMIT ENSEMBLE + REF EXPERIMENT
# ================================

# Usage: ./submit_ensemble.sh YYYYMMDD RSTID TIMESTEP JOBTIME_MIN

if [[ "$1" == "-h" || -z "$1" || -z "$2" || -z "$3" || -z "$4" ]]; then
    echo "Usage: ./submit_ensemble.sh YYYYMMDD TIMESTEP JOBTIME_MIN RSTID"
    exit 1
fi

date=$1
tstep=$2
JOBTIME_MIN=$3
rstid=$4

size=20
y=${date:0:4}
m=${date:4:2}
d=${date:6:2}
echo "Month is : ${m}"

# ================================
# Don't forget, that we also need to run ref experiment all the time
# ================================

cd /scratch/ulg/mast/pverezem/nemo4.2.0/cfgs/BSFS_NEW/

# Array to store job IDs
job_ids=()

# Loop to submit jobs for each model in directories 01 to 20
for ii in $(eval echo {01..$size}); do
    # Navigate to the corresponding directory
    cd ./ALL_$ii || exit
    rm -rf BS_*.nc slurm-*

    # First set the date for a new run
    cp namelist_cfg_main namelist_cfg
    sed -i -e "s|<ENDTS>|${tstep}|g" "namelist_cfg"
    sed -i -e "s|<RSTID>|${rstid}|g" "namelist_cfg"
    sed -i -e "s|<YYYYMMDD>|${date}|g" "namelist_cfg"

    # Convert minutes to HH:MM:SS
    HOURS=$(( JOBTIME_MIN / 60 ))
    MINS=$(( JOBTIME_MIN % 60 ))
    TIME_STRING=$(printf "%d:%02d:00" $HOURS $MINS)
    echo $TIME_STRING

    # Replace the old --time= line in job.sh with new value
    sed -i "s/--time=[0-9:]\+/--time=$TIME_STRING/" job.sh

    # Submit the job script and capture the job ID
    job_id=$(sbatch --parsable ./job.sh)

    # Print the job ID
    echo "Job $job_id submitted for model $ii"

    # Store the job ID in the array
    job_ids+=($job_id)

    # Go back to the original directory
    cd -
done

# Now run the reference experiment
cd ./DOMNEW || exit

# First set the date for a new run
cp namelist_cfg_main namelist_cfg
sed -i -e "s|<RSTID>|${rstid}|g" "namelist_cfg"
sed -i -e "s|<ENDTS>|${tstep}|g" "namelist_cfg"
sed -i -e "s|<YYYYMMDD>|${date}|g" "namelist_cfg"

sed -i "s/--time=[0-9:]\+/--time=$TIME_STRING/" job.sh

# Submit job for REF
job_id=$(sbatch --parsable ./job.sh)
echo "Job $job_id submitted for model REF"
job_ids+=($job_id)

cd -

# ================================
# Wait for all jobs to complete
# ================================

dependency_string=$(printf "afterok:%s," "${job_ids[@]}")
dependency_string=${dependency_string::-1}  # Remove trailing comma

echo "All jobs have been submitted. Monitoring their status..."

# Wait and check each job until they all finish
while true; do
    all_done=true
    echo "Checking job statuses at $(date):"

    for job_id in "${job_ids[@]}"; do
        # Get the job state for each job and trim whitespaces
        job_state=$(sacct -j "$job_id" --format=State --noheader | head -n 1 | xargs)
        echo "Job $job_id: $job_state"

        if [[ "$job_state" == "COMPLETED" ]]; then
            echo "Job $job_id: COMPLETED"
        elif [[ "$job_state" == "FAILED" || "$job_state" == "CANCELLED" ]]; then
            echo "Job $job_id: $job_state (Job failed or cancelled)"
            all_done=false
        else
            echo "Job $job_id: $job_state (Still running or pending)"
            all_done=false
        fi
    done

    if $all_done; then
        echo "All jobs are completed."
        break
    else
        echo "Some jobs are still running or pending. Waiting for 60 seconds..."
        sleep 60  # Wait for a minute before checking again
    fi
done

end_section1=$(date +%s)
echo "Ensemble elapsed time: $((end_section1 - start_section1)) seconds"

