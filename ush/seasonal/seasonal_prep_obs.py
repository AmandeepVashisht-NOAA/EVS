#!/usr/bin/env python3
'''
Name: seasonal_prep_obs.py
Contact(s): Aman Vashisht
Abstract: This does the prep seasonal obs files
Run By: scripts/prep/seasonal/exevs_seasonal_obs_prep.sh
'''

import os
import datetime
import glob
import shutil
import seasonal_util as sub_util
import sys

print("BEGIN: "+os.path.basename(__file__))

cwd = os.getcwd()
print("Working in: "+cwd)

# Read in common environment variables
DATA = os.environ['DATA']
COMINcfs = os.environ['COMINcfs']
#COMINcmc = os.environ['COMINcmc']
#COMINgfs = os.environ['COMINgfs']
#COMINccpa = os.environ['COMINccpa']
#COMINobsproc = os.environ['COMINobsproc']
#DCOMINcmc_precip = os.environ['DCOMINcmc_precip']
#DCOMINcmc_regional_precip = os.environ['DCOMINcmc_regional_precip']
#DCOMINdwd_precip = os.environ['DCOMINdwd_precip']
#DCOMINecmwf = os.environ['DCOMINecmwf']
#DCOMINecmwf_precip = os.environ['DCOMINecmwf_precip']
#DCOMINfnmoc = os.environ['DCOMINfnmoc']
#DCOMINimd = os.environ['DCOMINimd']
#DCOMINjma = os.environ['DCOMINjma']
#DCOMINjma_precip = os.environ['DCOMINjma_precip']
#DCOMINmetfra_precip = os.environ['DCOMINmetfra_precip']
#DCOMINukmet = os.environ['DCOMINukmet']
#DCOMINukmet_precip = os.environ['DCOMINukmet_precip']
DCOMINosi_saf = os.environ['DCOMINosi_saf']
DCOMINghrsst_ospo = os.environ['DCOMINghrsst_ospo']
SENDCOM = os.environ['SENDCOM']
COMOUT = os.environ['COMOUT']
INITDATE = os.environ['INITDATE']
NET = os.environ['NET']
RUN = os.environ['RUN']
COMPONENT = os.environ['COMPONENT']
STEP = os.environ['STEP']
#MODELNAME = os.environ['MODELNAME'].split(' ')
OBSNAME = os.environ['OBSNAME'].split(' ')

# Make COMOUT directory for dates
output_INITDATE = COMOUT+'.'+INITDATE
gda_util.make_dir(output_INITDATE)

###### OBS
# Get operational observation data
# Northern & Southern Hemisphere 10 km OSI-SAF multi-sensor analysis - osi_saf
# Group for High Resolution Sea Surface Temperature (GHRSST) Level 4 SST analysis for Office of Satellite and Product Operations (OSPO)- ghrsst_ospo
# NCEP's Climatology-Calibrated Precipitation Analysis to 24 hour accumulation- ccpa_accum24hr
global_det_obs_dict = {
    'osi_saf': {'input_file_format': os.path.join(DCOMINosi_saf,
                                                  '{init_shift?fmt=%Y%m%d'
                                                  +'?shift=-12}',
                                                  'seaice', 'osisaf',
                                                  'ice_conc_{hem?fmt=str}_'
                                                  +'polstere-100_multi_'
                                                  +'{init_shift?fmt=%Y%m%d%H'
                                                  +'?shift=-12}00.nc'),
                'tmp_file_format': os.path.join(DATA, RUN+'.'+INITDATE,
                                                'osi_saf', 'osi_saf.multi.'
                                                +'{hem?fmt=str}.'
                                                +'{init_shift?fmt=%Y%m%d%H'
                                                +'?shift=-24}to'
                                                +'{init?fmt=%Y%m%d%H}.nc'),
                'tmp_regrid_file_format': os.path.join(DATA, RUN+'.'+INITDATE,
                                                       'osi_saf', 'regrid_data_plane'
                                                       +'_sea_ice_DailyAvg_'
                                                       +'Concentration_'
                                                       +'{grid?fmt=str}'
                                                       +'_valid{init_shift?'
                                                       +'fmt=%Y%m%d%H'
                                                       +'?shift=-24}to'
                                                       +'{init?fmt=%Y%m%d%H}.nc'),
                'inithours': ['00']},
    'ghrsst_ospo': {'input_file_format': os.path.join(DCOMINghrsst_ospo,
                                                      '{init_shift?fmt=%Y%m%d'
                                                      +'?shift=-24}',
                                                      'validation_data', 'marine',
                                                      'ghrsst',
                                                      '{init_shift?fmt=%Y%m%d'
                                                      +'?shift=-24}_OSPO_L4_'
                                                      +'GHRSST.nc'),
                    'tmp_file_format': os.path.join(DATA, RUN+'.'+INITDATE,
                                                    'ghrsst_ospo',
                                                    'ghrsst_ospo.'
                                                    +'{init_shift?fmt=%Y%m%d%H'
                                                    +'?shift=-24}to'
                                                    +'{init?fmt=%Y%m%d%H}.nc'),
                    'inithours':['00']}
                
}

for OBS in OBSNAME:
    if OBS not in list(global_det_obs_dict.keys()):
        print("FATAL ERROR: "+OBS+" not recongized")
        sys.exit(1)
    print("---- Prepping data for "+OBS+" for init "+INITDATE)
    obs_dict = global_det_obs_dict[OBS]
    for inithour in obs_dict['inithours']:
        CDATE = INITDATE+inithour
        CDATE_dt = datetime.datetime.strptime(CDATE, '%Y%m%d%H')
        input_file = gda_util.format_filler(
            obs_dict['input_file_format'], CDATE_dt, CDATE_dt,
            'anl', {}
        )
        tmp_file = gda_util.format_filler(
           obs_dict['tmp_file_format'], CDATE_dt, CDATE_dt,
           'anl', {}
        )
        output_file = os.path.join(
            output_INITDATE, OBS, tmp_file.rpartition('/')[2]
        )
        tmp_file_dir = tmp_file.rpartition('/')[0]
        if OBS == 'osi_saf':
            tmp_regrid_file = gda_util.format_filler(
                obs_dict['tmp_regrid_file_format'], CDATE_dt, CDATE_dt,
                'anl', {}
            )
            output_regrid_file = os.path.join(
                output_INITDATE, OBS, tmp_regrid_file.rpartition('/')[2]
            )
            for hem in ['nh', 'sh']:
                log_missing_file = os.path.join(
                    DATA, 'mail_missing_'+OBS+'_'+hem+'_valid'
                    +CDATE_dt.strftime('%Y%m%d%H')+'.sh'
                )
                if hem == 'nh':
                    grid = 'G219'
                elif hem == 'sh':
                    grid = 'G220'
                input_hem_file = input_file.replace('{hem?fmt=str}', hem)
                tmp_hem_file = tmp_file.replace('{hem?fmt=str}', hem)
                tmp_grid_file = tmp_regrid_file.replace('{grid?fmt=str}', grid)
                output_hem_file = output_file.replace('{hem?fmt=str}', hem)
                output_grid_file = output_regrid_file.replace(
                    '{grid?fmt=str}', grid
                )
                if not os.path.exists(output_hem_file) \
                    or not os.path.exists(output_grid_file):
                    print("----> Trying to create "+tmp_hem_file+" and "
                          +tmp_grid_file)
                    gda_util.make_dir(tmp_file_dir)
                    gda_util.prep_prod_osi_saf_file(
                        input_hem_file, tmp_hem_file, tmp_grid_file, CDATE_dt,
                        log_missing_file
                    )
                    if SENDCOM == 'YES':
                        gda_util.copy_file(tmp_hem_file, output_hem_file)
                        gda_util.copy_file(tmp_grid_file, output_grid_file)
                else:
                    if os.path.exists(output_hem_file):
                        print(f"{output_hem_file} exists")
                    if os.path.exists(output_grid_file):
                        print(f"{output_grid_file} exists")
        elif OBS == 'ghrsst_ospo':
            log_missing_file = os.path.join(
                DATA, 'mail_missing_'+OBS+'_valid'
                +CDATE_dt.strftime('%Y%m%d%H')+'.sh'
            )
            if not os.path.exists(output_file):
                print("----> Trying to create "+tmp_file)
                gda_util.make_dir(tmp_file_dir)
                gda_util.prep_prod_ghrsst_ospo_file(
                    input_file, tmp_file, CDATE_dt,
                    log_missing_file
                )
                if SENDCOM == 'YES':
                    gda_util.copy_file(tmp_file, output_file)
            else:
                print(f"{output_file} exists")
        
            for vtype in vtype_list:
                tmp_vtype_file = tmp_file.replace('{vtype?fmt=str}', vtype)
                output_vtype_file = output_file.replace('{vtype?fmt=str}',
                                                        vtype)
                if not os.path.exists(output_vtype_file):
                    print("----> Trying to create "+tmp_vtype_file)
                    gda_util.make_dir(tmp_file_dir)
                    gda_util.prep_prod_prepbufr_file(
                        input_file, tmp_vtype_file, CDATE_dt,
                        OBS.split('_')[1], vtype, log_missing_file
                    )
                    if SENDCOM == 'YES':
                        gda_util.copy_file(tmp_vtype_file, output_vtype_file)
                        if os.path.exists(output_vtype_file):
                            gda_util.run_shell_command(['chmod', '750',
                                                        output_vtype_file])
                            gda_util.run_shell_command(['chgrp', 'rstprod',
                                                        output_vtype_file])
                else:
                    print(f"{output_vtype_file} exists")


print("END: "+os.path.basename(__file__))
