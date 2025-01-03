#!/bin/bash
# Program Name: exevs_seasonal_obs_prep
# Author(s)/Contact(s): Aman Vashisht
# Abstract: This script is run by JEVS_SEASONAL_PREP in jobs/.
#           This script retrieves data for seasonal observations.

set -x


echo
echo "===== RUNNING EVS SEASONAL OBS PREP  ====="
export STEP="prep"

# Source config?(subseaosonal sources evs_config in parm)

# Set up directories
mkdir -p $STEP
cd $STEP

# Run prep work for obs
echo "WORKING"
mkdir -p data
python ${USHevs}/seasonal/seasonal_prep_obs.py
export err=$?; err_chk

# Send for missing files
if [ $SENDMAIL = YES ] ; then
    if ls $DATA/mail_* 1> /dev/null 2>&1; then
        for FILE in $DATA/mail_*; do
            $FILE
        done
    fi
fi
