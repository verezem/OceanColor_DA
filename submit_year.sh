#!/bin/bash

# Array of months to run

start_date="20170109"
end_date="20170430"

current_date="$start_date"
while [[ "$current_date" -le "$end_date" ]]; do
    echo "Processing date: $current_date"
    ./main_driver.sh $current_date 216 >& log.${current_date} 
    current_date=$(date -d "$current_date + 1 day" +"%Y%m%d")
done

echo "All dates processed."
