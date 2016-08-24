#!/bin/bash

if [ -z "${SUBJECT_FILES_DIR}" ] ; then
    echo "Environment variable SUBJECT_FILES_DIR must be set!"
    exit 1
fi

project="WU_L1B_Staging"
subject_file_name="${SUBJECT_FILES_DIR}/${project}.functional.subjects"
echo "Retrieving subject list from: ${subject_file_name}"
subject_list_from_file=( $( cat ${subject_file_name} ) )
subjects="`echo "${subject_list_from_file[@]}"`"

mkdir -p ${project}

for subject in $subjects ; do
    echo "Checking subject: ${subject}"
    ../CheckFunctionalPreprocessing.sh \
        --project=${project} \
        --subjects=${subject} \
        --tasks="REST1,REST2,REST3,REST4,REST5,REST6,WM,GAMBLING,SOCIAL,EMOTION" | tee ${project}/${subject}.out | grep FAIL
done
