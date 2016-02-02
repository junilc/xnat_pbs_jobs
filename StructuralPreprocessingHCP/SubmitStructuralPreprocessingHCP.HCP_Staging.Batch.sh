#!/bin/bash

if [ -z "${SUBJECT_FILES_DIR}" ]; then
	echo "Environment variable SUBJECT_FILES_DIR must be set!"
	exit 1
fi

printf "Connectome DB Username: "
read userid

stty -echo
printf "Connectome DB Password: "
read password
echo ""
stty echo

echo "If you do not specify a seed, then a seed specification"
echo "will not be passed to the pipeline and the default random"
echo "number generator seed will be used."
printf "Random Number Generator Seed []: "
read seed

printf "Delay until first submission (minutes) [0]: "
read delay

if [ -z "${delay}" ]; then
	delay=0
fi

printf "Interval between submissions (minutes) [60]: "
read interval

if [ -z "${interval}" ]; then
	interval=60
fi

project="HCP_Staging"
subject_file_name="${SUBJECT_FILES_DIR}/${project}.StructuralPreprocessingHCP.subjects"
echo "Retrieving subject list from: ${subject_file_name}"
subject_list_from_file=( $( cat ${subject_file_name} ) )
subjects="`echo "${subject_list_from_file[@]}"`"

start_shadow_number=1
max_shadow_number=8

shadow_number=${start_shadow_number}

# Doesn't seem to work with at command, but works fine submitting job without at
use_at="FALSE"

for subject in ${subjects} ; do

	if [[ ${subject} != \#* ]]; then

		server="db-shadow${shadow_number}.nrg.mir:8080"

 		echo ""
		echo "--------------------------------------------------------------------------------"
		echo " Submitting Structural Preprocessing job for subject: ${subject}"
		echo " Using server: ${server}"
		echo " Submission delayed until ${delay} minutes from now"
		echo "--------------------------------------------------------------------------------"

		cmd_to_run=""
		cmd_to_run+="${HOME}/pipeline_tools/xnat_pbs_jobs/StructuralPreprocessingHCP/SubmitStructuralPreprocessingHCP.OneSubject.sh "
		cmd_to_run+=" --user=${userid}"
		cmd_to_run+=" --put-server=${server}"
		cmd_to_run+=" --project=${project}"
		cmd_to_run+=" --subject=${subject}"
		if [ ! -z "${seed}" ] ; then
			cmd_to_run+=" --seed=${seed}"
		fi
		echo "cmd_to_run: ${cmd_to_run}"
		cmd_to_run+=" --password=${password}"

		if [ "${use_at}" = "TRUE" ] ; then

		    echo "About to use at to run command"
 		    at now + ${delay} minutes <<EOF 
			${cmd_to_run}
EOF
		else
		    echo "About to simply run command"
		    ${cmd_to_run}
		fi

		delay=$((delay + interval))

		shadow_number=$((shadow_number+1))
		
		if [ "${shadow_number}" -gt "${max_shadow_number}" ]; then
			shadow_number=${start_shadow_number}
		fi

	fi

done
