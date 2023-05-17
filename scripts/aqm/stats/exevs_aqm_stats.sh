set -x

mkdir -p $DATA/logs
mkdir -p $DATA/stat

#######################################################################
# Define INPUT OBS DATA TYPE for PointStat
#######################################################################
#
hourly_type=aqobs
if [ "${hourly_type}" == "aqobs" ]; then
    export HOURLY_INPUT_TYPE=hourly_aqobs
else
    export HOURLY_INPUT_TYPE=hourly_data
fi
if [ "${fcst_input_ver}" == "v6" ]; then
    export dirnam=cs
    export gridspec=148
elif [ "${fcst_input_ver}" == "v7" ]; then
    export dirnam=aqm
    export gridspec=793
else
    echo "EVS_CHECK :: The AQM version number is not defined :: ${fcst_input_ver}"
fi
export fcstmax=72

export MASK_DIR=/lfs/h2/emc/vpppg/noscrub/logan.dawson/CAM_verif/masks/Bukovsky_CONUS/EVS_fix

export model1=`echo $MODELNAME | tr a-z A-Z`
echo $model1

# Begin verification of both the hourly data of ozone and PM
#
# The valid time of forecast model output is the reference here in PointStat
# Because of the valid time definition between forecat outp[ut and observation is different
#     For average concentration of a period [ cyc-1 to cyc ], aqm output is defined at cyc Z
#     while observation is defined at cyc-1 Z
# Thus, the one hour back OBS input will be checked and used in PointStat
#     [OBS_POINT_STAT_INPUT_TEMPLATE=****_{valid?fmt=%Y%m%d%H?shift=-3600}.nc]
#
cdate=${VDATE}${cyc}
vld_date=$(${NDATE} -1 ${cdate} | cut -c1-8)
vld_time=$(${NDATE} -1 ${cdate} | cut -c1-10)

VDAYm1=$(${NDATE} -24 ${cdate} | cut -c1-8)
VDAYm2=$(${NDATE} -24 ${cdate} | cut -c1-8)
VDAYm3=$(${NDATE} -24 ${cdate} | cut -c1-8)

check_file=${COMINaqmproc}/${RUN}.${vld_date}/${MODELNAME}/airnow_${HOURLY_INPUT_TYPE}_${vld_time}.nc
obs_hourly_found=0
if [ -s ${check_file} }; then
    obs_hourly_found=1
    echo "Can not find pre-processed obs hourly input ${check_file}"
    ## add email function here
fi
echo "obs_hourly_found = ${obs_hourly_found}"

# Verification to be done both on raw output files and bias-corrected files

  for biastyp in raw bc
  do

    export outtyp
    export biastyp
    echo $biastyp

    if [ $biastyp = "raw" ]
    then
      export bctag=
      export bcout=_raw
    fi

    if [ $biastyp = "bc" ]
    then
      export bctag=_bc
      export bcout=_bc
    fi

# check to see that model files exist, and list which forecast hours are to be used

    let ihr=0
    numo3fcst=0
    numpmfcst=0
    while [ ${ihr} -le $fcstmax ]
    do
      filehr=$(printf %3.3d ${ihr})    ## fhr of grib2 filename is in 3 digit for aqmv7 and 2 digit for aqmv6
      fhr=$(printf %2.2d ${ihr})       ## fhr for the processing valid hour is in 2 digit
      export fhr

      export datehr=${VDATE}${cyc}
      adate=`$NDATE -${ihr} $datehr`
      aday=`echo $adate |cut -c1-8`
      acyc=`echo $adate |cut -c9-10`
      if [ $acyc = 06 -o $acyc = 12 ]
      then
      if [ -s $COMINaqm/${dirname}.${aday}/${acyc}/aqm.t${acyc}z.awpozcon${bctag}.f${filehr}.${gridspec}.grib2 ]
      then
        echo "$fhr found"
        echo $fhr >> $DATA/fcstlist_o3
        let "numo3fcst=numo3fcst+1"
      fi 
      if [ -s $COMINaqm/${dirname}.${aday}/${acyc}/aqm.t${acyc}z.pm25${bctag}.f${filehr}.${gridspec}.grib2 ]
      then
        echo "$fhr found"
        echo $fhr >> $DATA/fcstlist_pm
        let "numpmfcst=numpmfcst+1"
      fi

      fi
      ((ihr++))
    done
    export fcsthours_o3=`awk -v d=", " '{s=(NR==1?s:s d)$0}END{print s}' $DATA/fcstlist_o3`
    export fcsthours_pm=`awk -v d=", " '{s=(NR==1?s:s d)$0}END{print s}' $DATA/fcstlist_pm`
    export numo3fcst
    export numpmfcst
    rm $DATA/fcstlist_o3 $DATA/fcstlist_pm
    echo "numo3fcst,numpmfcst", $numo3fcst, $numpmfcst

    case $outtyp in

        awpozcon) if [ $numo3fcst -gt 0 -a $obs_hourly_found -eq 1 ]
                  then
                  export fcsthours=$fcsthours_o3
                  run_metplus.py $PARMevs/metplus_config/${COMPONENT}/${VERIF_CASE}/stats/PointStat_fcstOZONE_obsAIRNOW_${fcst_input_ver}.conf $PARMevs/metplus_config/machine.conf
                  export err=$?; err_chk
                  mkdir -p $COMOUTsmall
                  cp $DATA/point_stat/$MODELNAME/* $COMOUTsmall
                  if [ $cyc = 23 ]
                  then
                    mkdir -p $COMOUTfinal
                    run_metplus.py $PARMevs/metplus_config/${COMPONENT}/${VERIF_CASE}/stats/StatAnalysis_fcstOZONE_obsAIRNOW_GatherByDay.conf $PARMevs/metplus_config/machine.conf
                    export err=$?; err_chk
                  fi
                  else
                  echo "NO O3 FORECAST OR OBS TO VERIFY"
                  echo "NUM FCST, NUM OBS", $numo3fcst, $obs_hourly_found
                  fi
                  ;;
      pm25) if [ $numpmfcst -gt 0 -a $obs_hourly_found -eq 1 ]
            then
            export fcsthours=$fcsthours_pm
            run_metplus.py $PARMevs/metplus_config/${COMPONENT}/${VERIF_CASE}/stats/PointStat_fcstPM2p5_obsAIRNOW_${fcst_input_ver}.conf $PARMevs/metplus_config/machine.conf
            export err=$?; err_chk
            mkdir -p $COMOUTsmall
            cp $DATA/point_stat/$MODELNAME/* $COMOUTsmall
            if [ $cyc = 23 ]
            then
               mkdir -p $COMOUTfinal
               run_metplus.py $PARMevs/metplus_config/${COMPONENT}/${VERIF_CASE}/stats/StatAnalysis_fcstPM_obsANOWPM_GatherByDay.conf $PARMevs/metplus_config/machine.conf
               export err=$?; err_chk
            fi
            else
            echo "NO PM FORECAST OR OBS TO VERIFY"
            echo "NUM FCST, NUM OBS", $numpmfcst, $obs_hourly_found
            fi
            ;;
    esac

  done

done

# Daily verification of the daily maximum of 8-hr ozone
# Verification being done on both raw and bias-corrected output data

check_file=${COMINaqmproc}/${RUN}.${VDATE}/${MODELNAME}/airnow_daily_${VDATE}.nc
obs_daily_found=0
if [ -s ${check_file} }; then
    obs_daily_found=1
    echo "Can not find pre-processed obs daily input ${check_file}"
    ## add email function here
fi
echo "obs_daily_found = ${obs_daily_found}"


if [ $cyc = 11 ]
then

  for biastyp in raw bc
  do

    export biastyp
    echo $biastyp

    if [ $biastyp = "raw" ]
    then
      export bctag=
      export bcout=_raw
    fi

    if [ $biastyp = "bc" ]
    then
      export bctag=_bc
      export bcout=_bc
    fi

    for hour in 06 12
    do

      export hour

#  search for model file and 2nd obs file for the daily 8-hr ozone max

      ozmax8=0
      if [ -s $COMINaqmproc/atmos.${VDAYm1}/aqm/aqm.t${hour}z.max_8hr_o3${bctag}.${gridspec}.grib2 ]
      then
        ozmax8=1
      fi
      if [ -s $COMINaqmproc/atmos.${VDAYm2}/aqm/aqm.t${hour}z.max_8hr_o3${bctag}.${gridspec}.grib2 ]
      then
       let "ozmax8=ozmax8+1"
      fi
      if [ -s $COMINaqmproc/atmos.${VDAYm3}/aqm/aqm.t${hour}z.max_8hr_o3${bctag}.${gridspec}.grib2 ]
      then
        let "ozmax8=ozmax8+1"
      fi
      echo "ozmax8, obs_daily_found=",$ozmax8,$obs_daily_found
      if [ $ozmax8 -gt 0 -a $obs_daily_found -gt 0 ]
      then 
        run_metplus.py $PARMevs/metplus_config/${COMPONENT}/${VERIF_CASE}/stats/PointStat_fcstOZONEMAX_obsAIRNOW_${fcst_input_ver}.conf $PARMevs/metplus_config/machine.conf
	export err=$?; err_chk
        cp $DATA/point_stat/$MODELNAME/* $COMOUTsmall
        export outtyp=OZMAX8
        run_metplus.py $PARMevs/metplus_config/${COMPONENT}/${VERIF_CASE}/stats/StatAnalysis_fcstOZONEMAX_obsAIRNOW_GatherByDay.conf $PARMevs/metplus_config/machine.conf
	export err=$?; err_chk
       else
         echo "NO OZMAX8 OBS OR MODEL DATA"
         echo "OZMAX8, OBS_DAILY_FOUND", $ozmax8, $obs_daily_found
       fi
    done

  done

fi

# Daily verification of the daily average of PM2.5
# Verification is being done on both raw and bias-corrected output data

if [ $cyc = 04 ]
then

  for biastyp in raw bc
  do

    export biastyp
    echo $biastyp

    if [ $biastyp = "raw" ]
    then
      export bctag=
      export bcout=_raw
    fi

    if [ $biastyp = "bc" ]
    then
      export bctag=_bc
      export bcout=_bc
    fi

    for hour in 06 12
    do

      export hour

#  search for model file and 2nd obs file for the daily average PM

      pmave1=0
      if [ -s $COMINaqm/${dirname}.${VDAYm1}/${hour}/aqm.t${hour}z.ave_24hr_pm25${bctag}.${gridspec}.grib2 ]
      then
        pmave1=1
      fi
      if [ -s $COMINaqm/${dirname}.${VDAYm2}/${hour}/aqm.t${hour}z.ave_24hr_pm25${bctag}.${gridspec}.grib2 ]
      then
       let "pmave1=pmave1+1" 
      fi
      if [ -s $COMINaqm/${dirname}.${VDAYm3}/${hour}/aqm.t${hour}z.ave_24hr_pm25${bctag}.${gridspec}.grib2 ]
      then
        let "pmave1=pmave1+1"
      fi
      echo "pmave1, obs_daily_found=",$pmave1,$obs_daily_found
      if [ $pmave1 -gt 0 -a $obs_daily_found -gt 0 ]
      then
        run_metplus.py $PARMevs/metplus_config/${COMPONENT}/${VERIF_CASE}/stats/PointStat_fcstPMAVE_obsANOWPM_${fcst_input_ver}.conf $PARMevs/metplus_config/machine.conf
	export err=$?; err_chk
        cp $DATA/point_stat/$MODELNAME/* $COMOUTsmall
        export outtyp=PMAVE
        run_metplus.py $PARMevs/metplus_config/${COMPONENT}/${VERIF_CASE}/stats/StatAnalysis_fcstPMAVE_obsANOWPM_GatherByDay.conf $PARMevs/metplus_config/machine.conf
	export err=$?; err_chk
       else
         echo "NO PMAVE OBS OR MODEL DATA"
         echo "PMAVE1, OBS_DAILY_FOUND", $pmave1, $obs_daily_found
       fi
    done

  done

fi

exit

