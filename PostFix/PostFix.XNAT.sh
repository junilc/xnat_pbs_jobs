#!/bin/bash

#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # PostFix.XNAT.sh
#
# ## Copyright Notice
#
# Copyright (C) 2015 The Human Connectome Project
#
# * Washington University in St. Louis
# * University of Minnesota
# * Oxford University
#
# ## Author(s)
#
# * Timothy B. Brown, Neuroinformatics Research Group, 
#   Washington University in St. Louis
#
# ## Description
#
# This script runs the PostFix pipeline script from the Human 
# Connectome Project for a specified project, subject, session, and scan 
# in the ConnectomeDB (db.humanconnectome.org) XNAT database.
#
# The script is run not as an XNAT pipeline (under the control of the
# XNAT Pipeline Engine), but in an "XNAT-aware" and "pipeline-like" manner.
#
# The data to be processed is retrieved via file system operations instead
# of using REST API calls to retrieve the data. So the database archive 
# and resource directory structure is "known and used" by this script.
# 
# This script can be invoked by a job submitted to a worker or execution
# node in a cluster, e.g. a Sun Grid Engine (SGE) managed or Portable Batch
# System (PBS) managed cluster. Alternatively, if the machine being used
# has adequate resources (RAM, CPU power, storage space), this script can 
# simply be invoked interactively.
#
#~ND~END~

echo "Job started on `hostname` at `date`"

# home directory for scripts to be sourced to setup the environment
SCRIPTS_HOME=/home/HCPpipeline/SCRIPTS
echo "SCRIPTS_HOME: ${SCRIPTS_HOME}"

# home directory for XNAT related utilities
XNAT_UTILS_HOME=/home/HCPpipeline/pipeline_tools/xnat_utilities
echo "XNAT_UTILS_HOME: ${XNAT_UTILS_HOME}"

# home directory for these XNAT PBS job scripts
XNAT_PBS_JOBS_HOME=/home/HCPpipeline/pipeline_tools/xnat_pbs_jobs
echo "XNAT_PBS_JOBS_HOME: ${XNAT_PBS_JOBS_HOME}"

# home directory for XNAT pipeline engine installation
XNAT_PIPELINE_HOME=/home/HCPpipeline/pipeline
echo "XNAT_PIPELINE_HOME: ${XNAT_PIPELINE_HOME}"

# root directory of the XNAT database archive
DATABASE_ARCHIVE_ROOT="/HCP/hcpdb/archive"
echo "DATABASE_ARCHIVE_ROOT: ${DATABASE_ARCHIVE_ROOT}"

# database project root directory name
#DATABASE_ARCHIVE_PROJECT_ROOT="arc001"
#echo "DATABASE_ARCHIVE_PROJECT_ROOT: ${DATABASE_ARCHIVE_PROJECT_ROOT}"

# database resources root directory name
#DATABASE_RESOURCES_ROOT="RESOURCES"
#echo "DATABASE_RESOURCES_ROOT: ${DATABASE_RESOURCES_ROOT}"

# Show script usage information 
usage()
{
    echo ""
    echo "  Run the HCP PostFix.sh pipeline script in an"
	echo "  XNAT-aware and XNAT-pipeline-like manner."
	echo ""
	echo "  Usage: PostFix.XNAT.sh <options>"
	echo ""
	echo "  Options: [ ] = optional, < > = user-supplied-value"
	echo ""
	echo "   [--help] : show usage information and exit"
	echo ""
	echo "    --user=<username>      : XNAT DB username"
	echo "    --password=<password>  : XNAT DB password"
	echo "    --server=<server>      : XNAT server (e.g. db.humanconnectome.org)"
	echo "    --project=<project>    : XNAT project (e.g. HCP_500)"
	echo "    --subject=<subject>    : XNAT subject ID within project (e.g. 100307)"
	echo "    --session=<session>    : XNAT session ID within project (e.g. 100307_3T)"
	echo "    --scan=<scan>          : Scan ID (e.g. rfMRI_REST1_LR)"
	echo "    --working-dir=<dir>    : Working directory in which to place retrieved data"
	echo "                             and in which to produce results"
	echo "    --workflow-id=<id>     : XNAT Workflow ID to update as steps are completed"
	echo ""
}

# Parse specified command line options and verify that required options are
# specified. "Return" the options to use in global variables.
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
	unset g_scan
	unset g_working_dir
	unset g_workflow_id

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
			--scan=*)
				g_scan=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--working-dir=*)
				g_working_dir=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--workflow-id=*)
				g_workflow_id=${argument/*=/""}
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

	if [ -z "${g_session}" ]; then
		echo "ERROR: session (--session=) required"
		error_count=$(( error_count + 1 ))
	else
		echo "g_session: ${g_session}"
	fi

	if [ -z "${g_scan}" ]; then
		echo "ERROR: scan (--scan=) required"
		error_count=$(( error_count + 1 ))
	else
		echo "g_scan: ${g_scan}"
	fi

	if [ -z "${g_working_dir}" ]; then
		echo "ERROR: working directory (--working-dir=) required"
		error_count=$(( error_count + 1 ))
	else
		echo "g_working_dir: ${g_working_dir}"
	fi

	if [ -z "${g_workflow_id}" ]; then
		echo "ERROR: workflow ID (--workflow-id=) required"
		error_count=$(( error_count + 1 ))
	else
		echo "g_workflow_id: ${g_workflow_id}"
	fi

	if [ ${error_count} -gt 0 ]; then
		echo "For usage information, use --help"
		exit 1
	fi
}

# Show information about the XNAT Workflow
show_xnat_workflow()
{
	${XNAT_UTILS_HOME}/xnat_workflow_info \
		--server="${g_server}" \
		--username="${g_user}" \
		--password="${g_password}" \
		--workflow-id="${g_workflow_id}" \
		show
}

# Update information (step id, step description, and percent complete)
# for the XNAT Workflow
update_xnat_workflow()
{
	local step_id=${1}
	local step_desc=${2}
	local percent_complete=${3}

	echo ""
	echo ""
	echo "---------- Step: ${step_id} "
	echo "---------- Desc: ${step_desc} "
	echo ""
	echo ""

	echo "update_xnat_workflow - workflow_id: ${g_workflow_id}"
	echo "update_xnat_workflow - step_id: ${step_id}"
	echo "update_xnat_workflow - set_desc: ${step_desc}"
	echo "update_xnat_workflow - percent_complete: ${percent_complete}"

	${XNAT_UTILS_HOME}/xnat_workflow_info \
		--server="${g_server}" \
		--username="${g_user}" \
		--password="${g_password}" \
		--workflow-id="${g_workflow_id}" \
		update \
		--step-id="${step_id}" \
		--step-description="${step_desc}" \
		--percent-complete="${percent_complete}"
}

# Mark the XNAT Workflow as complete
complete_xnat_workflow()
{
	${XNAT_UTILS_HOME}/xnat_workflow_info \
		--server="${g_server}" \
		--username="${g_user}" \
		--password="${g_password}" \
		--workflow-id="${g_workflow_id}" \
		complete
}

# Mark the XNAT Workflow as failed
fail_xnat_workflow()
{
	${XNAT_UTILS_HOME}/xnat_workflow_info \
		--server="${g_server}" \
		--username="${g_user}" \
		--password="${g_password}" \
		--workflow-id="${workflow_id}" \
		fail
}

# Update the XNAT Workflow to Failed status and exit this script
die()
{
	fail_xnat_workflow ${workflow_id}
	exit 1
}

# Main processing 
#   Carry out the necessary steps to: 
#   - get prerequisite data for PostFix.sh
#   - run the script
main()
{
	get_options $@

	source ${XNAT_PBS_JOBS_HOME}/GetHcpDataUtils/GetHcpDataUtils.sh

	# Set up step counters
	total_steps=7
	current_step=0

	# Set up to run Python
	echo "Setting up to run Python"
	source ${SCRIPTS_HOME}/epd-python_setup.sh

	show_xnat_workflow 

	# ----------------------------------------------------------------------------------------------
 	# Step - Get FIX processed data from DB
	# ----------------------------------------------------------------------------------------------
	current_step=$(( current_step + 1 ))
	step_percent=$(( (current_step * 100) / total_steps ))

	update_xnat_workflow ${current_step} "Get FIX processed data from DB" ${step_percent}

	get_hcp_fix_proc_data "${DATABASE_ARCHIVE_ROOT}" "${g_project}" "${g_subject}" "${g_session}" "${g_scan}" "${g_working_dir}"

	# ----------------------------------------------------------------------------------------------
	# Step - Create a start_time file
	# ----------------------------------------------------------------------------------------------
	current_step=$(( current_step + 1 ))
	step_percent=$(( (current_step * 100) / total_steps ))

	update_xnat_workflow ${current_step} "Create a start_time file" ${step_percent}
		
	start_time_file="${g_working_dir}/PostFix.starttime"
	if [ -e "${start_time_file}" ]; then
		echo "Removing old ${start_time_file}"
		rm -f ${start_time_file}
	fi
	
	echo "Creating start time file: ${start_time_file}"
	touch ${start_time_file} || die 
	ls -l ${start_time_file}

	# ----------------------------------------------------------------------------------------------
	# Step - Sleep for 1 minute to make sure any files created or modified
	#        by the PostFix.sh script are created at least 1 
	#        minute after the start_time file
	# ----------------------------------------------------------------------------------------------
	current_step=$(( current_step + 1 ))
	step_percent=$(( (current_step * 100) / total_steps ))

	update_xnat_workflow ${current_step} "Sleep for 1 minute" ${step_percent}
	sleep 1m || die 

	# ----------------------------------------------------------------------------------------------
	# Step - Run PostFix.sh script
	# ----------------------------------------------------------------------------------------------
	current_step=$(( current_step + 1 ))
	step_percent=$(( (current_step * 100) / total_steps ))

	update_xnat_workflow ${current_step} "Run PostFix.sh script" ${step_percent}
	
	# Source setup script to setup environment for running the script
	source ${SCRIPTS_HOME}/SetUpHCPPipeline_PostFix.sh
	
	# Run PostFix.sh script
	${HCPPIPEDIR}/PostFix/PostFix.sh \
		--path=${g_working_dir} \
		--subject=${g_subject} \
		--fmri-name=${g_scan} \
		--high-pass=2000 \
		--template-scene-dual-screen=${HCPPIPEDIR}/PostFix/PostFixScenes/ICA_Classification_DualScreenTemplate.scene \
		--template-scene-single-screen=${HCPPIPEDIR}/PostFix/PostFixScenes/ICA_Classification_SingleScreenTemplate.scene
	
	if [ $? -ne 0 ]; then
		die 
	fi

	# ----------------------------------------------------------------------------------------------
	# Step - Show any newly created or modified files
	# ----------------------------------------------------------------------------------------------
	current_step=$(( current_step + 1 ))
	step_percent=$(( (current_step * 100) / total_steps ))

	update_xnat_workflow ${current_step} "Show newly created or modified files" ${step_percent}
	
	echo "Newly created/modified files:"
	find ${g_working_dir}/${g_subject} -type f -newer ${start_time_file}
	
	# ----------------------------------------------------------------------------------------------
	# Step - Remove any files that are not newly created or modified
	# ----------------------------------------------------------------------------------------------
	current_step=$(( current_step + 1 ))
	step_percent=$(( (current_step * 100) / total_steps ))

	update_xnat_workflow ${current_step} "Remove files not newly created or modified" ${step_percent}
	
	echo "The following files are being removed"
	find ${g_working_dir}/${g_subject} -type f -not -newer ${start_time_file} -print -delete || die 
	
	# include removal of any empty directories
	echo "The following empty directories are being removed"
	find ${g_working_dir}/${g_subject} -type d -empty -delete || die 

	# ----------------------------------------------------------------------------------------------
	# Step - Complete Workflow
	# ----------------------------------------------------------------------------------------------
	current_step=$(( current_step + 1 ))
	step_percent=$(( (current_step * 100) / total_steps ))

	complete_xnat_workflow 
}

# Invoke the main function to get things started
main $@
