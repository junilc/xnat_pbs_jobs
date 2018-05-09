#!/bin/bash

if [ -z "${XNAT_PBS_JOBS}" ]; then
	script_name=$(basename "${0}")
	echo "${script_name}: ABORTING: XNAT_PBS_JOBS environment variable must be set"
	exit 1
fi

source ${XNAT_PBS_JOBS}/shlib/utils.shlib
set_g_python_environment
source activate ${g_python_environment} 2>/dev/null
${XNAT_PBS_JOBS}/lib/utils/get_json_meta_data.py $@
source deactivate 2>/dev/null
