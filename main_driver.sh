#!/bin/bash

# This is the main driver script for online data assimilation.

# Here we assimilate REF experiment data as observation

# TOOLS:
# NEMO 4.2 model + BAMHBI
# OAK assimilation toolkit

# Check if -h option is provided or no arguments are given
if [[ "$1" == "-h" || -z "$1" || -z "$2" ]]; then
    echo "Usage: ./main_driver.sh YYYYMMDD IIIII"
    echo "  YYYYMMDD : Date in the format YearMonthDay, e.g., 20231010 for October 10, 2023."
    echo "  III    : Restart ID, which should be the timestep at which the last run ended."
    exit 1
fi

date=$1 # first argument is the date in YYYYmmdd format
doy=$(date -d "$date" +%j)
read -r y m d <<< "$(date '+%Y %m %d' -d "$date")"
echo $doy

rstid=$2 # second argument is the ID of restart (namely - timestep at which last run ended
size=20
echo "Month is : ${m}"

start_script=$(date +%s)

# First of all, we submit the whole ensemble for 1 day
# 1 day in BSFS config is 216 time steps (400 steps per day: 86400/400 = 216)

# Go to BSFS_2W directory

start_section1=$(date +%s)

cd /scratch/ulg/mast/pverezem/nemo4.2.0/cfgs/BSFS_2W/

# Don't forget, that we also need to run ref experiment all the time

# Array to store job IDs
job_ids=()

# Loop to submit jobs for each model in directories 01 to 20
for ii in {01..20}; do
    # Navigate to the corresponding directory
    cd ./ALL2017_$ii || exit

    # First set the date for a new run
    cp namelist_cfg_main namelist_cfg
    sed -i -e "s|<RSTID>|${rstid}|g" "namelist_cfg"
    sed -i -e "s|<YYYYMMDD>|${date}|g" "namelist_cfg"

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
cd ./REF2017
 First set the date for a new run
cp namelist_cfg_main namelist_cfg
sed -i -e "s|<RSTID>|${rstid}|g" "namelist_cfg"
sed -i -e "s|<YYYYMMDD>|${date}|g" "namelist_cfg"
job_id=$(sbatch --parsable ./job.sh)
echo "Job $job_id submitted for model REF"
job_ids+=($job_id)
cd -

# Wait for all jobs to complete
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

# ----------------------------------------------------------------------
echo "Starting to process ensemble runs..."

start_section2=$(date +%s)

# Now that all jobs are done, let's process the restarts and (outputs too).
# Post-processing Step - Run for different data types in each of the 20 directories
for ii in {01..20}; do
    # Navigate to the corresponding directory
    cd /scratch/ulg/mast/pverezem/nemo4.2.0/cfgs/BSFS_2W/ALL2017_$ii || exit
    
    echo "Starting post-processing in directory ALL2017_$ii"
    
    # List of file types to process
    file_types=("sto" "trc" "ben" "")  # "" is for no suffix

    # Loop through each file type
    for file_type in "${file_types[@]}"; do
        # Determine the suffix
        if [ -z "$file_type" ]; then
            file_suffix=""  # No suffix if the file_type is empty
        else
            file_suffix="_${file_type}"
        fi
        
        echo "Processing file: $file_name"

        # Modify the namelist file to update the filename
        namelist_file="nam_rebuild${file_suffix}"  # You can use a different namelist for each type if needed

        # Run the post-processing script with the modified namelist
        ./rebuild_nemo.exe "$namelist_file"
        
        echo "Post-processing for $file_name submitted in directory ALL2017_$ii."
    done

    # Move combiined files to DA directory with renaming them
    # Structurize the outputs

    mkdir -p ./restarts
    mkdir -p ./outputs

    # mv combined restarts to dir
    mv BS_00000${rstid}_restart_???.nc ./restarts/
    mv BS_00000${rstid}_restart.nc ./restarts/ 

    # mv outputs away 
    mv BS_1?_*.nc ./outputs/

    # Now remove decomposed restarts
    rm -rf BS_00000${rstid}_restart_trc_????.nc BS_00000${rstid}_restart_sto_????.nc BS_00000${rstid}_restart_ben_????.nc BS_00000${rstid}_restart_????.nc

    # Copy the trc restart to the DA forecast data
    cp ./restarts/BS_00000${rstid}_restart_trc.nc /scratch/ulg/mast/pverezem/DA_online/forecast_restarts/PC0${ii}_y${y}m${m}d${d}.nc
    # Copy reflectances to the corresponding directory in DA_online:
    cp ./outputs/BS_1h_${y}${m}${d}_${y}${m}${d}_opti_T_*.nc /scratch/ulg/mast/pverezem/DA_online/reflectances/C0${ii}_y${y}m${m}d${d}.nc

    # Before we go let's get only 12h reflectances:
    cd /scratch/ulg/mast/pverezem/DA_online/reflectances/
    ncks -d time_counter,12  C0${ii}_y${y}m${m}d${d}.nc C0${ii}_y${y}m${m}d${d}.nc_day
    mv C0${ii}_y${y}m${m}d${d}.nc_day C0${ii}_y${y}m${m}d${d}.nc
    cd -

done

end_section2=$(date +%s)
echo "Processing restarts elapsed time: $((end_section2 - start_section2)) seconds"

echo "Ensemble post-processing done. Data stored in forecast_restarts dir."
# ----------------------------------------------------------------------

# Print local durectory
pwd

echo "Starting to process reference run..."

# ------------- Recombine reference experiment data too ----------------
cd /scratch/ulg/mast/pverezem/nemo4.2.0/cfgs/BSFS_2W/REF2017/

./rebuild_nemo.exe nam_rebuild
./rebuild_nemo.exe nam_rebuild_trc
./rebuild_nemo.exe nam_rebuild_ben

# And store it

mv BS_000?????_restart_???.nc ./restarts/
mv BS_000?????_restart.nc ./restarts/
mv BS_1?_*.nc ./outputs/

# Remove decoomposed restarts
rm -rf BS_000?????_restart_trc_????.nc BS_000?????_restart_ben_????.nc BS_000?????_restart_????.nc

# Ensure that we are in the main DA_online directory
cd /scratch/ulg/mast/pverezem/DA_online/

# Copy reference reflectances
cp /scratch/ulg/mast/pverezem/nemo4.2.0/cfgs/BSFS_2W/REF2017/outputs/BS_1h_${date}_${date}_opti_T_*.nc ./reflectances/REF_y${y}m${m}d${d}.nc
cd /scratch/ulg/mast/pverezem/DA_online/reflectances/
ncks -d time_counter,12 REF_y${y}m${m}d${d}.nc REF_y${y}m${m}d${d}.nc_day
mv REF_y${y}m${m}d${d}.nc_day REF_y${y}m${m}d${d}.nc
cd -

echo "Reference post-processing done. Data stored in reflectances dir."
# ----------------------------------------------------------------------

start_section3=$(date +%s)

echo "Start data preprocessing for DA."

# Clean the directory just in case
cd /scratch/ulg/mast/pverezem/DA_online/current_day
rm -rf ./*${y}*.nc *.tmp *.swp slurm* assim.2017${m}* *log*

echo "Get reference experiment data as observations"
cp ../reflectances/REF_y${y}m${m}d${d}.nc ./REF_y${y}m${m}d${d}.nc
python /scratch/ulg/mast/pverezem/DEV/programs/online_ref_fillval.py $date ./
ncatted -a _FillValue,,o,f,-999 REF_y${y}m${m}d${d}_refl.nc

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

    echo "Assimilation done! now we can prepare data for the model."


end_section3=$(date +%s)
echo "Data assimilation elapsed time: $((end_section3 - start_section3)) seconds"
# ------------------------------------------------------------------------
# Process ananlysis carefully

cd /scratch/ulg/mast/pverezem/DA_online/analysis/
for ii in {01..20} ; do
	ncks -A -v RRS412,RRS443,RRS490,RRS510,RRS555,RRS670 ${date}_Ea_C0${ii}.nc C0${ii}_Ea_${date}_reflectances.nc
	ncks -A -v BCDI,BCEM,BCFL,BPOC ${date}_Ea_C0${ii}.nc C0${ii}_Ea_${date}_before.nc
        ncks -A -v NCDI,NCEM,NCFL,NPOC ${date}_Ea_C0${ii}.nc C0${ii}_Ea_${date}_now.nc
done

cd ../

echo 'Start mixing the analysis to restarts'
python /scratch/ulg/mast/pverezem/DEV/programs/analysis_to_restarts.py /scratch/ulg/mast/pverezem/DA_online/ $date

# ------------------------------------------------------------------------
# Now we put analysed values back to restarts

cd /scratch/ulg/mast/pverezem/nemo4.2.0/cfgs/BSFS_2W/
for ii in {01..20} ; do
        cp /scratch/ulg/mast/pverezem/DA_online/analysis_restarts/PC0${ii}_analysed_y${y}m${m}d${d}.nc ./ALL2017_${ii}/restarts/BS_00000${rstid}_restart_trc.nc
done

# ------------------------------------------------------------------------
# We are ready to run the model again! 
echo "We are ready to run the model again!"

end_script=$(date +%s)
echo "Total script execution time: $((end_script - start_script)) seconds"
