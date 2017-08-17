#!/bin/bash

g_pipeline_name="StructuralPreprocessing"

if [ -z "${XNAT_PBS_JOBS}" ]; then
	script_name=$(basename "${0}")
	echo "${script_name}: ABORTING: XNAT_PBS_JOBS environment variable must be set"
	exit 1
fi

source "${XNAT_PBS_JOBS}/shlib/log.shlib"  # Logging related functions
source "${XNAT_PBS_JOBS}/shlib/utils.shlib"  # Utility functions
log_Msg "XNAT_PBS_JOBS: ${XNAT_PBS_JOBS}"

if [ -z "${NRG_PACKAGES}" ]; then
	log_Err_Abort "NRG_PACKAGES environment variable must be set"
else
	log_Msg "NRG_PACKAGES: ${NRG_PACKAGES}"
fi

if [ -z "${XNAT_PBS_JOBS_XNAT_SERVER}" ]; then
	log_Err_Abort "XNAT_PBS_JOBS_XNAT_SERVER environment variable must be set"
else
	log_Msg "XNAT_PBS_JOBS_XNAT_SERVER: ${XNAT_PBS_JOBS_XNAT_SERVER}"
fi

if [ -z "${XNAT_PBS_JOBS_ARCHIVE_ROOT}" ]; then
	log_Err_Abort "XNAT_PBS_JOBS_ARCHIVE_ROOT environment variable must be set"
else
	log_Msg "XNAT_PBS_JOBS_ARCHIVE_ROOT: ${XNAT_PBS_JOBS_ARCHIVE_ROOT}"
fi

if [ -z "${XNAT_UTILS_HOME}" ]; then
	log_Err_Abort "XNAT_UTILS_HOME environment variable must be set"
else
	log_Msg "XNAT_UTILS_HOME: ${XNAT_UTILS_HOME}"
fi

if [ -z "${XNAT_PBS_JOBS_PIPELINE_ENGINE}" ]; then
	log_Err_Abort "XNAT_PBS_JOBS_PIPELINE_ENGINE environment variable must be set"
else
	log_Msg "XNAT_PBS_JOBS_PIPELINE_ENGINE: ${XNAT_PBS_JOBS_PIPELINE_ENGINE}"
fi

# Show script usage information
usage()
{
	cat <<EOF

Run the HCP Structural Preprocessing pipeline scripts (PreFreeSurferPipeline.sh, 
FreeSurferPipeline.sh, and PostFreeSurferPipeline.sh) in an XNAT-aware and
XNAT-pipeline-like manner.

Usage: StructuralPreprocessingHCP.XNAT.sh <options>

  Options: [ ] = optional, < > = user-supplied-value

  [--help] : show usage information and exit
   --user=<username>        : XNAT DB username
   --password=<password>    : XNAT DB password
   --server=<server>        : XNAT server 
   --project=<project>      : XNAT project (e.g. HCP_500)
   --subject=<subject>      : XNAT subject ID within project (e.g. 100307)
   --session=<session>      : XNAT session ID within project (e.g. 100307_3T)
   --working-dir=<dir>      : Working directory in which to place retrieved data
                              and in which to produce results
   --setup-script=<script>  : Full path to script to source to set up environment before running
                              HCP Pipeline Scripts. If unspecified the default value of:
                              ${DEFAULT_SETUP_SCRIPT} is used.
   --first-t1w-directory-name=<directory-name>
                            : TBW
   --first-t1w-resource-name=<resource-name>
                            : Name of XNAT session resource that contains the first T1w scan
   --first-t1w-file-name=<file-name>
                            : Name of first T1w file
  [--second-t1w-directory-name=<directory-name>]
                            : TBW
  [--second-t1w-resource-name=<resource-name>]
                            : Name of XNAT session resource that contains the second T1w scan
  [--second-t1w-file-name=<file-name>]
                            : Name of second T1w file
   --first-t2w-directory-name=<directory-name>
                            : TBW
   --first-t2w-resource-name=<resource-name>
                            : Name of XNAT session resource that contains the first T2w scan
   --first-t2w-file-name=<file-name>
                            : Name of first T2w file
  [--second-t2w-directory-name=<directory-name>]
                            : TBW
  [--second-t2w-resource-name=<resource-name>]
                            : Name of XNAT session resource that contains the second T2w scan
  [--second-t2w-file-name=<file-name>]
                            : Name of second T2w file
  [--fieldmap-type=<type>]  : <type> values
                              GE: Siemens Gradient Echo Fieldmaps
                              SiemensGradientEcho: Siemens Gradient Echo Fieldmaps (equiv. to GE)
                              SE: Spin Echo Fieldmaps
                              SpinEcho: Spin Echo Fieldmaps (equiv. to SE)
                              NONE: No fieldmaps
                              If unspecified, defaults to GE
  [--seed=<rng-seed>]       : Random number generator seed for recon-all, passed to FreeSurferPipeline.sh script
                              If unspecified, no seed value is passed to the FreeSurferPipeline.sh script.
                              In that case, no seed value is passed to random number generator seed using
                              tools.
  [--brainsize=<brainsize>] : brainsize value passed to the PreFreeSurferPipeline.sh script
                              If unspecified, the default value of 150 is used.

   NB: The following template files are expected to be found in HCPPIPEDIR/global/templates

   --t1template=<name>      : MNI T1w template 
   --t1templatebrain=<name> : Brain extracted MNI T1w template
   --t1template2mm=<name>   : MNI 2mm T1w template
   --t2template=<name>      : MNI T2w template
   --t2templatebrain=<name> : Brain extracted MNI T2w template
   --t2template2mm=<name>   : MNI 2mm T2w template
   --templatemask=<name>    : Brain mask MNI Template
   --template2mmmask=<name> : Brain mask MNI 2mm Template

   NB: The following file are expected to be found in HCPPIPEDIR/global/config

   --fnirtconfig=<name>     : FNIRT 2mm Configuration file
  [--gdcoeffs=<name>]       : Gradient Distortion Coefficients file
                              If not specified, this value defaults to NONE and 
                              no gradient distortion correction is performed.
  [--topupconfig=<name>]    : Configuration file for topup or "NONE" if not used
                              Defaults to "NONE"

EOF
}

# Parse specified command line options and verify that required options are 
# specified. "Return" the options to use in global variables
get_options()
{
	local arguments=($@)

	# initialize global output variables
	unset g_user
	unset g_password
	unset g_server
	unset g_project
	unset g_subject
	unset g_session
	unset g_working_dir
	unset g_setup_script	

	unset g_fieldmap_type
	unset g_seed
	unset g_brainsize

	unset g_first_t1w_directory_name
	unset g_first_t1w_resource_name
	unset g_first_t1w_file_name

	unset g_second_t1w_directory_name
	unset g_second_t1w_resource_name
	unset g_second_t1w_file_name

	unset g_first_t2w_directory_name
	unset g_first_t2w_resource_name
	unset g_first_t2w_file_name

	unset g_second_t2w_directory_name
	unset g_second_t2w_resource_name
	unset g_second_t2w_file_name

	unset g_session_classifier

	unset g_t1template
	unset g_t1templatebrain
	unset g_t1template2mm
	unset g_t2template
	unset g_t2templatebrain
	unset g_t2template2mm
	unset g_templatemask
	unset g_template2mmmask

	unset g_fnirtconfig
	
	# set default values
	g_fieldmap_type="GE"
	g_brainsize="150"
	g_session_classifier="3T"
	g_gdcoeffs="NONE"
	g_topupconfig="NONE"
	g_se_phase_pos="NONE"
	g_se_phase_neg="NONE"
	
	# parse arguments
	local num_args=${#arguments[@]}
	local argument
	local index=0

	while [ ${index} -lt ${num_args} ]; do
		argument=${arguments[index]}

		case ${argument} in
			--help)
				usage
				exit 1
				;;
			--user=*)
				g_user=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--password=*)
				g_password=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--server=*)
				g_server=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--project=*)
				g_project=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--subject=*)
				g_subject=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--session=*)
				g_session=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--session-classifier=*)
				g_session_classifier=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--working-dir=*)
				g_working_dir=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--setup-script=*)
				g_setup_script=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--fieldmap-type=*)
				g_fieldmap_type=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--seed=*)
				g_seed=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--brainsize=*)
				g_brainsize=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--first-t1w-directory-name=*)
				g_first_t1w_directory_name=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--first-t1w-resource-name=*)
				g_first_t1w_resource_name=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--first-t1w-file-name=*)
				g_first_t1w_file_name=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--second-t1w-directory-name=*)
				g_second_t1w_directory_name=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--second-t1w-resource-name=*)
				g_second_t1w_resource_name=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--second-t1w-file-name=*)
				g_second_t1w_file_name=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--first-t2w-directory-name=*)
				g_first_t2w_directory_name=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--first-t2w-resource-name=*)
				g_first_t2w_resource_name=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--first-t2w-file-name=*)
				g_first_t2w_file_name=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--second-t2w-directory-name=*)
				g_second_t2w_directory_name=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--second-t2w-resource-name=*)
				g_second_t2w_resource_name=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--second-t2w-file-name=*)
				g_second_t2w_file_name=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--t1template=*)
				g_t1template=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--t1templatebrain=*)
				g_t1templatebrain=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--t1template2mm=*)
				g_t1template2mm=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--t2template=*)
				g_t2template=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--t2templatebrain=*)
				g_t2templatebrain=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--t2template2mm=*)
				g_t2template2mm=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--templatemask=*)
				g_templatemask=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--template2mmmask=*)
				g_template2mmmask=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--fnirtconfig=*)
				g_fnirtconfig=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--gdcoeffs=*)
				g_gdcoeffs=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--topupconfig=*)
				g_topupconfig=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--se-phase-pos=*)
				g_se_phase_pos=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--se-phase-neg=*)
				g_se_phase_neg=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			*)
				usage
				log_Err_Abort "unrecognized option: ${argument}"
				;;
		esac
	done

 	local error_count=0

 	# check parameters
 	if [ -z "${g_user}" ]; then
 		log_Err "user (--user=) required"
 		error_count=$(( error_count + 1 ))
 	else
 		log_Msg "g_user: ${g_user}"
 	fi

 	if [ -z "${g_password}" ]; then
 		log_Err "password (--password=) required"
 		error_count=$(( error_count + 1 ))
 	else
 		log_Msg "g_password: *******"
 	fi

	if [ -z "${g_server}" ]; then
		log_Err "server (--server=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_server: ${g_server}"
	fi

	if [ -z "${g_project}" ]; then
		log_Err "project (--project=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_project: ${g_project}"
	fi

	if [ -z "${g_subject}" ]; then
		log_Err "subject (--subject=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_subject: ${g_subject}"
	fi

	if [ -z "${g_session}" ]; then
		log_Err "session (--session=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_session: ${g_session}"
	fi

	if [ -z "${g_session_classifier}" ]; then
		log_Err "session classifier (--session-classifier=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_session_classifier: ${g_session_classifier}"
	fi
	
	if [ -z "${g_working_dir}" ]; then
		log_Err "working directory (--working-dir=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_working_dir: ${g_working_dir}"
	fi
	
	if [ -z "${g_setup_script}" ] ; then
		log_Err "setup script (--setup-script=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_setup_script: ${g_setup_script}"
	fi
	
	if [ -z "${g_fieldmap_type}" ]; then
		log_Err "fieldmap type (--fieldmap-type=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_fieldmap_type: ${g_fieldmap_type}"
	fi
	
 	if [[ ("${g_fieldmap_type}" != "GE") && ("${g_fieldmap_type}" != "SiemensGradientEcho") && ("${g_fieldmap_type}" != "SE") && ("${g_fieldmap_type}" != "SpinEcho") && ("${g_fieldmap_type}" != "NONE") ]] ; then
 		log_Err "unrecognized g_fieldmap_type: ${g_fieldmap_type}"
 		error_count=$(( error_count + 1 ))
 	fi

 	if [ ! -z "${g_seed}" ]; then
 		log_Msg "g_seed: ${g_seed}"
 	fi

	if [ -z "${g_brainsize}" ]; then
 		log_Err "brainsize (--brainsize=) required"
 	else
 		log_Msg "g_brainsize: ${g_brainsize}"
 	fi

 	if [ -z "${g_first_t1w_directory_name}" ]; then
 		log_Err "first T1w directory name (--first-t1w-directory-name=) required"
 		error_count=$(( error_count + 1 ))
 	else
 		log_Msg "g_first_t1w_directory_name: ${g_first_t1w_directory_name}"
 	fi
	
 	if [ -z "${g_first_t1w_resource_name}" ]; then
 		log_Err "first T1w resource name (--first-t1w-resource-name=) required"
 		error_count=$(( error_count + 1 ))
 	else
 		log_Msg "g_first_t1w_resource_name: ${g_first_t1w_resource_name}"
 	fi

 	if [ -z "${g_first_t1w_file_name}" ]; then
 		log_Err "first T1w file name (--first-t1w-file-name=) required"
 		error_count=$(( error_count + 1 ))
	else
 		log_Msg "g_first_t1w_file_name: ${g_first_t1w_file_name}"
 	fi

 	if [ ! -z "${g_second_t1w_directory_name}" ]; then
 		log_Msg "g_second_t1w_directory_name: ${g_second_t1w_directory_name}"
 	fi
	
 	if [ ! -z "${g_second_t1w_resource_name}" ]; then
 		log_Msg "g_second_t1w_resource_name: ${g_second_t1w_resource_name}"
 	fi

 	if [ ! -z "${g_second_t1w_file_name}" ]; then
 		log_Msg "g_second_t1w_file_name: ${g_second_t1w_file_name}"
 	fi

 	if [ -z "${g_first_t2w_directory_name}" ]; then
 		log_Err "first T2w directory name (--first-t2w-directory-name=) required"
 		error_count=$(( error_count + 1 ))
 	else
 		log_Msg "g_first_t2w_directory_name: ${g_first_t2w_directory_name}"
 	fi

 	if [ -z "${g_first_t2w_resource_name}" ]; then
 		log_Err "first T2w resource name (--first-t2w-resource-name=) required"
 		error_count=$(( error_count + 1 ))
 	else
 		log_Msg "g_first_t2w_resource_name: ${g_first_t2w_resource_name}"
 	fi

 	if [ -z "${g_first_t2w_file_name}" ]; then
 		log_Err "first T2w file name (--first-t2w-file-name=) required"
 		error_count=$(( error_count + 1 ))
 	else
 		log_Msg "g_first_t2w_file_name: ${g_first_t2w_file_name}"
 	fi

 	if [ ! -z "${g_second_t2w_directory_name}" ]; then
 		log_Msg "g_second_t2w_directory_name: ${g_first_t2w_directory_name}"
 	fi
	
 	if [ ! -z "${g_second_t2w_resource_name}" ]; then
 		log_Msg "g_second_t2w_resource_name: ${g_second_t2w_resource_name}"
 	fi

 	if [ ! -z "${g_second_t2w_file_name}" ]; then
 		log_Msg "g_second_t2w_file_name: ${g_second_t2w_file_name}"
 	fi

 	if [ -z "${g_t1template}" ]; then
 		log_Err "--t1template= required"
 		error_count=$(( error_count + 1 ))
 	else
 		log_Msg "g_t1template: ${g_t1template}"
 	fi

	if [ -z "${g_t1templatebrain}" ]; then
		log_Err "--t1templatebrain= required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_t1templatebrain: ${g_t1templatebrain}"
	fi
	
	if [ -z "${g_t1template2mm}" ]; then
		log_Err "--t1template2mm= required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_t1template2mm: ${g_t1template2mm}"
	fi
	
	if [ -z "${g_t2template}" ]; then
		log_Err "MNI T2w template (--t2template=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_t2template: ${g_t2template}"
	fi

	if [ -z "${g_t2templatebrain}" ]; then
		log_Err "--t2templatebrain= required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_t2templatebrain: ${g_t2templatebrain}"
	fi
	
	if [ -z "${g_t2template2mm}" ]; then
		log_Err "--t2template2mm= required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_t2template2mm: ${g_t2template2mm}"
	fi
	
	if [ -z "${g_templatemask}" ]; then
		log_Err "--templatemask= required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_templatemask: ${g_templatemask}"
	fi
	
	if [ -z "${g_template2mmmask}" ]; then
		log_Err "--template2mmmask= required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_template2mmmask: ${g_template2mmmask}"
	fi

	if [ -z "${g_fnirtconfig}" ]; then
		log_Err "--fnirtconfig= required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_fnirtconfig: ${g_fnirtconfig}"
	fi

	if [ -z "${g_gdcoeffs}" ]; then
		log_Err "--gdcoeffs= required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_gdcoeffs: ${g_gdcoeffs}"
	fi

	if [ -z "${g_topupconfig}" ]; then
		log_Err "--topupconfig= required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_topupconfig: ${g_topupconfig}"
	fi

	if [ -z "${g_se_phase_pos}" ]; then
		log_Err "--se-phase-pos= required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_se_phase_pos: ${g_se_phase_pos}"
	fi

	if [ -z "${g_se_phase_neg}" ]; then
		log_Err "--se-phase-neg= required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_se_phase_neg: ${g_se_phase_neg}"
	fi

 	if [ ${error_count} -gt 0 ]; then
 		log_Err_Abort "For usage information, use --help"
 	fi
}

# "base" of file name for first T1w scan
FIRST_T1W_FILE_NAME_BASE="T1w_MPR1"

# "base" of file name for second T1w scan
SECOND_T1W_FILE_NAME_BASE="T1w_MPR2"

# "base" of file name for first T2w scan
FIRST_T2W_FILE_NAME_BASE="T2w_SPC1"

# "base" of file name for second T2w scan
SECOND_T2W_FILE_NAME_BASE="T2w_SPC2"

# file name extension for compressed NIFTI fiiles
COMPRESSED_NIFTI_EXTENSION=".nii.gz"

# part of file name that indicates a Siemens Gradient Echo Magnitude Fieldmap file
MAG_FIELDMAP_NAME="FieldMap_Magnitude"

# part of file name that indicates a Siemens Gradient Echo Phase Fieldmap file
PHASE_FIELDMAP_NAME="FieldMap_Phase"

get_scan_data() 
{
	local resource_name="${1}"
	local file_name="${2}"
	local item_name="${3}"

	local result=`${XNAT_UTILS_HOME}/xnat_scan_info -s "${XNAT_PBS_JOBS_XNAT_SERVER}" -u ${g_user} -p ${g_password} -pr ${g_project} -su ${g_subject} -se ${g_session} -r "${resource_name}" get_data -f "${file_name}" -i "${item_name}"`
	echo ${result}
}

does_resource_exist()
{
	local resource_name="${1}"
	local does_it_exist=`${XNAT_UTILS_HOME}/xnat_scan_info -s "${XNAT_PBS_JOBS_XNAT_SERVER}" -u ${g_user} -p ${g_password} -pr ${g_project} -su ${g_subject} -se ${g_session} -r "${resource_name}" check_resource_exists`
	echo ${does_it_exist}
}

does_first_t1w_scan_exist()
{
	local does_it_exist
	if [ -z "${g_first_t1w_resource_name}" ]; then
		does_it_exist="FALSE"
	else
		does_it_exist=`does_resource_exist "${g_first_t1w_resource_name}" check_resource_exists`
	fi
	echo ${does_it_exist}
}

get_parameters_for_first_t1w_scan() 
{
	g_first_t1w_sample_spacing=""
	g_first_t1w_deltaTE=""
	g_first_t1w_positive_dwell_time=""

	# sample_spacing value in XNAT DB is in nanoseconds, but needs to be specified in seconds
	g_first_t1w_sample_spacing=`get_scan_data "${g_first_t1w_resource_name}" "${g_first_t1w_file_name}" "parameters/readoutSampleSpacing"`
	sample_spacing_in_secs=`echo "${g_first_t1w_sample_spacing} 1000000000.0" | awk '{printf "%.9f", $1/$2}'`
	g_first_t1w_sample_spacing=${sample_spacing_in_secs}
	log_Msg "g_first_t1w_sample_spacing: ${g_first_t1w_sample_spacing}"

	if [[ ("${g_fieldmap_type}" = "GE") || ("${g_fieldmap_type}" = "SiemensGradientEcho") ]] ; then
		g_first_t1w_deltaTE=`get_scan_data "${g_first_t1w_resource_name}" "${g_session}_${MAG_FIELDMAP_NAME}${COMPRESSED_NIFTI_EXTENSION}" "parameters/deltaTE"`
		log_Msg "g_first_t1w_deltaTE: ${g_first_t1w_deltaTE}"

	elif [[ ("${g_fieldmap_type}" = "SE") || ("${g_fieldmap_type}" = "SpinEcho") ]] ; then
		g_first_t1w_positive_dwell_time=`get_scan_data "${g_first_t1w_resource_name}" "${g_se_phase_pos}" "parameters/echoSpacing"`
		log_Msg "g_first_t1w_positive_dwell_time: ${g_first_t1w_positive_dwell_time}"

	fi
}

does_second_t1w_scan_exist()
{
	local does_it_exist
	if [ -z "${g_second_t1w_resource_name}" ]; then
		does_it_exist="FALSE"
	else
		does_it_exist=`does_resource_exist "${g_second_t1w_resource_name}" check_resource_exists`
	fi
	echo ${does_it_exist}
}

does_first_t2w_scan_exist()
{
	local does_it_exist
	if [ -z "${g_first_t2w_resource_name}" ]; then
		does_it_exist="FALSE"
	else
		does_it_exist=`does_resource_exist "${g_first_t2w_resource_name}" check_resource_exists`
	fi
	echo ${does_it_exist}
}

get_parameters_for_first_t2w_scan()
{
	g_first_t2w_sample_spacing=""

	# sample_spacing value in XNAT DB is in nanoseconds, but needs to be specified in seconds
	g_first_t2w_sample_spacing=`get_scan_data "${g_first_t2w_resource_name}" "${g_first_t2w_file_name}" "parameters/readoutSampleSpacing"`
	sample_spacing_in_secs=`echo "${g_first_t2w_sample_spacing} 1000000000.0" | awk '{printf "%.9f", $1/$2}'`
	g_first_t2w_sample_spacing=${sample_spacing_in_secs}
	log_Msg "g_first_t2w_sample_spacing: ${g_first_t2w_sample_spacing}"
}

does_second_t2w_scan_exist()
{
	local does_it_exist
	if [ -z "${g_second_t2w_resource_name}" ]; then
		does_it_exist="FALSE"
	else
		does_it_exist=`does_resource_exist "${g_second_t2w_resource_name}" check_resource_exists`
	fi
	echo ${does_it_exist}
}

do_gradient_echo_field_maps_exist()
{
	magnitude_fieldmaps=`find ${XNAT_PBS_JOBS_ARCHIVE_ROOT}/${g_project}/arc001/${g_session}/RESOURCES/T[1-2]w*_unproc -maxdepth 1 -name "*${MAG_FIELDMAP_NAME}*"`
	phase_fieldmaps=`find ${XNAT_PBS_JOBS_ARCHIVE_ROOT}/${g_project}/arc001/${g_session}/RESOURCES/T[1-2]w*_unproc -maxdepth 1 -name "*${PHASE_FIELDMAP_NAME}*"`

	if [ -z "${magnitude_fieldmaps}" ] ; then
		echo "FALSE"
	elif [ -z "${phase_fieldmaps}" ] ; then
		echo "FALSE"
	else
		echo "TRUE"
	fi
}

# Main processing
#   Carry out the necessary steps to:
#   - get prerequisite data for the Strucutral Preprocessing pipeline 
#   - run the scripts
main()
{
	show_job_start

	show_platform_info
	
	get_options "$@"

	create_start_time_file ${g_working_dir} ${g_pipeline_name}

	source_script ${g_setup_script}

	source_script ${XNAT_PBS_JOBS}/ToolSetupScripts/epd-python_setup.sh

	# determine what resources exist and get parameters needed
	first_T1w_resource_exists=`does_first_t1w_scan_exist`
	log_Msg "first_T1w_resource_exists: ${first_T1w_resource_exists}"

	if [ "${first_T1w_resource_exists}" = "TRUE" ] ; then
		get_parameters_for_first_t1w_scan
	fi
	
	second_T1w_resource_exists=`does_second_t1w_scan_exist`
	log_Msg "second_T1w_resource_exists: ${second_T1w_resource_exists}"

	first_T2w_resource_exists=`does_first_t2w_scan_exist`
	log_Msg "first_T2w_resource_exists: ${first_T2w_resource_exists}"

	if [ "${first_T2w_resource_exists}" = "TRUE" ] ; then
		get_parameters_for_first_t2w_scan
	fi

	second_T2w_resource_exists=`does_second_t2w_scan_exist`
	log_Msg "second_T2w_resource_exists: ${second_T2w_resource_exists}"
	
	gradient_echo_field_maps_exist=`do_gradient_echo_field_maps_exist`
	log_Msg "gradient_echo_field_maps_exist: ${gradient_echo_field_maps_exist}"
	
	# build specification of T1w scans

	t1_spec=""
	
	if [ "${first_T1w_resource_exists}" = "TRUE" ]; then
		first_T1w_file="${g_working_dir}/${g_subject}/unprocessed/${g_session_classifier}/${g_first_t1w_directory_name}/${g_first_t1w_file_name}"
		if [ -e "${first_T1w_file}" ] ; then
			t1_spec+=${first_T1w_file}
		else
			log_Err_Abort "The first T1w file: '${first_T1w_file}' does not exist"
		fi
	else
		log_Err_Abort "NO FIRST T1W RESOURCE"
	fi

 	if [ "${second_T1w_resource_exists}" = "TRUE" ]; then
 		second_T1w_file="${g_working_dir}/${g_subject}/unprocessed/${g_session_classifier}/${g_second_t1w_directory_name}/${g_second_t1w_file_name}"
		
 		if [ -e "${second_T1w_file}" ] ; then
			t1_spec+=@
 			t1_spec+=${second_T1w_file}
 		else
 			log_Err_Abort "The second T1w file: '${second_T1w_file}' does not exist"
 		fi
 	else
		t1_spec+=@
		t1_spec+=${first_T1w_file}
 	fi

 	log_Msg "t1_spec: ${t1_spec}"

	# build specification of T2w scans
 	t2_spec=""

 	if [ "${first_T2w_resource_exists}" = "TRUE" ]; then
 		first_T2w_file="${g_working_dir}/${g_subject}/unprocessed/${g_session_classifier}/${g_first_t2w_directory_name}/${g_first_t2w_file_name}"
		
 		if [ -e "${first_T2w_file}" ] ; then
 			t2_spec+=${first_T2w_file}
 		else
 			log_Err_Abort "The first T2w file: '${first_T2w_file}' does not exist"
 		fi
 	else
 		log_Err_Abort "NO FIRST T2W RESOURCE"
 	fi

 	if [ "${second_T2w_resource_exists}" = "TRUE" ]; then
 		second_T2w_file="${g_working_dir}/${g_subject}/unprocessed/${g_session_classifier}/${g_second_t2w_directory}/${g_second_t2w_file_name}"

 		if [ -e "${second_T2w_file}" ] ; then
 			t2_spec+=@
			t2_spec+=${second_T2w_file}
		else
			log_Err_Abort "The second T2w file: '${second_T2w_file}' does not exist"
		fi
 	else
		t2_spec+=@
		t2_spec+=${first_T2w_file}
	fi
	
 	log_Msg "t2_spec: ${t2_spec}"
	
	# Run the PreFreeSurferPipeline.sh script
 	PreFreeSurfer_cmd=""
 	PreFreeSurfer_cmd+="${HCPPIPEDIR}/PreFreeSurfer/PreFreeSurferPipeline.sh"
 	PreFreeSurfer_cmd+=" --path=${g_working_dir}"
 	PreFreeSurfer_cmd+=" --subject=${g_subject}"
 	PreFreeSurfer_cmd+=" --t1=${t1_spec}"
 	PreFreeSurfer_cmd+=" --t2=${t2_spec}"
	PreFreeSurfer_cmd+=" --t1template=${HCPPIPEDIR}/global/templates/${g_t1template}"
	PreFreeSurfer_cmd+=" --t1templatebrain=${HCPPIPEDIR}/global/templates/${g_t1templatebrain}"
 	PreFreeSurfer_cmd+=" --t1template2mm=${HCPPIPEDIR}/global/templates/${g_t1template2mm}"
	PreFreeSurfer_cmd+=" --t2template=${HCPPIPEDIR}/global/templates/${g_t2template}"
 	PreFreeSurfer_cmd+=" --t2templatebrain=${HCPPIPEDIR}/global/templates/${g_t2templatebrain}"
 	PreFreeSurfer_cmd+=" --t2template2mm=${HCPPIPEDIR}/global/templates/${g_t2template2mm}"
	PreFreeSurfer_cmd+=" --templatemask=${HCPPIPEDIR}/global/templates/${g_templatemask}"
	PreFreeSurfer_cmd+=" --template2mmmask=${HCPPIPEDIR}/global/templates/${g_template2mmmask}"
	PreFreeSurfer_cmd+=" --fnirtconfig=${HCPPIPEDIR}/global/config/${g_fnirtconfig}"

	if [ "${g_gdcoeffs}" = "NONE" ]; then
		PreFreeSurfer_cmd+=" --gdcoeffs=${g_gdcoeffs}"
	else
		PreFreeSurfer_cmd+=" --gdcoeffs=${HCPPIPEDIR}/global/config/${g_gdcoeffs}"
	fi

	PreFreeSurfer_cmd+=" --brainsize=${g_brainsize}"

	if [[ ("${g_fieldmap_type}" == "GE") || ("${g_fieldmap_type}" == "SiemensGradientEcho") ]] ; then
		# add parameters for Siemens Gradient Echo fieldmap usage
		log_Msg "add parameters for Siemens Gradient Echo fieldmap usage"

		log_Msg "gradient_echo_field_maps_exist: ${gradient_echo_field_maps_exist}"
		if [[ "${gradient_echo_field_maps_exist}" == "TRUE" ]] ; then
			log_Msg "adding parameters for when Siemens gradient echo fieldmaps should be used and do exist"
			PreFreeSurfer_cmd+=" --echodiff=${g_first_t1w_deltaTE}"
			PreFreeSurfer_cmd+=" --t1samplespacing=${g_first_t1w_sample_spacing}"
			PreFreeSurfer_cmd+=" --t2samplespacing=${g_first_t2w_sample_spacing}"
			PreFreeSurfer_cmd+=" --avgrdcmethod=FIELDMAP"
			PreFreeSurfer_cmd+=" --topupconfig=NONE"
			PreFreeSurfer_cmd+=" --fmapmag=${g_working_dir}/${g_subject}/unprocessed/${g_session_classifier}/${FIRST_T1W_FILE_NAME_BASE}/${g_subject}_${g_session_classifier}_${MAG_FIELDMAP_NAME}${COMPRESSED_NIFTI_EXTENSION}"
			PreFreeSurfer_cmd+=" --fmapphase=${g_working_dir}/${g_subject}/unprocessed/${g_session_classifier}/${FIRST_T1W_FILE_NAME_BASE}/${g_subject}_${g_session_classifier}_${PHASE_FIELDMAP_NAME}${COMPRESSED_NIFTI_EXTENSION}"
			PreFreeSurfer_cmd+=" --unwarpdir=z"
		else
			log_Msg "adding parameters for when Siemens gradient echo fieldmaps should be used but do NOT exist"
			PreFreeSurfer_cmd+=" --echodiff=NONE"
			PreFreeSurfer_cmd+=" --t1samplespacing=NONE"
			PreFreeSurfer_cmd+=" --t2samplespacing=NONE"
			PreFreeSurfer_cmd+=" --avgrdcmethod=NONE"
			PreFreeSurfer_cmd+=" --topupconfig=NONE"
			PreFreeSurfer_cmd+=" --fmapmag=${g_working_dir}/${g_subject}/unprocessed/${g_session_classifier}/${FIRST_T1W_FILE_NAME_BASE}/${g_subject}_${g_session_classifier}_${MAG_FIELDMAP_NAME}${COMPRESSED_NIFTI_EXTENSION}"
			PreFreeSurfer_cmd+=" --fmapphase=${g_working_dir}/${g_subject}/unprocessed/${g_session_classifier}/${FIRST_T1W_FILE_NAME_BASE}/${g_subject}_${g_session_classifier}_${PHASE_FIELDMAP_NAME}${COMPRESSED_NIFTI_EXTENSION}"
			PreFreeSurfer_cmd+=" --unwarpdir=z"
		fi
	elif [[ ("${g_fieldmap_type}" == "SE") || ("${g_fieldmap_type}" == "SpinEcho") ]] ; then
		# add parameters for SpinEcho fieldmap usage
		PreFreeSurfer_cmd+=" --echodiff=NONE"
		PreFreeSurfer_cmd+=" --t1samplespacing=${g_first_t1w_sample_spacing}"
		PreFreeSurfer_cmd+=" --t2samplespacing=${g_first_t2w_sample_spacing}"
		PreFreeSurfer_cmd+=" --avgrdcmethod=TOPUP"
		PreFreeSurfer_cmd+=" --SEPhaseNeg=${g_working_dir}/${g_subject}/unprocessed/${g_session_classifier}/${g_first_t1w_directory_name}/${g_se_phase_neg}"
		PreFreeSurfer_cmd+=" --SEPhasePos=${g_working_dir}/${g_subject}/unprocessed/${g_session_classifier}/${g_first_t1w_directory_name}/${g_se_phase_pos}"
		PreFreeSurfer_cmd+=" --echospacing=${g_first_t1w_positive_dwell_time}"
		PreFreeSurfer_cmd+=" --topupconfig=${HCPPIPEDIR}/global/config/${g_topupconfig}"
		PreFreeSurfer_cmd+=" --seunwarpdir=y"
		PreFreeSurfer_cmd+=" --unwarpdir=z"
	else
		log_Err_Abort "Unrecognized g_fieldmap_type: ${g_fieldmap_type}"
	fi

	log_Msg ""
	log_Msg "PreFreeSurfer_cmd: ${PreFreeSurfer_cmd}"
	log_Msg ""
	
	pushd ${g_working_dir}
	${PreFreeSurfer_cmd}
	return_code=$?
	if [ ${return_code} -ne 0 ]; then
		log_Err_Abort "PreFreeSurferPipeline.sh non-zero return code: ${return_code}"
	fi
	popd

	# Run FreeSurferPipeline.sh script
 	FreeSurfer_cmd=""
	FreeSurfer_cmd+="${HCPPIPEDIR}/FreeSurfer/FreeSurferPipeline.sh"
	FreeSurfer_cmd+=" --subject=${g_subject}"
	FreeSurfer_cmd+=" --subjectDIR=${g_working_dir}/${g_subject}/T1w"
	FreeSurfer_cmd+=" --t1=${g_working_dir}/${g_subject}/T1w/T1w_acpc_dc_restore.nii.gz"
	FreeSurfer_cmd+=" --t1brain=${g_working_dir}/${g_subject}/T1w/T1w_acpc_dc_restore_brain.nii.gz"
	FreeSurfer_cmd+=" --t2=${g_working_dir}/${g_subject}/T1w/T2w_acpc_dc_restore.nii.gz"

	if [ ! -z "${g_seed}" ]; then
		FreeSurfer_cmd+=" --seed=${g_seed}"
	fi

	log_Msg ""
	log_Msg "FreeSurfer_cmd: ${FreeSurfer_cmd}"
	log_Msg ""
	
	pushd ${g_working_dir}
	${FreeSurfer_cmd}
	return_code=$?
	if [ ${return_code} -ne 0 ]; then
		log_Err_Abort "FreeSurferPipeline.sh non-zero return code: ${return_code}"
	fi
	popd

	# Run PostFreeSurferPipeline.sh script
 	PostFreeSurfer_cmd=""
	PostFreeSurfer_cmd+="${HCPPIPEDIR}/PostFreeSurfer/PostFreeSurferPipeline.sh"
	PostFreeSurfer_cmd+=" --path=${g_working_dir}"
	PostFreeSurfer_cmd+=" --subject=${g_subject}"
	PostFreeSurfer_cmd+=" --surfatlasdir=${HCPPIPEDIR}/global/templates/standard_mesh_atlases/"
	PostFreeSurfer_cmd+=" --grayordinatesdir=${HCPPIPEDIR}/global/templates/91282_Greyordinates"
	PostFreeSurfer_cmd+=" --grayordinatesres=2"
	PostFreeSurfer_cmd+=" --hiresmesh=164"
	PostFreeSurfer_cmd+=" --lowresmesh=32"
	PostFreeSurfer_cmd+=" --subcortgraylabels=${HCPPIPEDIR}/global/config/FreeSurferSubcorticalLabelTableLut.txt"
	PostFreeSurfer_cmd+=" --freesurferlabels=${HCPPIPEDIR}/global/config/FreeSurferAllLut.txt"
	PostFreeSurfer_cmd+=" --refmyelinmaps=${HCPPIPEDIR}/global/templates/standard_mesh_atlases/Conte69.MyelinMap_BC.164k_fs_LR.dscalar.nii"
	PostFreeSurfer_cmd+=" --regname=MSMSulc"

	log_Msg ""
	log_Msg "PostFreeSurfer_cmd: ${PostFreeSurfer_cmd}"
	log_Msg ""
	
	pushd ${g_working_dir}
	${PostFreeSurfer_cmd}
	return_code=$?
	if [ ${return_code} -ne 0 ]; then
		log_Err_Abort "PostFreeSurferPipeline.sh non-zero return code: ${return_code}"
	fi
	popd

	# # GENERATE_SNAPSHOT

	# # use a sub-shell so that freesurfer53_setup.sh only affects the snap_montage_cmd 
	# (
	# 	source "${XNAT_PBS_JOBS}/shlib/log.shlib"  # Logging related functions
		
	# 	snap_montage_cmd=""
	# 	snap_montage_cmd+="/export/HCP/bin/xvfb_wrapper.sh ${NRG_PACKAGES}/tools/HCP/Freesurfer/freesurfer_includes/snap_montage_fs5.csh"
	# 	snap_montage_cmd+=" ${g_subject}"
	# 	snap_montage_cmd+=" ${g_working_dir}/${g_subject}/T1w"
		
	# 	log_Msg ""
	# 	log_Msg "snap_montage_cmd: ${snap_montage_cmd}"
	# 	log_Msg ""
		
	# 	pushd ${g_working_dir}/${g_subject}
	# 	source ${XNAT_PBS_JOBS}/ToolSetupScripts/freesurfer53_setup.sh
	# 	${snap_montage_cmd}
	# 	return_code=$?
	# 	if [ ${return_code} -ne 0 ]; then
	# 		log_Err_Abort "snap_montage command non-zero return code: ${return_code}"
	# 	fi
	# 	popd
	# )

	# # Show created .gif files
	# log_Msg "Show the GIF files created by the snap_montage_fs5.csh script"
	# pushd ${g_working_dir}/${g_subject}
	# find . -name "*.gif"
	# popd
	
	# # CREATE_ASSESSOR

	# # Get XNAT Session ID (a.k.a. the experiment ID, e.g. ConnectomeDB_E1234)
	# log_Msg "Getting XNAT Session ID"
	# get_session_id_script="${XNAT_PBS_JOBS_PIPELINE_ENGINE}/catalog/ToolsHCP/resources/scripts/sessionid.py"
	# get_session_id_cmd="python ${get_session_id_script}"
	# get_session_id_cmd+=" --server=${g_server}"
	# get_session_id_cmd+=" --username=${g_user}"
	# get_session_id_cmd+=" --password=${g_password}"
	# get_session_id_cmd+=" --project=${g_project} "
	# get_session_id_cmd+=" --subject=${g_subject} "
	# get_session_id_cmd+=" --session=${g_session}"
	# sessionID=`${get_session_id_cmd}`
	# log_Msg "XNAT session ID: ${sessionID}"

 	# # Generate XNAT XML from FreeSurfer stats files	
	# stats2xml_cmd=""
	# stats2xml_cmd+="${NRG_PACKAGES}/tools/HCP/Freesurfer/freesurfer_includes/stats2xml_mrh.pl"
	# stats2xml_cmd+=" -p ${g_project}"
	# stats2xml_cmd+=" -x ${sessionID}"
	# stats2xml_cmd+=" -t Freesurfer"
	# stats2xml_cmd+=" -d ${g_session_classifier}"
	# stats2xml_cmd+=" -o ${g_working_dir}/${g_subject}/"
	# stats2xml_cmd+=" ${g_working_dir}/${g_subject}/T1w/${g_subject}/stats"

	# log_Msg "stats2xml_cmd: ${stats2xml_cmd}"

	# pushd ${g_working_dir}/${g_subject}
	# ${stats2xml_cmd}
	# return_code=$?
	# if [ ${return_code} -ne 0 ]; then
	# 	log_Err_Abort "stats2xml_cmd non-zero return code: ${return_code}"
	# fi
	# popd

	# # Show created *freesurfer5.xml file
	# log_Msg "Show freesurfer5.xml file created by stats2xml_mrh.pl"
	# pushd ${g_working_dir}/${g_subject}
	# find . -name "${sessionID}_freesurfer5.xml"
	# popd
	
	# # Put generated FreeSurfer stats file in DB

	# resource_uri="https://${g_server}/data/archive/projects/${g_project}/subjects/${g_subject}"
	# resource_uri+="/experiments/${sessionID}"
	# resource_uri+="/assessors/${sessionID}_freesurfer_${g_session_classifier}"
	# resource_uri+="?allowDataDeletion=true&inbody=true"
	
	# java_cmd="java -Xmx1024m -jar ${XNAT_PBS_JOBS_PIPELINE_ENGINE}/lib/xnat-data-client-1.6.4-SNAPSHOT-jar-with-dependencies.jar"
	# java_cmd+=" -u ${g_user}"
	# java_cmd+=" -p ${g_password}"
	# java_cmd+=" -r ${resource_uri}"	
	# java_cmd+=" -l ${g_working_dir}/${g_subject}/${sessionID}_freesurfer5.xml"
	# java_cmd+=" -m PUT"

	# log_Msg ""
	# log_Msg "java_cmd: ${java_cmd}"
	# log_Msg ""

	# pushd ${g_working_dir}/${g_subject}
	# ${java_cmd}
	# return_code=$?
	# if [ ${return_code} -ne 0 ]; then
	# 	log_Err_Abort "java_cmd non-zero return code: ${return_code}"
	# fi
	# popd

	# # Put snapshots in DB and remove local copies
	# db_resource="https://${g_server}/data/archive/projects/${g_project}/subjects/${g_subject}/experiments/${sessionID}/assessors/${sessionID}_freesurfer_${g_session_classifier}/resources/SNAPSHOTS"
	# log_Msg "db_resource: ${db_resource}"
	
	# local_resource="${g_working_dir}/${g_subject}/T1w/${g_subject}/snapshots"
	# log_Msg "local_resource: ${local_resource}"

	# # show files in local_resource
	# log_Msg "Files in ${local_resource}"
	# find ${local_resource} -print
	
	# # create zip file to send to DB
	# zipped_file=$(basename ${local_resource}).zip
	# log_Msg "zipped_file: ${zipped_file}"

	# pushd ${local_resource}

	# zip_cmd="zip --recurse-paths --test ${zipped_file} ."
	# log_Msg "zip_cmd: ${zip_cmd}"
	# ${zip_cmd}
	
	# # Replace very first instance of HCP in working directory name with data.
	# # So, for example, "/HCP/hcpdb/build_ssd/chpc/BUILD/HCP_Staging/..." becomes "/data/hcpdb/build_ssd/chpc/BUILD/HCP_Staging/..."
	# # The reference= part of the PUT operation expects a reference to something that is local to the machine
	# # running XNAT.
	# #	xnat_local_resource=${local_resource/HCP/data}
	# #	log_Msg "xnat_local_resource: ${xnat_local_resource}"
	# #	resource_uri="${db_resource}/files?overwrite=true&replace=true&reference=${xnat_local_resource}"
	
	# resource_uri="${db_resource}/files?overwrite=true&replace=true&extract=true"

	# java_cmd="java -Xmx1024m -jar ${XNAT_PBS_JOBS_PIPELINE_ENGINE}/lib/xnat-data-client-1.6.4-SNAPSHOT-jar-with-dependencies.jar"
	# java_cmd+=" -u ${g_user}"
	# java_cmd+=" -p ${g_password}"
	# java_cmd+=" -m PUT"
	# java_cmd+=" -r ${resource_uri}"	
	# java_cmd+=" -l ${zipped_file}"
	
	# log_Msg ""
	# log_Msg "java_cmd: ${java_cmd}"
	# log_Msg ""
	# ${java_cmd}
	# return_code=$?
	# if [ ${return_code} -ne 0 ]; then
	# 	log_Err_Abort "java_cmd non-zero return code: ${return_code}"
	# fi

	# popd
	
	# rm_cmd="rm -r ${local_resource}"
	# log_Msg ""
	# log_Msg "rm_cmd: ${rm_cmd}"
	# log_Msg ""
	# ${rm_cmd}

	log_Msg "Complete"
}

# Invoke the main function to get things started
main "$@"
