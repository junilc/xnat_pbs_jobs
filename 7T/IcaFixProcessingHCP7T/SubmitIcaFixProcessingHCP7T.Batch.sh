#!/bin/bash

SCRIPT_NAME=`basename ${0}`

inform()
{
	local msg=${1}
	echo "${SCRIPT_NAME}: ${msg}"
}

if [ -z "${SUBJECT_FILES_DIR}" ]; then
	inform "Environment variable SUBJECT_FILES_DIR must be set!"
	exit 1
fi

printf "Connectome DB Username: "
read userid

stty -echo
printf "Connectome DB Password: "
read password
echo ""
stty echo

subject_file_name="${SUBJECT_FILES_DIR}/IcaFixProcessingHCP7T.subjects"
inform "Retrieving subject list from: ${subject_file_name}"
subject_list_from_file=( $( cat ${subject_file_name} ) )
subjects="`echo "${subject_list_from_file[@]}"`"

start_shadow_number=1
max_shadow_number=8

shadow_number=${start_shadow_number}

for subject_spec in ${subjects} ; do

	if [[ ${subject_spec} != \#* ]]; then

		parsing_subject_spec="${subject_spec}"

		project=${parsing_subject_spec%%:*}
		parsing_subject_spec=${parsing_subject_spec#*:}
		
		refproject=${parsing_subject_spec%%:*}
		parsing_subject_spec=${parsing_subject_spec#*:}

		subject=${parsing_subject_spec%%:*}
		parsing_subject_spec=${parsing_subject_spec#*:}
		
		scan=${parsing_subject_spec%%:*} # REST1_PA, REST2_AP, MOVIE1_AP, MOVIE2_PA, etc
		parsing_subject_spec=${parsing_subject_spec#*:}
		
		comments=${parsing_subject_spec}

		server="db-shadow${shadow_number}.nrg.mir:8080"

		inform ""
		inform "--------------------------------------------------------------------------------"
		inform " Submitting IcaFixProcessingHCP7T jobs for:"
		inform "      project: ${project}"
		inform "   refproject: ${refproject}"
		inform "      subject: ${subject}"
		inform "         scan: ${scan}"
		inform "       server: ${server}"
		inform "--------------------------------------------------------------------------------"		

		if [ "${scan}" = "all" ] ; then

			${HOME}/pipeline_tools/xnat_pbs_jobs/7T/IcaFixProcessingHCP7T/SubmitIcaFixProcessingHCP7T.OneSubject.sh \
				--user=${userid} \
				--password=${password} \
				--put-server=${server} \
				--project=${project} \
				--subject=${subject} \
				--structural-reference-project=${refproject} \
				--structural-reference-session=${subject}_3T \
				--setup-script=${SCRIPTS_HOME}/SetUpHCPPipeline_IcaFixProcessingHCP7T.sh
				#--scan=${scan} \
				#--do-not-clean-first
			
		else

			${HOME}/pipeline_tools/xnat_pbs_jobs/7T/IcaFixProcessingHCP7T/SubmitIcaFixProcessingHCP7T.OneSubject.sh \
				--user=${userid} \
				--password=${password} \
				--put-server=${server} \
				--project=${project} \
				--subject=${subject} \
				--structural-reference-project=${refproject} \
				--structural-reference-session=${subject}_3T \
				--setup-script=${SCRIPTS_HOME}/SetUpHCPPipeline_IcaFixProcessingHCP7T.sh \
				--scan=${scan} \
				#--do-not-clean-first \

		fi

		shadow_number=$((shadow_number+1))
		
		if [ "${shadow_number}" -gt "${max_shadow_number}" ]; then
			shadow_number=${start_shadow_number}
		fi
		
	fi

done
