#!/bin/bash

# === User configuration ===
start_date="20160104"
end_date="20160431"

ASSIM_FREQ=3              # Assimilation every N days
STEPS_PER_DAY=216         # NEMO steps per day
JOBTIME_MIN=$(( ASSIM_FREQ * 1 ))  # ~1 minute per day per ensemble member

ref_date="$start_date"
ref_epoch=$(date -d "$ref_date" +%s)

current_date="$start_date"
while [[ "$current_date" -le "$end_date" ]]; do
    echo "Processing date: $current_date"

    # Compute how many days passed since start
    current_epoch=$(date -d "$current_date" +%s)
    day_diff=$(( (current_epoch - ref_epoch) / 86400 ))

    if (( day_diff % ASSIM_FREQ == 0 )); then
        tstep=$(( ASSIM_FREQ * STEPS_PER_DAY ))
        rstid="$(printf "%08d" $tstep)"  # Format timestep to 8-digit string

        echo "[INFO] Assimilating on $current_date with tstep=$tstep, rstid=$rstid, jobtime=$JOBTIME_MIN min"

        ./submit_ensemble.sh           "$current_date" "$tstep" "$JOBTIME_MIN" "$rstid"
        ./process_and_store.sh         "$current_date" "$rstid" "$ASSIM_FREQ"
        ./preprocess_and_assimilate.sh "$current_date" 
        ./postprocess.sh               "$current_date" "$rstid"

    else
        echo "[INFO] Skipping assimilation on $current_date (ASSIM_FREQ=$ASSIM_FREQ)"
    fi

    current_date=$(date -d "$current_date + 1 day" +"%Y%m%d")
done

echo "[DONE] All dates processed."

