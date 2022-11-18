#!/usr/bin/env bash
#

export SCRIPT_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )";
export SCRIPT_NAME=$( basename ${0#-} );
export THIS_SCRIPT=$( basename ${BASH_SOURCE} )


declare MAKE_SLAV_JOB="./slave/makeSlaveTasks.sh";
source ${MAKE_SLAV_JOB};

declare MAKE_SLAV_PATCH="./slave/makeSlaveMariaDBconfPatch.sh";
source ${MAKE_SLAV_PATCH};

declare MAKE_SLAV_MARIA_SQL="./slave/makeSlaveMariaDBScript.sh";
source ${MAKE_SLAV_MARIA_SQL};

declare SLAV_PATCH_NAME="50-server.cnf.patch";
declare SLAV_JOB="slaveTasks.sh";
declare MARIADB_SCRIPT="setUpSlave.sql";

# function makeSlaveMariaDBconfPatch () {

#   declare HOST=$(host ${MASTER_HOST_URL})
#   declare MASTER_IP_ADDR=${HOST#${MASTER_HOST_URL} has address }
#   declare HOST_ALIAS=${MASTER_HOST_URL//./_}

#   echo -e " - Making MariaDB config patch :: ${SLAV_WRK_DIR}/${SLAV_PATCH_NAME}
#   ";

#   cat << EOFMCP > ${SLAV_WRK_DIR}/${SLAV_PATCH_NAME}
# --- /dev/shm/50-server.cnf      2022-10-27 10:33:19.504245491 -0400
# +++ /dev/shm/50-server_new.cnf  2022-11-03 16:20:47.086226155 -0400
# @@ -44,6 +44,10 @@
#  # * Logging and Replication
#  #
 
# +log-basename=${SLAVE_NAME}
# +log-bin
# +server_id=2
# +
#  # Both location gets rotated by the cronjob.
#  # Be aware that this log type is a performance killer.
#  # Recommend only changing this at runtime for short testing periods if needed!

# EOFMCP
# cat ${SLAV_WRK_DIR}/${SLAV_PATCH_NAME};
# }

# function makeSlaveMariaDBScript () {
#   echo -e " - Making MariaDB script :: ${SLAV_WRK_DIR}/${MARIADB_SCRIPT}"

#   cat << EOFMDB > ${SLAV_WRK_DIR}/${MARIADB_SCRIPT}
# STOP SLAVE;
# CHANGE MASTER TO MASTER_HOST='${MASTER_HOST_URL}', MASTER_USER='${SLAVE_NAME}', MASTER_PASSWORD='${SLAVE_DB_PWD}', MASTER_LOG_FILE='${STATUS_FILE}', MASTER_LOG_POS=${STATUS_POS};
# START SLAVE;
# SHOW SLAVE STATUS\G;
# EOFMDB

# # cat ${SLAV_WRK_DIR}/${MARIADB_SCRIPT};
# }

# function makeSlaveTasks () {
#   echo -e " - Making Slave Tasks script :: ${SLAV_WRK_DIR}/${SLAV_JOB}"
#   cat << EOFCT > ${SLAV_WRK_DIR}/${SLAV_JOB}
# #!/usr/bin/env bash
# #
# export SUDO_ASKPASS=${SLAV_WRK_DIR}/.supwd.sh;

# declare PKG="xmlstarlet";
# if dpkg-query -l \${PKG} >/dev/null; then
#   echo -e " - Found \${PKG} already installed";
# else
#   sudo -A apt install \${PKG};
#   echo -e "\n - Installed \${PKG}"
# fi;

# declare DIR_BKP="/home/${SLAVE_HOST_USR}/${TARGET_BENCH_NAME}/BKP";

# mkdir -p ${SLAV_RSLT_DIR};

# echo -e "${pYELLOW} - Stopping ERPNext on Slave ...  ${pDFLT}";
# sudo -A supervisorctl stop all;

# echo -e " - Moving backup files from '${SLAV_WRK_DIR}' to backup directory '\${DIR_BKP}'";
# # echo -e "${pYELLOW}----------------- makeSlaveTasks Curtailed -------------------${pDFLT}";
# # exit;

# pushd ${SLAV_WRK_DIR} >/dev/null;
#   BACKUP_NAME="\$(cat BACKUP.txt)";
#   cp BACKUP.txt \${DIR_BKP} >/dev/null;
#   cp \${BACKUP_NAME} \${DIR_BKP} >/dev/null;
# popd >/dev/null;

# echo -e " - Restoring backup ...\n\n";
# pushd /home/${SLAVE_HOST_USR}/${TARGET_BENCH_NAME}/${CE_SRI_UTILS} >/dev/null;
#   sudo -A systemctl restart mariadb;
#   ./qikRestore.sh;
#   echo -e "${pYELLOW} - Stopping MariaDB to remain sync'd to stopped Master. ${pDFLT}";
#   sudo -A systemctl stop mariadb;
# popd >/dev/null;
# echo -e "\n";

# echo -e " - Configuring MariaDB Slave for replication";
# pushd ${MARIADB_CONFIG_DIR} >/dev/null;

#   echo -e " - Patching '${MARIADB_CONFIG}' with '${SLAV_WRK_DIR}/${MSTR_PATCH_NAME}'";
#   sudo -A patch ${MARIADB_CONFIG} ${SLAV_WRK_DIR}/${SLAV_PATCH_NAME} >/dev/null;
#   # sudo -A patch --dry-run ${MARIADB_CONFIG} ${SLAV_WRK_DIR}/${SLAV_PATCH_NAME};

#   echo -e "${pYELLOW} - Restarting MariaDB  ${pDFLT}";
#   sudo -A systemctl restart mariadb;
#   # sudo -A systemctl status mariadb;

# popd >/dev/null;

# echo -e " - Enabling Slave connection to Master";
# pushd ${SLAV_WRK_DIR} >/dev/null;
#   # ls -la
#   mysql -AX < ${MARIADB_SCRIPT} > ${SLAV_RSLT_DIR}/${SLAV_STATUS_RSLT};
# popd >/dev/null;



# EOFCT
#   chmod +x ${SLAV_WRK_DIR}/${SLAV_JOB};
# }

function prepareSlave() {
  echo -e "Preparing slave...";

  declare SLAVE_NAME=${SLAVE_HOST_URL//./_}

  if [[ "${REPEAT_SLAVE_WITHOUT_MASTER}" == "yes" ]]; then
    echo -e "\n${pGOLD}Skipping uploads to slave. (REPEAT_SLAVE_WITHOUT_MASTER =='${REPEAT_SLAVE_WITHOUT_MASTER}').${pDFLT}\n"
  else
    echo -e " - Extracting Master status values";
    declare STATUS_FILE=$(xmlstarlet sel -t -v "//resultset/row/field[@name='File']" ${MSTR_RSLT_DIR}/${MSTR_STATUS_RSLT});
    echo -e "   - Log FILE :: ${STATUS_FILE}";

    declare STATUS_POS=$(xmlstarlet sel -t -v "//resultset/row/field[@name='Position']" ${MSTR_RSLT_DIR}/${MSTR_STATUS_RSLT});
    echo -e "   - Log file POSITION :: ${STATUS_POS}";

    # declare STATUS_DB=$(xmlstarlet sel -t -v "//resultset/row/field[@name='Binlog_Do_DB']" ${MSTR_RSLT_DIR}/${MSTR_STATUS_RSLT});
    # echo -e "   - Restrict to DATABASE :: ${STATUS_DB}";


    echo -e " - Moving backup and restore handlers '${BACKUP_HANDLER}' to transfer directory '${TMP_DIR}/${MSTR_WRK}'";
    cp -r ${BACKUP_RESTORE_PATH} ${TMP_DIR}/${SLAV_WRK};

    makeSlaveTasks;

    pushd ${MSTR_RSLT_DIR} >/dev/null;
      declare MASTER_BACKUP=$(cat BACKUP.txt)
      echo -e " - Copy backup of Master ('${MASTER_BACKUP}') to Slave work directory.";
      if [[ "${UPLOAD_MASTER_BACKUP}" == "yes" ]]; then
        cp BACKUP.txt ${SLAV_WRK_DIR} &>/dev/null;
        cp ${MASTER_BACKUP} ${SLAV_WRK_DIR} &>/dev/null;
      else
        echo -e "\n${pGOLD}Skipping uploads to slave. (REPEAT_SLAVE_WITHOUT_MASTER =='${REPEAT_SLAVE_WITHOUT_MASTER}').${pDFLT}\n"
      fi;
    popd >/dev/null;

    makeSlaveMariaDBScript;
    makeSlaveMariaDBconfPatch;

    # echo -e "${pYELLOW}------------------------------ Curtailed ----------------------------------${pDFLT}
    # ${SLAVE_DB_PWD}";
    # exit;

    pushd ${TMP_DIR} >/dev/null
      echo -e " - Packaging Slave work files ('${SLAV_WRK_FILES}') from '${SLAV_WRK_DIR}' in '${TMP_DIR}' ...";
      tar zcvf ${SLAV_WRK_FILES} ${SLAV_WRK} >/dev/null;
    popd >/dev/null


    echo -e " - Purging existing Slave work files from '${THE_SLAVE}:${TMP_DIR}'"
    ssh ${THE_SLAVE} "rm -fr /dev/shm/S_rslt; rm -fr /dev/shm/S_work*; rm -fr /dev/shm/BKP;" >/dev/null;

    echo -e " - Uploading Slave work files '${SLAV_WRK_FILES}' to '${THE_SLAVE}:${TMP_DIR}'"
    scp ${TMP_DIR}/${SLAV_WRK_FILES} ${THE_SLAVE}:${TMP_DIR} >/dev/null;
  fi;

  echo -e " - Extracting content from uploaded file '${SLAV_WRK_FILES}' on Slave ..."
  ssh ${THE_SLAVE} tar zxvf ${TMP_DIR}/${SLAV_WRK_FILES} -C /dev/shm >/dev/null;

  echo -e " - Executing script '${SLAV_JOB}' on Slave"
  ssh ${THE_SLAVE} ${SLAV_WRK_DIR}/${SLAV_JOB};
  echo -e " - Finished with Slave.\n"

  # echo -e "Downloading Master status file '${MASTER_STATUS_RSLT}' to '${TMP_DIR}'"
  # scp ${THE_MASTER}:${SLAV_WRK_DIR}/${MASTER_STATUS_RSLT} ${TMP_DIR} >/dev/null;
  # # cat ${TMP_DIR}/${MASTER_STATUS_RSLT};
}

if [[ ${SCRIPT_NAME} = ${THIS_SCRIPT} ]] ; then
  prepareSlave;

  ls -la ${TMP_DIR}
else
  echo " - Sourced '${THIS_SCRIPT}' from '${SCRIPT_NAME}'"
fi;

