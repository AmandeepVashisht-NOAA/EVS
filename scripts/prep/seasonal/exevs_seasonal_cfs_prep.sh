#!/bin/bash
# Program Name: exevs_seasonal_cfs_prep
# Author(s)/Contact(s): Aman Vashisht
# Abstract: This script is run by JEVS_SEASONAL_PREP in jobs/.
#           This script retrieves data for seasonal CFS verification.

set -x


echo
echo "===== RUNNING EVS SEASONAL CFS PREP  ====="
export STEP="prep"

# Source config
source $config
export err=$?; err_chk

# Set up directories
mkdir -p $STEP
cd $STEP

# Check user's configuration file
python $USHevs/seasonal/check_seasonal_config_cfs_prep.py
export err=$?; err_chk

# Set up environment variables for initialization, valid, and forecast hours and source them
python $USHevs/seasonal/set_init_valid_fhr_seasonal_prep_info.py
export err=$?; err_chk
. $DATA/$STEP/python_gen_env_vars.sh
export err=$?; err_chk

# Retrieve needed data files and set up model information
mkdir -p data
python $USHevs/seasonal/get_cfs_seasonal_data_files_prep.py
export err=$?; err_chk

# Send for missing files
if [ $SENDMAIL = YES ] ; then
    if ls $DATA/mail_* 1> /dev/null 2>&1; then
        for FILE in $DATA/mail_*; do
	    $FILE
        done
    fi
fi
