#!/bin/bash

if [ -z "${SUBJECT_FILES_DIR}" ]; then
	echo "Environment variable SUBJECT_FILES_DIR must be set!"
	exit 1
fi

project="${1}"

if [ -z "${project}" ]; then
	printf "project name: "
	read project
fi

subject_file_name="${SUBJECT_FILES_DIR}/${project}.PackageCompletion.subjects"
echo "Retrieving subject list from: ${subject_file_name}"
subject_list_from_file=( $( cat ${subject_file_name} ) )
subjects="`echo "${subject_list_from_file[@]}"`"

for subject in ${subjects} ; do
	if [[ ${subject} != \#* ]]; then
		./CheckForUpdateFixExtendedPackagesCompletion.sh \
			--archive-root="/HCP/hcpdb/archive/${project}/arc001" \
			--subject=${subject} \
			--output-dir="/HCP/hcpdb/packages/PostMsmAll/${project}"
	fi
done
