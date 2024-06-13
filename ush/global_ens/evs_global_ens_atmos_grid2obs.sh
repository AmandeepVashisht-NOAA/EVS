#!/bin/ksh
#*********************************************************************************************************
# Script: evs_global_ens_grid2obs.sh
# Purpose: run Global ensembles (GEFS, CMCE, EC and NAES)  grid2obs verification for surface fields
#            by setting several METPlus environment variables and running METplus conf files
# Input parameters:
#   (1) modnam: either gefs or cmce or ecme or naefs 
# Execution steps:
#       (1) Set/export environment parameters for METplus conf files and put them into  procedure files
#       (2) Set running conf files and put them into sub-task scripts
#       (3) Put all sub-task scripts into one poe script file    
#       (4) If $run_mpi is yes, run the poe script  in paraalel
#           otherwise run the poe script in sequence
# Note on METplus verification:
#   (1) For EnsembleStat, the input forecast files are ensemble member files from EVS prep directory
#   (2) For GridStat, the input forecast files are ensemble product. Since global ensemble forecast
#       (GEFS, CMCE, ECME, NAEFS) have no ensemble product output (GEFS only has some a few), the
#       ensemble products should be generated. In this script, the ensemble products (mean or probability)
#       are first generated by the MET GenEnsProd tool dynamically in the netCDF files. Then the netCDF
#       files are used as input for GridStat to verify SL1L2, SAL1L2, CTC, PSTD etc line types
#
# Last update: 11/16/2023, by Binbin Zhou (Lynker@NCPE/EMC)
#              11/12/2023  by Mallory Row (SAIC@NCEP/EMC)
#
#********************************************************************************************************

set -x 

###########################################################
#export global parameters unified for all mpi sub-tasks
############################################################
export regrid='NONE'
############################################################
modnam=$1

#**********************************
#Check availability of input files
#*********************************
if [ $modnam = naefs ] ; then
  $USHevs/global_ens/evs_gens_atmos_check_input_files.sh gefs
  export err=$?; err_chk
  $USHevs/global_ens/evs_gens_atmos_check_input_files.sh cmce
  export err=$?; err_chk
else
  $USHevs/global_ens/evs_gens_atmos_check_input_files.sh $modnam
  export err=$?; err_chk
fi

$USHevs/global_ens/evs_gens_atmos_check_input_files.sh prepbufr
export err=$?; err_chk
$USHevs/global_ens/evs_gens_atmos_check_input_files.sh prepbufr_profile
export err=$?; err_chk

#*************************
#Get sub-string of $EVSIN
#*************************
tail='/atmos'
prefix=${EVSIN%%$tail*}
index=${#prefix}
echo $index
COM_IN=${EVSIN:0:$index}
echo $COM_IN

#********************************
#Begin to build sub-task scripts
#********************************
MODNAM=`echo $modnam | tr '[a-z]' '[A-Z]'`
if [ $modnam = gefs ] ; then
  mbrs=30
  #***************************************
  #fields: types of fields to be verified
  #**************************************
  #fields="sfc profile cloud upper"
   fields="sfc profile"
  validhours="00 06 12 18"
elif [ $modnam = cmce ] ; then
  mbrs=20
  fields="sfc profile cloud upper"
  validhours="00 12"
elif [ $modnam = naefs ] ; then
  #*************************************
  #Dynamically create NAEFS members
  #*************************************
  $USHevs/global_ens/evs_gens_atmos_g2o_create_naefs.sh
  export err=$?; err_chk
  if [ $gefs_number = 20 ] ; then
     mbrs=40
  elif [ $gefs_number = 30 ] ; then
     mbrs=50
  fi
  fields="sfc upper"
  validhours="00 12"
elif [ $modnam = ecme ] ; then
  mbrs=50
  fields="sfc profile cloud"
  validhours="00 12"
else
  err_exit "$modnam wrong model"
fi

for field in $fields ; do
    fieldUPPER=`echo $field | tr '[a-z]' '[A-Z]'`
    if [ $field = profile ] || [ $field = upper ] ; then
      #***************************************************
      #fhrs: groups of forecast hours for build sub-tasks 
      #***************************************************
      fhrs='fhr1 fhr2 fhr3 fhr4'
    elif [ $field = cloud ] ; then
      if [  $modnam = gefs ] ; then
        fhrs='fhr30 fhr31 fhr32 fhr33'
      else
        fhrs='fhr30 fhr31'
      fi
    elif [ $field = sfc ] ; then
      if [ $modnam = gefs ] ; then
        fhrs='fhr21 fhr22 fhr23 fhr24'
      else
        fhrs='fhr30 fhr31'
      fi
    fi
    if [ $field = cloud ] ; then
       metplus_jobs="GenEnsProd EnsembleStat PointStat"
    elif [ $field = sfc ] ; then
       metplus_jobs="GenEnsProd EnsembleStat PointStat"
    elif [ $field = profile ] ; then
       metplus_jobs="EnsembleStat"
    elif [ $field = upper ] ; then
       if [ $modnam = gefs ] || [ $modnam = cmce ] ; then
          metplus_jobs="GenEnsProd PointStat"
       elif [ $modnam = naefs ] ; then
          #There is no PROFILE for NAEFS, so have EnsembleStat_fcstNAEFSbc_obsPREPBUFR_UPPER.conf for ECNT for the upper level fields
          metplus_jobs="GenEnsProd EnsembleStat PointStat"
       fi
    fi
    for metplus_job in $metplus_jobs ; do
      #****************************************
      # Build a poe script to collect sub-tasks
      #***************************************
      >run_all_gens_${field}_${metplus_job}_g2o_poe.sh
      for vhour in ${validhours}  ; do
        for fhr in $fhrs ; do
          if [ $modnam = gefs ] ; then
            #For profile and upper
            if [ $fhr = fhr1 ] ; then
              leads_chk="000 006 012 018 024 030 036 042 048 054 060 066 072 078 084 090 096"
            elif [ $fhr = fhr2 ] ; then
              leads_chk="102 108 114 120 126 132 138 144 150 156 162 168 174 180 186 192"
            elif [ $fhr = fhr3 ] ; then
              leads_chk="198 204 210 216 222 228 234 240 246 252 258 264 270 276 282 288"
            elif [ $fhr = fhr4 ] ; then
              leads_chk="294 300 306 312 318 324 330 336 342 348 354 360 366 372 378 384"
            #For cloud 
            elif [ $fhr = fhr30 ] ; then
              leads_chk="006 012 018 024 030 036 042 048 054 060 066 072 078 084 090 096 102 108 114 120 126" 
            elif [ $fhr = fhr31 ] ; then
              leads_chk="132 138 144 150 156 162 168 174 180 186 192 198 204 210 216 222 228 234 240 246 252" 
            elif [ $fhr = fhr32 ] ; then
	      leads_chk="258 264 270 276 282 288 294 300 306 312 318 324 330 336 342 348 354 360 366 372 378 384"
            elif [ $fhr = fhr33 ] ; then
              leads_chk="000"
            #For sfc
            elif [ $fhr = fhr21 ] ; then
              leads_chk="000 006 012 018 024 030 036 042 048 054 060 066 072 078 084 090 096" 
            elif [ $fhr = fhr22 ] ; then
              leads_chk="102 108 114 120 126 132 138 144 150 156 162 168 174 180 186 192"
            elif [ $fhr = fhr23 ] ; then
              leads_chk="198 204 210 216 222 228 234 240 246 252 258 264 270 276 282 288" 
            elif [ $fhr = fhr24 ] ; then
              leads_chk="294 300 306 312 318 324 330 336 342 348 354 360 366 372 378 384"
            fi
          elif [ $modnam = ecme ] ; then
            #For cloud and sfc 
            if [ $fhr = fhr30 ] ; then
              leads_chk="000 012 024 036 048 060 072 084 096 108 120 132 144 156 168 180"
            elif [ $fhr = fhr31 ] ; then
              leads_chk="192 204 216 228 240 252 264 276 288 300 312 324 336 348 360"
            #For profile and upper
            elif [ $fhr = fhr1 ] ; then
              leads_chk="000 012 024 036 048 060 072 084 096"
            elif [ $fhr = fhr2 ] ; then
              leads_chk="108 120 132 144 156 168 180 192"
            elif [ $fhr = fhr3 ] ; then
              leads_chk="204 216 228 240 252 264 276 288"
            elif [ $fhr = fhr4 ] ; then
              leads_chk="300 312 324 336 348 360"
            fi
          else
            #For cloud and sfc
            if [ $fhr = fhr30 ] ; then
              leads_chk="000 012 024 036 048 060 072 084 096 108 120 132 144 156 168 180 192"
            elif [ $fhr = fhr31 ] ; then
              leads_chk="204 216 228 240 252 264 276 288 300 312 324 336 348 360 372 384"
            #For profile and upper
            elif [ $fhr = fhr1 ] ; then
              leads_chk="000 012 024 036 048 060 072 084 096"
            elif [ $fhr = fhr2 ] ; then
              leads_chk="108 120 132 144 156 168 180 192"
            elif [ $fhr = fhr3 ] ; then
              leads_chk="204 216 228 240 252 264 276 288"
            elif [ $fhr = fhr4 ] ; then
              leads_chk="300 312 324 336 348 360 372 384"
            fi
          fi
          typeset -a lead_arr
          for lead_chk in $leads_chk; do
            fcst_time=$($NDATE -$lead_chk ${vday}${vhour})
            fyyyymmdd=${fcst_time:0:8}
            ihour=${fcst_time:8:2}
            if [ $metplus_job = GenEnsProd ]|| [ $metplus_job = EnsembleStat ] ; then
              if [ $modnam = naefs ] ; then
                chk_path=${WORK}/naefs_g2o/$modnam.ens*.${fyyyymmdd}.t${ihour}z.grid3.f${lead_chk}.grib2
              elif [ $modnam = ecme ] ; then
                chk_path=$COM_IN/atmos.${fyyyymmdd}/$modnam/$modnam.ens*.t${ihour}z.grid4.f${lead_chk}.grib1
              else
                chk_path=$COM_IN/atmos.${fyyyymmdd}/$modnam/$modnam.ens*.t${ihour}z.grid3.f${lead_chk}.grib2
              fi
              nmbrs_lead_check=$(find $chk_path -size +0c 2>/dev/null | wc -l)
              if [ $nmbrs_lead_check -eq $mbrs ]; then
                 lead_arr[${#lead_arr[*]}+1]=${lead_chk}
              fi
            elif [ $metplus_job = PointStat ]; then
              chk_file=$WORK/grid2obs/run_${modnam}_${vhour}_${fhr}_${field}_g2o/stat/${modnam}/GenEnsProd_${MODNAM}_${fieldUPPER}_BIN1_FHR${lead_chk}_${vday}_${vhour}0000V_ens.nc
              if [ -s $chk_file ]; then
                lead_arr[${#lead_arr[*]}+1]=${lead_chk}
              fi
            fi
          done
          lead=$(echo $(echo ${lead_arr[@]}) | tr ' ' ',')
          unset lead_arr
	  #*****************************
	  #Build sub-task scripts
	  #*****************************
          >run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
          echo  "export output_base=$WORK/grid2obs/run_${modnam}_${vhour}_${fhr}_${field}_g2o" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
          if [ $modnam = naefs ] ; then
            echo  "export modelpath=${WORK}/naefs_g2o" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
          else
            echo  "export modelpath=$COM_IN" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
          fi
          echo  "export prepbufrhead=gfs" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
          if [ $field = profile ] ; then
             echo  "export prepbufrgrid=prepbufr_profile.f00.nc" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
          else
             echo  "export prepbufrgrid=prepbufr.f00.nc" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
          fi
          echo  "export prepbufrpath=$COM_IN" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
          echo  "export model=$modnam"  >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
          echo  "export MODEL=${MODNAM}" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
          echo  "export vbeg=$vhour" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
          echo  "export vend=$vhour" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
          echo  "export valid_increment=100" >>  run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
          echo  "export modelhead=$modnam" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
          if [ $modnam = ecme ] ; then
            echo  "export modeltail='.grib1'" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
            echo  "export modelgrid=grid4.f" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
          else
            echo  "export modeltail='.grib2'" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
            echo  "export modelgrid=grid3.f" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
          fi
          echo  "export extradir='atmos/'" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
          echo  "export climpath=$CLIMO/era5" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
          echo  "export climgrid=grid3" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
          echo  "export climtail='.grib1'" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
          echo  "export members=$mbrs" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
          echo  "export lead=$lead" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
          if [ $field = cloud ] ; then
              if [ $metplus_job = GenEnsProd ]|| [ $metplus_job = EnsembleStat ] ; then
                  if [ $modnam = gefs ] ; then
                     if [ $fhr = fhr33 ] ; then
                        echo  "${METPLUS_PATH}/ush/run_metplus.py -c ${PARMevs}/metplus_config/machine.conf -c ${GRID2OBS_CONF}/${metplus_job}_fcst${MODNAM}_obsPREPBUFR_${fieldUPPER}_F000.conf " >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
                        echo "export err=\$?; err_chk" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
                     else
                        echo  "${METPLUS_PATH}/ush/run_metplus.py -c ${PARMevs}/metplus_config/machine.conf -c ${GRID2OBS_CONF}/${metplus_job}_fcst${MODNAM}_obsPREPBUFR_${fieldUPPER}.conf " >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
                        echo "export err=\$?; err_chk" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
                     fi
                  else
                     echo  "${METPLUS_PATH}/ush/run_metplus.py -c ${PARMevs}/metplus_config/machine.conf -c ${GRID2OBS_CONF}/${metplus_job}_fcst${MODNAM}_obsPREPBUFR_${fieldUPPER}.conf " >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
                     echo "export err=\$?; err_chk" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
                  fi
              elif [ $metplus_job = PointStat ]; then
                  if [ $modnam = gefs ] ; then
                      if [ $fhr = fhr33 ] ; then
                          echo  "${METPLUS_PATH}/ush/run_metplus.py -c ${PARMevs}/metplus_config/machine.conf -c ${GRID2OBS_CONF}/${metplus_job}_fcst${MODNAM}_obsPREPBUFR_${fieldUPPER}_mean_F000.conf " >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
                          echo "export err=\$?; err_chk" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
                          echo  "${METPLUS_PATH}/ush/run_metplus.py -c ${PARMevs}/metplus_config/machine.conf -c ${GRID2OBS_CONF}/${metplus_job}_fcst${MODNAM}_obsPREPBUFR_${fieldUPPER}_prob_F000.conf " >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
                          echo "export err=\$?; err_chk" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
                      else
                          echo  "${METPLUS_PATH}/ush/run_metplus.py -c ${PARMevs}/metplus_config/machine.conf -c ${GRID2OBS_CONF}/${metplus_job}_fcst${MODNAM}_obsPREPBUFR_${fieldUPPER}_mean.conf " >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
                          echo "export err=\$?; err_chk" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
                          echo  "${METPLUS_PATH}/ush/run_metplus.py -c ${PARMevs}/metplus_config/machine.conf -c ${GRID2OBS_CONF}/${metplus_job}_fcst${MODNAM}_obsPREPBUFR_${fieldUPPER}_prob.conf " >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
                          echo "export err=\$?; err_chk" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
                      fi
                  else
                      echo  "${METPLUS_PATH}/ush/run_metplus.py -c ${PARMevs}/metplus_config/machine.conf -c ${GRID2OBS_CONF}/${metplus_job}_fcst${MODNAM}_obsPREPBUFR_${fieldUPPER}_mean.conf " >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
                      echo "export err=\$?; err_chk" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
                      echo  "${METPLUS_PATH}/ush/run_metplus.py -c ${PARMevs}/metplus_config/machine.conf -c ${GRID2OBS_CONF}/${metplus_job}_fcst${MODNAM}_obsPREPBUFR_${fieldUPPER}_prob.conf " >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
                      echo "export err=\$?; err_chk" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
                  fi
              fi
          elif [ $field = sfc ] || [ $field = upper ]; then
              if [ $modnam = gefs ] || [ $modnam = cmce ] || [ $modnam = ecme ] ; then
                  conf_MODNAM=${MODNAM}
              elif [ $modnam = naefs ] ; then
                  conf_MODNAM="NAEFSbc"
              fi
              if [ $metplus_job = GenEnsProd ]|| [ $metplus_job = EnsembleStat ] ; then
                  if [ $metplus_job = EnsembleStat ] && [ $modnam = naefs ] && [ $field = upper ]; then
                     echo  "${METPLUS_PATH}/ush/run_metplus.py -c ${PARMevs}/metplus_config/machine.conf -c ${GRID2OBS_CONF}/${metplus_job}_fcst${conf_MODNAM}_obsPREPBUFR_${fieldUPPER}.conf " >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
                     echo "export err=\$?; err_chk" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
                  else
                      echo  "${METPLUS_PATH}/ush/run_metplus.py -c ${PARMevs}/metplus_config/machine.conf -c ${GRID2OBS_CONF}/${metplus_job}_fcst${conf_MODNAM}_obsPREPBUFR_${fieldUPPER}_climoERA5.conf " >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
                      echo "export err=\$?; err_chk" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
                  fi
              elif [ $metplus_job = PointStat ]; then
                  echo  "${METPLUS_PATH}/ush/run_metplus.py -c ${PARMevs}/metplus_config/machine.conf -c ${GRID2OBS_CONF}/${metplus_job}_fcst${conf_MODNAM}_obsPREPBUFR_${fieldUPPER}_mean_climoERA5.conf " >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
                  echo "export err=\$?; err_chk" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
              fi
          elif [ $field = profile ] ; then
              echo "${METPLUS_PATH}/ush/run_metplus.py -c ${PARMevs}/metplus_config/machine.conf -c ${GRID2OBS_CONF}/${metplus_job}_fcst${MODNAM}_obsPREPBUFR_${fieldUPPER}.conf" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
              echo "export err=\$?; err_chk" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
          fi
          if [ $metplus_job = EnsembleStat ] ; then
              if [ $SENDCOM="YES" ] ; then
                  echo "for FILE in \$output_base/stat/${modnam}/ensemble_stat*.stat ; do" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
                  echo "  if [ -s \$FILE ]; then" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
                  echo "    cp -v \$FILE $COMOUTsmall" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
                  echo "  fi" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
                  echo "done" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
               fi
          elif [ $metplus_job = PointStat ]; then
              if [ $SENDCOM="YES" ] ; then
                  echo "for FILE in \$output_base/stat/${modnam}/point_stat*.stat ; do" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
                  echo "  if [ -s \$FILE ]; then" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
                  echo "    cp -v \$FILE $COMOUTsmall" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
                  echo "  fi" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
                  echo "done" >> run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
              fi
          fi
          chmod +x run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh
          echo "${DATA}/run_${modnam}_${vhour}_${fhr}_${field}_${metplus_job}_g2o.sh" >> run_all_gens_${field}_${metplus_job}_g2o_poe.sh
        done # end of fhr
      done # end of vhour
    chmod 755 ${DATA}/run_all_gens_${field}_${metplus_job}_g2o_poe.sh

    #***********************************************
    #Run poe script in MPI parallel or in sequence
    #**********************************************
    if [ $run_mpi = yes ] ; then
      if [ ${modnam} = gefs ] ; then
        mpiexec -n 60 -ppn 60 --cpu-bind verbose,core cfp ${DATA}/run_all_gens_${field}_${metplus_job}_g2o_poe.sh
        export err=$?; err_chk
      elif [ ${modnam} = cmce ] || [ ${modnam} = ecme ] ; then
        mpiexec -n 24 -ppn 24 --cpu-bind verbose,core cfp ${DATA}/run_all_gens_${field}_${metplus_job}_g2o_poe.sh
        export err=$?; err_chk
      else
        mpiexec -n 12 -ppn 12 --cpu-bind verbose,core cfp ${DATA}/run_all_gens_${field}_${metplus_job}_g2o_poe.sh
        export err=$?; err_chk
      fi
    else
      ${DATA}/run_all_gens_${field}_${metplus_job}_g2o_poe.sh
      export err=$?; err_chk
    fi
    done #end of metplus_job
done #end of field

#******************************************************************
# Collect all small stat files to form a large final big stat file 
#******************************************************************
if [ $gather = yes ] ; then
   if [ ${modnam} = gefs ] ; then
     $USHevs/global_ens/evs_global_ens_atmos_gather.sh $MODELNAME grid2obs 00 18
     export err=$?; err_chk
   else
     $USHevs/global_ens/evs_global_ens_atmos_gather.sh $MODELNAME grid2obs 00 12
     export err=$?; err_chk
   fi
fi
