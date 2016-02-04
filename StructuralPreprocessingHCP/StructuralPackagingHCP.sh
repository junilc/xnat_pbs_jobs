#!/bin/bash

echo "Job started on `hostname` at `date`"

# home directory for scripts to be sourced to setup the environment
SCRIPTS_HOME=${HOME}/SCRIPTS
echo "SCRIPTS_HOME: ${SCRIPTS_HOME}"

# root directory of the XNAT database archive
export XNAT_ARCHIVE_ROOT="/HCP/hcpdb/archive"
echo "XNAT_ARCHIVE_ROOT: ${XNAT_ARCHIVE_ROOT}"

usage()
{
	echo "usage: TBW"
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
				g_project=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--subject=*)
				g_subject=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--working-dir=*)
				g_working_dir=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			*)
				usage
				echo "ERROR: unrecognized option: ${argument}"
				echo ""
				exit 1
				;;
		esac
	done

	local error_count=0

	# check required parameters
	if [ -z "${g_user}" ]; then
		echo "ERROR: user (--user=) required"
		error_count=$(( error_count + 1 ))
	else
		echo "g_user: ${g_user}"
	fi

	if [ -z "${g_password}" ]; then
		echo "ERROR: password (--password=) required"
		error_count=$(( error_count + 1 ))
	else
		echo "g_password: *******"
	fi

	if [ -z "${g_server}" ]; then
		echo "ERROR: server (--server=) required"
		error_count=$(( error_count + 1 ))
	else
		echo "g_server: ${g_server}"
	fi

	if [ -z "${g_project}" ]; then
		echo "ERROR: project (--project=) required"
		error_count=$(( error_count + 1 ))
	else
		echo "g_project: ${g_project}"
	fi

	if [ -z "${g_subject}" ]; then
		echo "ERROR: subject (--subject=) required"
		error_count=$(( error_count + 1 ))
	else
		echo "g_subject: ${g_subject}"
	fi

	if [ -z "${g_working_dir}" ]; then
		echo "ERROR: working directory (--working-dir=) required"
		error_count=$(( error_count + 1 ))
	else
		echo "g_working_dir: ${g_working_dir}"
	fi

	if [ ${error_count} -gt 0 ]; then
		echo "For usage information, use --help"
		exit 1
	fi
}

# Main processing
main()
{
	get_options $@

	echo "Setting up to run Python"
	source ${SCRIPTS_HOME}/epd-python_setup.sh

	echo "Setting up to run Groovy"
	source ${SCRIPTS_HOME}/groovy_setup.sh

	pkg_cmd=""
	pkg_cmd+="${NRG_PACKAGES}/tools/packaging/callPackager.sh "
	pkg_cmd+=" --host ${g_server}"
	pkg_cmd+=" --user ${g_user}"
	pkg_cmd+=" --pw ${g_password}"
	#pkg_cmd+=" --outDir /HCP/hcpdb/packages/prerelease/zip" # should be the same place as below
	pkg_cmd+=" --outDir /HCP/OpenAccess/prerelease/zip"
	pkg_cmd+=" --buildDir ${g_working_dir}"
	pkg_cmd+=" --project ${g_project}"
	pkg_cmd+=" --subject ${g_subject}"
	pkg_cmd+=" --outputFormat PACKAGE" # [CINAB | PACKAGE]
	pkg_cmd+=" --outputType PREPROC"   # [UNPROC | PREPROC | ANALYSIS | FIX]
	pkg_cmd+=" --packet STRUCTURAL"    # [STRUCTURAL | FUNCTIONAL | DIFFUSION]

	echo ""
	echo "pkg_cmd: ${pkg_cmd}"
	echo ""

	${pkg_cmd}
}

# Invoke the main function to get things started
main $@
