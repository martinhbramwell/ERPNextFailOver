#!/usr/bin/env bash
#

export SCRIPT_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )";
export SCRIPT_NAME=$( basename ${0#-} );
export THIS_SCRIPT=$( basename ${BASH_SOURCE} )

function makeEnvarsFile () {
  echo -e "    - Making environment variables file for backup and restore functions";

  mkdir -p ${DIR}/${BACKUP_RESTORE_DIR};

  cat << EOFMRS > ${DIR}/${BACKUP_RESTORE_DIR}/${ROL}_${ENVARS}
export TARGET_BENCH=${FBP};        # Full path to Bench directory
export ERPNEXT_SITE_URL=${HST};    # URL of site to back up
export RESTORE_SITE_CONFIG="yes";   # URL of site to back up
export KEEP_SITE_PASSWORD="yes";   # URL of site to back up
EOFMRS
}

if [[ ${SCRIPT_NAME} = ${THIS_SCRIPT} ]] ; then
  makeEnvarsFile;

  ls -la ${DIR}
else
  echo " - Sourced '${THIS_SCRIPT}' from '${SCRIPT_NAME}'"
fi;
