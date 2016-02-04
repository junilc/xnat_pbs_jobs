#!/bin/bash

# This pipeline's name 
PIPELINE_NAME="IcaFixProcessingHCP"

# home directory for these XNAT PBS job scripts
XNAT_PBS_JOBS_HOME=${HOME}/pipeline_tools/xnat_pbs_jobs
echo "XNAT_PBS_JOBS_HOME: ${XNAT_PBS_JOBS_HOME}"

# home directory for XNAT pipeline engine installation
XNAT_PIPELINE_HOME=${HOME}/pipeline
echo "XNAT_PIPELINE_HOME: ${XNAT_PIPELINE_HOME}"

# home directory for XNAT utilities
XNAT_UTILS_HOME=${HOME}/pipeline_tools/xnat_utilities
echo "XNAT_UTILS_HOME: ${XNAT_UTILS_HOME}"

# main build directory
BUILD_HOME="/HCP/hcpdb/build_ssd/chpc/BUILD"
echo "BUILD_HOME: ${BUILD_HOME}"

# set up to run Python
echo "Setting up to run Python"
source ${SCRIPTS_HOME}/epd-python_setup.sh

# root directory of the XNAT database archive
DATABASE_ARCHIVE_ROOT="/HCP/hcpdb/archive"
echo "DATABASE_ARCHIVE_ROOT: ${DATABASE_ARCHIVE_ROOT}"

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
	unset g_put_server

	# parse arguments
	local num_args=${#arguments[@]}
	local argument
	local index=0

	while [ ${index} -lt ${num_args} ]; do
		argument=${arguments[index]}

		case ${argument} in
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
			--put-server=*)
				g_put_server=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			*)
				echo "ERROR: unrecognized option: ${argument}"
				echo ""
				exit 1
				;;
		esac
	done

	# set defaults and prompt for some unspecified parameters
	if [ -z "${g_user}" ]; then
		printf "Enter Connectome DB Username: "
		read g_user
	fi

	if [ -z "${g_password}" ]; then
		stty -echo
		printf "Enter Connectome DB Password: "
		read g_password
		echo ""
		stty echo
	fi

	if [ -z "${g_server}" ]; then
		g_server="db.humanconnectome.org"
	fi
	echo "Connectome DB Server: ${g_server}"

	if [ -z "${g_project}" ]; then
		g_project="HCP_Staging"
	fi
    echo "Connectome DB Project: ${g_project}"

	if [ -z "${g_subject}" ]; then
		printf "Enter Connectome DB Subject: "
		read g_subject
	fi
	echo "Connectome DB Subject: ${g_subject}"

	if [ -z "${g_session}" ]; then
		g_session=${g_subject}_3T
	fi
	echo "Connectome DB Session: ${g_session}"

	if [ -z "${g_put_server}" ]; then
		g_put_server="db.humanconnectome.org"
	fi
	echo "PUT server: ${g_put_server}"
}

main()
{
	get_options $@

	phase_encoding_dirs="LR RL"

	# Determine what resting state scans are available and preprocessed for the subject
	pushd ${DATABASE_ARCHIVE_ROOT}/${g_project}/arc001/${g_session}/RESOURCES

	resting_state_scan_names=""
	resting_state_scan_dirs=`ls -d rfMRI_*_preproc`
	for resting_state_scan_dir in ${resting_state_scan_dirs} ; do
		scan_name=${resting_state_scan_dir%%_preproc}
		
		for pe_dir in ${phase_encoding_dirs} ; do
			scan_name=${scan_name%%_${pe_dir}}
		done

		scan_name=${scan_name##rfMRI_}
		resting_state_scan_names=${resting_state_scan_names//$scan_name/}
		resting_state_scan_names+=" ${scan_name}"
	done

	popd

	echo "Resting state scans preprocessed and ready for subject: ${resting_state_scan_names}"

	# Submit jobs for each preprocessed resting state scan 

	for scan_name in ${resting_state_scan_names} ; do

		echo "scan_name: ${scan_name}"

		prefix="rfMRI"
		
		for pe_dir in ${phase_encoding_dirs} ; do

			scan="${prefix}_${scan_name}_${pe_dir}"

			echo "--------------------------------------------------"
			echo "Submitting jobs for scan: ${scan}"
			echo "--------------------------------------------------"

			# Get token user id and password
			echo "Getting token user id and password"
			get_token_cmd="${XNAT_UTILS_HOME}/xnat_get_tokens --server=${g_server} --username=${g_user} --password=${g_password}"
			new_tokens=`${get_token_cmd}`
			token_username=${new_tokens% *}
			token_password=${new_tokens#* }
			echo "token_username: ${token_username}"
			echo "token_password: ${token_password}"

			# make sure working directories don't have the same name based on the 
			# same start time by sleeping a few seconds
			sleep 5s

			current_seconds_since_epoch=`date +%s`
			working_directory_name="${BUILD_HOME}/${g_project}/IcaFixProcessingHCP_${current_seconds_since_epoch}_${g_subject}_${scan}"

			# Make the working directory
			echo "Making working directory: ${working_directory_name}"
			mkdir -p ${working_directory_name}

			# Get JSESSION ID
			echo "Getting JSESSION ID"
			jsession=`curl -u ${g_user}:${g_password} https://db.humanconnectome.org/data/JSESSION`
			echo "jsession: ${jsession}"

			# Get XNAT Session ID (a.k.a. the experiment ID, e.g. ConnectomeDB_E1234)
			echo "Getting XNAT Session ID"
			get_session_id_cmd=""
			get_session_id_cmd+="python ${XNAT_PIPELINE_HOME}/catalog/ToolsHCP/resources/scripts/sessionid.py "
			get_session_id_cmd+="--server=db.humanconnectome.org "
			get_session_id_cmd+="--username=${g_user} "
			get_session_id_cmd+="--project=${g_project} "
			get_session_id_cmd+="--subject=${g_subject} "
			get_session_id_cmd+="--session=${g_session} "
			get_session_id_cmd+=" --password=${g_password}"

			sessionID=`${get_session_id_cmd}`
			echo "XNAT session ID: ${sessionID}"

			# Get XNAT Workflow ID
			server="https://db.humanconnectome.org/"
			echo "Getting XNAT workflow ID for this job from server: ${server}"
			get_workflow_id_cmd=""
			get_workflow_id_cmd+="python ${XNAT_PIPELINE_HOME}/catalog/ToolsHCP/resources/scripts/workflow.py"
			get_workflow_id_cmd+=" -User ${g_user}"
			get_workflow_id_cmd+=" -Server ${server}"
			get_workflow_id_cmd+=" -ExperimentID ${sessionID}"
			get_workflow_id_cmd+=" -ProjectID ${g_project}"
			get_workflow_id_cmd+=" -Pipeline ${PIPELINE_NAME}_${scan}"
			get_workflow_id_cmd+=" -Status Queued"
			get_workflow_id_cmd+=" -JSESSION ${jsession}"
			echo "get_workflow_id_cmd: ${get_workflow_id_cmd}"
			get_workflow_id_cmd+=" -Password ${g_password}"
			
			workflowID=`${get_workflow_id_cmd}`
			if [ $? -ne 0 ]; then
				echo "Fetching workflow failed. Aborting"
				echo "workflowID: ${workflowID}"
				exit 1
			elif [[ ${workflowID} == HTTP* ]]; then
				echo "Fetching workflow failed. Aborting"
				echo "worflowID: ${workflowID}"
				exit 1
			fi
			echo "XNAT workflow ID: ${workflowID}"
			
			# Submit job to actually do the work
			script_file_to_submit=${working_directory_name}/${g_subject}.${scan}.IcaFixProcessingHCP.${g_project}.${g_session}.${current_seconds_since_epoch}.XNAT_PBS_job.sh
			if [ -e "${script_file_to_submit}" ]; then
				rm -f "${script_file_to_submit}"
			fi
			
			touch ${script_file_to_submit}
			echo "#PBS -l nodes=1:ppn=1,walltime=24:00:00,vmem=55000mb" >> ${script_file_to_submit}
			echo "#PBS -o ${working_directory_name}" >> ${script_file_to_submit}
			echo "#PBS -e ${working_directory_name}" >> ${script_file_to_submit}
			echo "" >> ${script_file_to_submit}
			echo "${XNAT_PBS_JOBS_HOME}/IcaFixProcessingHCP/IcaFixProcessingHCP.XNAT.sh \\" >> ${script_file_to_submit}
			echo "  --user=\"${token_username}\" \\" >> ${script_file_to_submit}
			echo "  --password=\"${token_password}\" \\" >> ${script_file_to_submit}
			echo "  --server=\"${g_server}\" \\" >> ${script_file_to_submit}
			echo "  --project=\"${g_project}\" \\" >> ${script_file_to_submit}
			echo "  --subject=\"${g_subject}\" \\" >> ${script_file_to_submit}
			echo "  --session=\"${g_session}\" \\" >> ${script_file_to_submit}
			echo "  --scan=\"${scan}\" \\" >> ${script_file_to_submit}
			echo "  --working-dir=\"${working_directory_name}\" \\" >> ${script_file_to_submit}
			echo "  --workflow-id=\"${workflowID}\" \\" >> ${script_file_to_submit} 
			echo "  --xnat-session-id=${sessionID}" >> ${script_file_to_submit}
		
			chmod +x ${script_file_to_submit}

			submit_cmd="qsub ${script_file_to_submit}"
			echo "submit_cmd: ${submit_cmd}"			

			processing_job_no=`${submit_cmd}`
			echo "processing_job_no: ${processing_job_no}"

			if [ -z "${processing_job_no}" ] ; then
				echo "ERROR SUBMITTING PROCESSING JOB - ABORTING"
				exit 1
			fi

			# Submit job to put the results in the DB
 			put_script_file_to_submit=${LOG_DIR}/${g_subject}.${scan}.IcaFixProcessingHCP.${g_project}.${g_session}.${current_seconds_since_epoch}.XNAT_PBS_PUT_job.sh
 			if [ -e "${put_script_file_to_submit}" ]; then
 				rm -f "${put_script_file_to_submit}"
 			fi

 			touch ${put_script_file_to_submit}
 			echo "#PBS -l nodes=1:ppn=1,walltime=4:00:00,vmem=12000mb" >> ${put_script_file_to_submit}
 			echo "#PBS -q HCPput" >> ${put_script_file_to_submit}
 			echo "#PBS -o ${LOG_DIR}" >> ${put_script_file_to_submit}
 			echo "#PBS -e ${LOG_DIR}" >> ${put_script_file_to_submit}
 			echo "" >> ${put_script_file_to_submit}
			echo "${XNAT_PBS_JOBS_HOME}/WorkingDirPut/XNAT_working_dir_put.sh \\" >> ${put_script_file_to_submit}
 			echo "  --user=\"${g_user}\" \\" >> ${put_script_file_to_submit}
 			echo "  --password=\"${g_password}\" \\" >> ${put_script_file_to_submit}
			echo "  --server=\"${g_put_server}\" \\" >> ${put_script_file_to_submit}
 			echo "  --project=\"${g_project}\" \\" >> ${put_script_file_to_submit}
 			echo "  --subject=\"${g_subject}\" \\" >> ${put_script_file_to_submit}
 			echo "  --session=\"${g_session}\" \\" >> ${put_script_file_to_submit}
 			echo "  --working-dir=\"${working_directory_name}\" \\" >> ${put_script_file_to_submit}
			echo "  --resource-suffix=\"${scan}_FIX_TEST\" \\" >> ${put_script_file_to_submit}
			echo "  --reason=\"${scan}_IcaFixProcessingHCP\" " >> ${put_script_file_to_submit}

			chmod +x ${put_script_file_to_submit}

			submit_cmd="qsub -W depend=afterok:${processing_job_no} ${put_script_file_to_submit}"
			echo "submit_cmd: ${submit_cmd}"
			${submit_cmd}

		done # pe_dir in ${phase_encoding_dirs}

	done # scan_name in ${resting_state_scan_names}

}

# Invoke the main function to get things started
main $@