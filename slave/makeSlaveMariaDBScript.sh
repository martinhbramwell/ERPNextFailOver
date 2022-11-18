#!/usr/bin/env bash
#

export SCRIPT_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )";
export SCRIPT_NAME=$( basename ${0#-} );
export THIS_SCRIPT=$( basename ${BASH_SOURCE} )

function makeSlaveMariaDBScript () {
  echo -e " - Making MariaDB script :: ${SLAV_WRK_DIR}/${MARIADB_SCRIPT}"

  cat << EOFMDB > ${SLAV_WRK_DIR}/${MARIADB_SCRIPT}
STOP SLAVE;
CHANGE MASTER TO MASTER_HOST='${MASTER_HOST_URL}', MASTER_USER='${SLAVE_NAME}', MASTER_PASSWORD='${SLAVE_DB_PWD}', MASTER_LOG_FILE='${STATUS_FILE}', MASTER_LOG_POS=${STATUS_POS};
START SLAVE;
SHOW SLAVE STATUS\G;
EOFMDB
}

if [[ ${SCRIPT_NAME} = ${THIS_SCRIPT} ]] ; then
  makeSlaveMariaDBScript;

  ls -la ${TMP_DIR}
else
  echo " - Sourced '${THIS_SCRIPT}' from '${SCRIPT_NAME}'"
fi;
