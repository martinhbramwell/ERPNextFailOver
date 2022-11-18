#!/usr/bin/env bash
#

export SCRIPT_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )";
export SCRIPT_NAME=$( basename ${0#-} );
export THIS_SCRIPT=$( basename ${BASH_SOURCE} )

function makeMasterMariaDBconfPatch () {

  declare HOST_ALIAS=${MASTER_HOST_URL//./_}

  echo -e " - Making MariaDB config patch :: '${MSTR_WRK_DIR}/${MSTR_PATCH_NAME}'.
  ";

  cat << EOFMCP > ${MSTR_WRK_DIR}/${MSTR_PATCH_NAME}
--- 50-server.cnf       2022-10-28 21:58:04.584379268 +0200
+++ 50-server_new.cnf   2022-10-28 21:57:05.182855389 +0200
@@ -24,7 +24,7 @@
 
 # Instead of skip-networking the default is now to listen only on
 # localhost which is more compatible and is not less secure.
-bind-address            = 127.0.0.1
+bind-address            = 0.0.0.0
 
 #
 # * Fine Tuning
@@ -43,6 +43,11 @@
 #
 # * Logging and Replication
 #
+log-basename=${HOST_ALIAS};
+log-bin=/var/log/mysql/mariadb-bin.log
+server_id=1
+binlog-do-db=REPLACE_WITH_DATABASE_NAME
+gtid-domain-id=1
 
 # Both location gets rotated by the cronjob.
 # Be aware that this log type is a performance killer.
EOFMCP
}

if [[ ${SCRIPT_NAME} = ${THIS_SCRIPT} ]] ; then
  makeMasterMariaDBconfPatch;

  ls -la ${TMP_DIR}
else
  echo " - Sourced '${THIS_SCRIPT}' from '${SCRIPT_NAME}'"
fi;
