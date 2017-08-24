#!/bin/bash

if [ -z "${XNAT_PBS_JOBS}" ]; then
	script_name=$(basename "${0}")
	echo "${script_name}: ABORTING: XNAT_PBS_JOBS environment variable must be set"
	exit 1
fi

source activate python3 2>/dev/null
${XNAT_PBS_JOBS}/7T/IcaFixProcessingHCP7T/SubmitIcaFixProcessingHCP7TBatch.py
source deactivate 2>/dev/null
	