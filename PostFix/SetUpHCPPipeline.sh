#!/bin/bash 

log()
{
	local msg="$*"
	local date_time
	date_time=$(date)
	local tool_name="PostFix/SetUpHCPPipeline.sh"
	echo "${date_time} - ${tool_name} - ${msg}" 
}

log "Setting up for running PostFix pipeline"
log "This script must be SOURCED to correctly setup the environment"

if [ -z "${COMPUTE}" ]; then
	log "COMPUTE value unset.  Setting to the default of CHPC"
	export COMPUTE="CHPC"
fi

if [ "$COMPUTE" = "CHPC" ]; then
	log "Setting up for processing on ${COMPUTE}"

	if [ "${CLUSTER}" = "2.0" ] ; then
 		log "Setting up for CHPC cluster ${CLUSTER}"

		# FSL
		export FSLDIR=${HOME}/export/fsl-5.0.9-custom-bedpostx-20161206
		source ${FSLDIR}/etc/fslconf/fsl.sh
		log "Set up to use FSL at ${FSLDIR}"

		# bet2 binary in FSL-5.0.9 needs newer version of libstdc++.so.6
		# found in /act/gcc-4.7.2/lib64
		if [ -z "${LD_LIBRARY_PATH}" ] ; then
			export LD_LIBRARY_PATH=/act/gcc-4.7.2/lib64
		else
		 	export LD_LIBRARY_PATH=/act/gcc-4.7.2/lib64:${LD_LIBRARY_PATH}
		fi
		log "Added /act/gcc-4.7.2/lib64 to LD_LIBRARY_PATH"
		log "LD_LIBRARY_PATH: ${LD_LIBRARY_PATH}"

		# FreeSurfer
		export FSL_DIR="${FSLDIR}"
		export FREESURFER_HOME=/act/freesurfer-5.3.0-HCP
		source ${FREESURFER_HOME}/SetUpFreeSurfer.sh
		log "Set up to use FreeSurfer at ${FREESURFER_HOME}"

		# EPD Python
		export EPD_PYTHON_HOME=${HOME}/export/epc-7.3.2
		export PATH=${EPD_PYTHON_HOME}/bin:${PATH}
		log "Set up to use EPD Python at ${EPD_PYTHON_HOME}"

		# Connectome Workbench
		export CARET7DIR=${HOME}/pipeline_tools/workbench-v1.2.3/bin_rh_linux64
		log "Set up to use Workbench at ${CARET7DIR}"

		# HCP Pipeline Scripts
		export HCPPIPEDIR=${HOME}/pipeline_tools/Pipelines_dev
		export HCPPIPEDIR_Config=${HCPPIPEDIR}/global/config
		export HCPPIPEDIR_Global=${HCPPIPEDIR}/global/scripts
		export HCPPIPEDIR_Templates=${HCPPIPEDIR}/global/templates
		export HCPPIPEDIR_PreFS=${HCPPIPEDIR}/PreFreeSurfer/scripts
		export HCPPIPEDIR_FS=${HCPPIPEDIR}/FreeSurfer/scripts
		export HCPPIPEDIR_PostFS=${HCPPIPEDIR}/PostFreeSurfer/scripts
		export HCPPIPEDIR_fMRISurf=${HCPPIPEDIR}/fMRISurface/scripts
		export HCPPIPEDIR_fMRIVol=${HCPPIPEDIR}/fMRIVolume/scripts
		export HCPPIPEDIR_dMRI=${HCPPIPEDIR}/DiffusionPreprocessing/scripts
		export HCPPIPEDIR_tfMRIAnalysis=${HCPPIPEDIR}/TaskfMRIAnalysis/scripts
		log "Set up to use HCP Pipelines at ${HCPPIPEDIR}"

		# MSM
		export MSMBINDIR=${HOME}/pipeline_tools/MSM_HOCR_v2/Centos
		log "Set up to use MSM binary at ${MSMBINDIR}"

		export MSMCONFIGDIR=${HCPPIPEDIR}/MSMConfig
		log "Set MSM configuration files directory to ${MSMCONFIGDIR}"

		# MATLAB
		export MATLAB_COMPILER_RUNTIME=/export/matlab/MCR/R2016b/v91
		log "Set MATLAB_COMPILER_RUNTIME to: ${MATLAB_COMPILER_RUNTIME}"

	else # unhandled value for ${CLUSTER}
		log "Processing setup for cluster ${CLUSTER} is currently not supported."
		log "EXITING WITH NON-ZERO EXIT STATUS (UNSUCCESSFUL EXECUTION)"
		exit 1

	fi

else # unhandled value for ${COMPUTE}
	log "Processing setup for ${COMPUTE} is currently not supported."
	log "EXITING WITH NON-ZERO EXIT STATUS (UNSUCCESSFUL EXECUTION)"
	exit 1

fi

unset -f log
