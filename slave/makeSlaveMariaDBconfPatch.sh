#!/usr/bin/env bash
#

export SCRIPT_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )";
export SCRIPT_NAME=$( basename ${0#-} );
export THIS_SCRIPT=$( basename ${BASH_SOURCE} )

function makeSlaveMariaDBconfPatch () {
  echo -e " - Making MariaDB config patch :: '${SLAV_WRK_DIR}/${SLAV_PATCH_NAME}'.
  ";

  cat << EOFMCP > ${SLAV_WRK_DIR}/${SLAV_PATCH_NAME}
--- /dev/shm/50-server.cnf      2022-10-27 10:33:19.504245491 -0400
+++ /dev/shm/50-server_new.cnf  2022-11-03 16:20:47.086226155 -0400
@@ -44,6 +44,10 @@
 # * Logging and Replication
 #
 
+log-basename=${SLAVE_NAME}
+log-bin
+server_id=2
+
 # Both location gets rotated by the cronjob.
 # Be aware that this log type is a performance killer.
 # Recommend only changing this at runtime for short testing periods if needed!

EOFMCP
# cat ${SLAV_WRK_DIR}/${SLAV_PATCH_NAME};
}


if [[ ${SCRIPT_NAME} = ${THIS_SCRIPT} ]] ; then
  makeSlaveMariaDBconfPatch;

  ls -la ${TMP_DIR}
else
  echo " - Sourced '${THIS_SCRIPT}' from '${SCRIPT_NAME}'"
fi;
