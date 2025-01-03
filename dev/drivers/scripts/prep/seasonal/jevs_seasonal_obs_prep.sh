#PBS -N jevs_seasonal_obs_prep
#PBS -j oe 
#PBS -S /bin/bash
#PBS -q "dev"
#PBS -A VERF-DEV
#PBS -l walltime=00:10:00
#PBS -l place=shared,select=1:ncpus=1:mem=5GB
#PBS -l debug=true

set -x

export model=evs

cd $PBS_O_WORKDIR

export HOMEevs=/lfs/h2/emc/vpppg/noscrub/$USER/feature_seasonal_sst

source $HOMEevs/versions/run.ver
module reset
module load prod_envir/${prod_envir_ver}
source $HOMEevs/dev/modulefiles/seasonal/seasonal_prep.sh

evs_ver_2d=$(echo $evs_ver | cut -d'.' -f1-2)

export envir=prod
export DATAROOT=/lfs/h2/emc/stmp/$USER/evs_test/$envir/tmp
export job=${PBS_JOBNAME:-jevs_seasonal_obs_prep}
export jobid=$job.${PBS_JOBID:-$$}
export TMPDIR=$DATAROOT
export SITE=$(cat /etc/cluster_name)
export KEEPDATA=YES
export SENDMAIL=YES

export MAILTO='lydia.b.stefanova@noaa.gov,amandeep.vashisht@noaa.gov'

export USER=$USER
export ACCOUNT=VERF-DEV
export QUEUE=dev
export QUEUESHARED=dev_shared
export QUEUESERV=dev_transfer
export PARTITION_BATCH=
export nproc=1
export WGRIB2=`which wgrib2`
export vhr=00
export NET=evs
export STEP=prep
export COMPONENT=seasonal
export RUN=atmos
export OBSNAME="ghrsst"
#export gfs_ver=${gfs_ver}
#export obsproc_ver=${obsproc_ver}
#export ccpa_ver=${ccpa_ver}
export PREP_TYPE=obs

export COMIN=/lfs/emc/vpppg/noscrub/$USER/data_archive
export COMOUT=/lfs/h2/emc/vpppg/noscrub/$USER/$NET/${evs_ver_2d}/$STEP/$COMPONENT/$RUN

export config=$HOMEevs/parm/evs_config/seasonal/config.evs.seasonal.obs.prep

# Call executable job script
$HOMEevs/jobs/JEVS_SEASONAL_PREP


######################################################################
# Purpose: The job and task scripts work together to retrieve the
#          subseasonal data files for obs 
#          and copy into the prep directory.
######################################################################
