#!/usr/bin/env bash
#

export SCRIPT_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )";
export SCRIPT_NAME=$( basename ${0#-} );
export THIS_SCRIPT=$( basename ${BASH_SOURCE} )

function makeMasterMariaDBScript () {
  echo -e " - Making MariaDB script :: '${MSTR_WRK_DIR}/${MARIADB_SCRIPT}'."

  cat << EOFMDB > ${MSTR_WRK_DIR}/${MARIADB_SCRIPT}
DROP USER IF EXISTS 'loso_erpnext_host'@'185.34.136.36';

STOP SLAVE;
CREATE USER 'loso_erpnext_host'@'185.34.136.36' IDENTIFIED BY '${SLAVE_DB_PWD}';
GRANT REPLICATION SLAVE ON *.* TO 'loso_erpnext_host'@'185.34.136.36';

FLUSH PRIVILEGES;

SHOW MASTER STATUS;

-- select host, db, user from mysql.db;
-- select host, user, repl_slave_priv, delete_priv from mysql.user;
EOFMDB
}

if [[ ${SCRIPT_NAME} = ${THIS_SCRIPT} ]] ; then
  makeMasterMariaDBScript;

  ls -la ${TMP_DIR}
else
  echo " - Sourced '${THIS_SCRIPT}' from '${SCRIPT_NAME}'"
fi;
