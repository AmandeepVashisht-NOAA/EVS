#PBS -N jevs_global_ens_chem_g2o_prep
#PBS -j oe
#PBS -S /bin/bash
#PBS -q dev
#PBS -A VERF-DEV
#PBS -l walltime=01:00:00
#PBS -l select=ncpus=1:mem=8GB
#PBS -l debug=true
#PBS -o g2o_out.t00z
#PBS -e g20_err.t00z
#PBS -V

##%include <head.h>
##%include <envir-p1.h>

############################################################
# Load modules
############################################################
set -x

export model=evs
export HOMEevs=/lfs/h2/emc/vpppg/noscrub/$USER/EVS
source $HOMEevs/versions/run.ver

module reset
export HPC_OPT=/apps/ops/para/libs
module use /apps/ops/para/libs/modulefiles/compiler/intel/${intel_ver}
module use /apps/dev/modulefiles/
module load ve/evs/${ve_evs_ver}
module load cray-mpich/${craympich_ver}
module load cray-pals/${craypals_ver}
module load libjpeg/${libjpeg_ver}
module load libpng/${libpng_ver}
module load zlib/${zlib_ver}
module load jasper/${jasper_ver}
module load cfp/${cfp_ver}
module load gsl/${gsl_ver}
module load met/${met_ver}
module load metplus/${metplus_ver}
module load prod_util/${prod_util_ver}
module load prod_envir/${prod_envir_ver}

module list

export MET_PLUS_PATH="/apps/ops/para/libs/intel/${intel_ver}/metplus/${metplus_ver}"
export MET_PATH="/apps/ops/para/libs/intel/${intel_ver}/met/${met_ver}"
export MET_CONFIG="${MET_PLUS_PATH}/parm/met_config"
export PYTHONPATH=$HOMEevs/ush/$COMPONENT:$PYTHONPATH

export cyc=00
echo $cyc
export KEEPDATA=YES
export NET=evs
export STEP=prep
export COMPONENT=global_ens
export RUN=chem
export VERIF_CASE=grid2obs
export MODELNAME=gefs

######################################
### Correct MET/METplus roots (Aug 2022)
########################################
export MET_bin_exec=bin

export VDATE=$(date --date="2 days ago" +%Y%m%d)

export COMIN=/lfs/h2/emc/vpppg/noscrub/$USER/$NET/${evs_ver}
export COMINobs=/lfs/h1/ops/dev/dcom/${VDATE}
export COMOUT=/lfs/h2/emc/vpppg/noscrub/$USER/$NET/${evs_ver}
export COMOUTprep=/lfs/h2/emc/vpppg/noscrub/$USER/$NET/${evs_ver}/$STEP/$COMPONENT
export DATA=/lfs/h2/emc/ptmp/$USER/$NET/${evs_ver}
mkdir -p DATA
export FIXevs=/lfs/h2/emc/vpppg/noscrub/emc.vpppg/verification/EVS_fix
export USHevs=$HOMEevs/ush/$COMPONENT
export CONFIGevs=$HOMEevs/parm/metplus_config/$COMPONENT
export PARMevs=$HOMEevs/parm/metplus_config

## developers directories

export cycle=t${cyc}z

export VDATE=$PDYm1

############################################################
## CALL executable job script here
#############################################################
$HOMEevs/jobs/$COMPONENT/$STEP/JEVS_GLOBAL_ENS_CHEM_GRID2OBS_PREP

#%include <tail.h>
#%manual
#######################################################################
# Purpose: This does the prep work for the global_ens GEFS-Chem model
#######################################################################
#%end
