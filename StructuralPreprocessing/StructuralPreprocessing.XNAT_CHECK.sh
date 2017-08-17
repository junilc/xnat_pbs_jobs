#!/bin/bash
g_script_name=$(basename "${0}")

if [ -z "${XNAT_PBS_JOBS}" ]; then
	echo "${g_script_name}: ABORTING: XNAT_PBS_JOBS environment variable must be set"
	exit 1
fi

source "${XNAT_PBS_JOBS}/shlib/log.shlib"  # Logging related functions
source "${XNAT_PBS_JOBS}/shlib/utils.shlib"  # Utility functions
log_Msg "XNAT_PBS_JOBS: ${XNAT_PBS_JOBS}"

if [ -z "${XNAT_PBS_JOBS_ARCHIVE_ROOT}" ]; then
	log_Err_Abort "XNAT_PBS_JOBS_ARCHIVE_ROOT environment variable must be set"
else
	log_Msg "XNAT_PBS_JOBS_ARCHIVE_ROOT: ${XNAT_PBS_JOBS_ARCHIVE_ROOT}"
fi

usage()
{
	cat <<EOF

Check a created Structural Preprocessing resource for completeness

Usage: ${g_script_name} PARAMETER..."

PARAMETERs are [ ] = optional; < > = user supplied value
  [--help]                   : show usage information and exit with non-zero return code
   --user=<username>         : XNAT DB username
   --password=<password>     : XNAT DB password
   --server=<server>         : XNAT server
   --project=<project>       : XNAT project (e.g. HCP_500)
   --subject=<subject>       : XNAT subject ID within project (e.g. 100307)
   --classifier=<classifier> : XNAT session classifier (e.g. 3T, 7T, MR, V1, V2, etc.)
   --working-dir=<dir>       : Working directory in which to place retrieved data
                               and in which to produce results

EOF
}

get_options()
{
	local arguments=($@)

	# initialize global output variables
	unset g_user
	unset g_password
	unset g_server
	unset g_project
	unset g_subject
	unset g_classifier
	unset g_working_dir

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
				g_project=${argument#*=}
				index=$(( index + 1 ))
				;;
			--subject=*)
				g_subject=${argument#*=}
				index=$(( index + 1 ))
				;;
			--classifier=*)
				g_classifier=${argument#*=}
				index=$(( index + 1 ))
				;;
			--working-dir=*)
				g_working_dir=${argument#*=}
				index=$(( index + 1 ))
				;;
			*)
				usage
				log_Err_Abort "unrecognized option ${argument}"
				;;
		esac
	done

	local error_count=0

	# check required parameters
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

	if [ -z "${g_classifier}" ]; then
		g_classifier="3T"
	fi
	log_Msg "g_classifier: ${g_classifier}"
	
	if [ -z "${g_working_dir}" ]; then
		log_Err "working directory (--working-dir=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_working_dir: ${g_working_dir}"
	fi

	# check required environment variables
	if [ -z "${XNAT_PBS_JOBS}" ]; then
		log_Err "XNAT_PBS_JOBS environment variable must be set"
		error_count=$(( error_count + 1 ))
	else
		g_xnat_pbs_jobs=${XNAT_PBS_JOBS}
		log_Msg "g_xnat_pbs_jobs: ${g_xnat_pbs_jobs}"
	fi

	if [ ${error_count} -gt 0 ]; then
		log_Err_Abort "For usage information, use --help"
	fi
}

main()
{
	show_job_start

	show_platform_info

	get_options "$@"

	# Link CinaB-style data
	log_Msg "Activating Python 3"
	source activate python3 2>&1

	log_file_name="${g_script_name}.log"
	success_file_name="${g_script_name}.success"

	check_cmd=""
	check_cmd+="${g_xnat_pbs_jobs}/lib/ccf/structural_preprocessing/one_subject_completion_checker.py"
	check_cmd+=" --project=${g_project}"
	check_cmd+=" --subject=${g_subject}"
	check_cmd+=" --classifier=${g_classifier}"
	check_cmd+=" --verbose"
	check_cmd+=" --output=${log_file_name}"
	check_cmd+=" --check-all"
	
	pushd ${g_working_dir}
	
	rm -f ${log_file_name}
	log_Msg "check_cmd: ${check_cmd}"
	${check_cmd}
	check_cmd_ret_code=$?

	log_Msg "check_cmd_ret_code=${check_cmd_ret_code}"

	if [ "${check_cmd_ret_code}" -eq 0 ]; then
		log_Msg "Completion Check was successful"
		echo "Completion Check was successful" >> ${log_file_name}
		echo "Completion Check was successful" >  ${success_file_name}

		put_success_file_cmd=""
		put_success_file_cmd+="${g_xnat_pbs_jobs}/WorkingDirPut/PutFileIntoResource.sh"
		put_success_file_cmd+=" --user=${g_user}"
		put_success_file_cmd+=" --password=${g_password}"
		put_success_file_cmd+=" --protocol=http"
		put_success_file_cmd+=" --server=${g_server}"
		put_success_file_cmd+=" --project=${g_project}"
		put_success_file_cmd+=" --subject=${g_subject}"
		put_success_file_cmd+=" --session=${g_subject}_${g_classifier}"
		put_success_file_cmd+=" --resource=Structural_preproc"
		put_success_file_cmd+=" --file=${success_file_name}"
		put_success_file_cmd+=" --file-path-within-resource=${success_file_name}"
		put_success_file_cmd+=" --force"
		put_success_file_cmd+=" --use-http"
		
		#log_Msg "put_success_file_cmd: ${put_success_file_cmd}"
		${put_success_file_cmd}
		
	else
		log_Msg "Completion Check was unsuccessful"
		echo "Completion Check was unsuccessful" >> ${log_file_name}
		rm -f ${success_file_name}

		success_file_in_archive=""
		success_file_in_archive+="${XNAT_PBS_JOBS_ARCHIVE_ROOT}/${g_project}"
		success_file_in_archive+="/arc001/${g_subject}_${g_classifier}/RESOURCES"
		success_file_in_archive+="/Structural_preproc/${success_file_name}"

		if [ -e ${success_file_in_archive} ] ; then
			remove_file_cmd=""
			remove_file_cmd+="${g_xnat_pbs_jobs}/WorkingDirPut/RemoveFileFromResource.sh"
			remove_file_cmd+=" --user=${g_user}"
			remove_file_cmd+=" --password=${g_password}"
			remove_file_cmd+=" --protocol=http"
			remove_file_cmd+=" --server=${g_server}"
			remove_file_cmd+=" --project=${g_project}"
			remove_file_cmd+=" --subject=${g_subject}"
			remove_file_cmd+=" --session=${g_subject}_${g_classifier}"
			remove_file_cmd+=" --resource=Structural_preproc"
			remove_file_cmd+=" --file-path-within-resource=${success_file_name}"

			${remove_file_cmd}
		fi

	fi

	put_log_file_cmd=""
	put_log_file_cmd+="${g_xnat_pbs_jobs}/WorkingDirPut/PutFileIntoResource.sh"
	put_log_file_cmd+=" --user=${g_user}"
	put_log_file_cmd+=" --password=${g_password}"
	put_log_file_cmd+=" --protocol=http"
	put_log_file_cmd+=" --server=${g_server}"
	put_log_file_cmd+=" --project=${g_project}"
	put_log_file_cmd+=" --subject=${g_subject}"
	put_log_file_cmd+=" --session=${g_subject}_${g_classifier}"
	put_log_file_cmd+=" --resource=Structural_preproc"
	put_log_file_cmd+=" --file=${log_file_name}"
	put_log_file_cmd+=" --file-path-within-resource=${log_file_name}"
	put_log_file_cmd+=" --force"
	put_log_file_cmd+=" --use-http"
	
	log_Msg "put_log_file_cmd: ${put_log_file_cmd}"
	${put_log_file_cmd}
	
	popd	

	# clean up
	if [ "${check_cmd_ret_code}" -eq 0 ]; then
	    rm -rf ${g_working_dir}
	fi
	
	log_Msg "Complete"
}

# Invoke the main to get things started
main "$@"
