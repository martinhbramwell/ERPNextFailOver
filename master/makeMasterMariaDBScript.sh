#!/usr/bin/env bash
#

export SCRIPT_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )";
export SCRIPT_NAME=$( basename ${0#-} );
export THIS_SCRIPT=$( basename ${BASH_SOURCE} )

function makeMasterMariaDBScript () {
  echo -e " - Making MariaDB script :: '${MSTR_WRK_DIR}/${MARIADB_SCRIPT}'.";

  declare SLAVE_IP=$(dig ${SLAVE_HOST_URL} A +short);
  declare SLAVE_USR=${SLAVE_HOST_URL//./_};

  cat << EOFMDB > ${MSTR_WRK_DIR}/${MARIADB_SCRIPT}
DROP USER IF EXISTS '${SLAVE_USR}'@'${SLAVE_IP}';

STOP SLAVE;

CREATE USER '${SLAVE_USR}'@'${SLAVE_IP}' IDENTIFIED BY '${SLAVE_DB_PWD}';
GRANT REPLICATION SLAVE ON *.* TO '${SLAVE_USR}'@'${SLAVE_IP}';

FLUSH PRIVILEGES;

SHOW MASTER STATUS;

EOFMDB
}

if [[ ${SCRIPT_NAME} = ${THIS_SCRIPT} ]] ; then
  makeMasterMariaDBScript;

  ls -la ${TMP_DIR}
else
  echo " - Sourced '${THIS_SCRIPT}' from '${SCRIPT_NAME}'"
fi;
