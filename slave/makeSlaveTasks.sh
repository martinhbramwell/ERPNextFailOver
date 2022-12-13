#!/usr/bin/env bash
#

export SCRIPT_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )";
export SCRIPT_NAME=$( basename ${0#-} );
export THIS_SCRIPT=$( basename ${BASH_SOURCE} )

function makeSlaveTasks () {
  echo -e " - Making Slave Tasks script :: ${SLAV_WRK_DIR}/${SLAV_JOB}"
  cat << EOFCTS > ${SLAV_WRK_DIR}/${SLAV_JOB}
#!/usr/bin/env bash
#
export SUDO_ASKPASS=${SLAV_WRK_DIR}/.supwd.sh;

function ensurePkgIsInstalled () {
  if dpkg-query -l \${PKG} >/dev/null; then
    echo -e " - Found \${PKG} already installed";
  else
    sudo -A apt install \${PKG};
    echo -e "\n - Installed \${PKG}"
  fi;
}

function stopERPNext () {
  echo -e "${pYELLOW}   - Stopping ERPNext on Slave ...  \n${pFAINT_BLUE}";
  sudo -A supervisorctl stop all;
  echo -e "\n      Stopped${pDFLT}\n";
}

function relocateBackupFiles () {
  echo -e "   - Move backup files from '${SLAV_WRK_DIR}' to backup directory '\${DIR_BKP}'";
  pushd ${SLAV_WRK_DIR} >/dev/null;
    BACKUP_NAME="\$(cat BACKUP.txt)";
    echo -e "     Moving ...";
    echo -e "       - 'BACKUP.txt'";
    echo -e "       - '\${BACKUP_NAME}'";
    cp BACKUP.txt \${DIR_BKP} >/dev/null;
    cp \${BACKUP_NAME} \${DIR_BKP} >/dev/null;
  popd >/dev/null;
}

function restoreDatabase () {
  echo -e "\n - Ensuring MariaDB is running";
  sudo -A systemctl restart mariadb;

  # echo -e " - Restoring backup ...\n\n";
  pushd ${SLAVE_BENCH_PATH} >/dev/null;
    pushd ${BACKUP_RESTORE_DIR} >/dev/null;
      ./handleRestore.sh;
      # echo -e "${pYELLOW}----------------- Slave Tasks Curtailed --------------------------${pDFLT}";
      # exit;
    popd >/dev/null;

  popd >/dev/null;
}

function configureDBforReplication () {
  echo -e " - Configuring MariaDB Slave for replication";
  pushd ${MARIADB_CONFIG_DIR} >/dev/null;

    echo -e " - Patching '${MARIADB_CONFIG}' with '${SLAV_WRK_DIR}/${MSTR_PATCH_NAME}'";
    sudo -A patch ${MARIADB_CONFIG} ${SLAV_WRK_DIR}/${SLAV_PATCH_NAME} >/dev/null;
    # sudo -A patch --dry-run ${MARIADB_CONFIG} ${SLAV_WRK_DIR}/${SLAV_PATCH_NAME};

    echo -e "${pYELLOW} - Restarting MariaDB  ${pDFLT}";
    sudo -A systemctl restart mariadb;
    # sudo -A systemctl status mariadb;

  popd >/dev/null;
}

function installBackupAndRestoreTools () {
  echo -e " - Checking Frappe Bench directory location :: '${SLAVE_BENCH_PATH}'";
  if [ -f ${SLAVE_BENCH_PATH}/Procfile ]; then
    echo -e " - Moving Backup and Restore handlers from '${SLAV_WRK_DIR}/${BACKUP_RESTORE_DIR}' to Frappe Bench directory";
    pushd ${SLAV_WRK_DIR}/${BACKUP_RESTORE_DIR} >/dev/null;
      ln -fs Slave_${ENVARS} ${ENVARS};
    popd >/dev/null;
    cp -r ${SLAV_WRK_DIR}/${BACKUP_RESTORE_DIR} ${SLAVE_BENCH_PATH}
  else
    echo -e "\n${pRED}* * * Specified Frappe Bench directory location, '${SLAVE_BENCH_PATH}', is NOT correct. Cannot continue .... * * * ${pDFLT}"
    exit 1;
  fi;
}



declare DIR_BKP="${SLAVE_BENCH_PATH}/BKP";

mkdir -p ${SLAV_RSLT_DIR};

      # echo -e "${pYELLOW}----------------- Slave Tasks Curtailed Before Restore Database  --------------------------${pDFLT}
      # ${SLAV_RSLT_DIR}";
      # exit;


declare PKG="xmlstarlet";
ensurePkgIsInstalled;

declare PKG="jq";
ensurePkgIsInstalled;


installBackupAndRestoreTools;

stopERPNext;

relocateBackupFiles;

restoreDatabase;

configureDBforReplication;

echo -e " - Enabling Slave connection to Master";
pushd ${SLAV_WRK_DIR} >/dev/null;
  # ls -la
  mysql -AX < ${MARIADB_SCRIPT} > ${SLAV_RSLT_DIR}/${SLAV_STATUS_RSLT};
popd >/dev/null;

echo -e " - Purging temporary files from Slave. ${pRED}*** SKIPPED ***${pDFLT}";
# rm -fr /dev/shm/S_*;


echo -e "\nCompleted remote job : '${SLAV_WRK_DIR}/${SLAV_JOB}'.\n\n";
exit;

EOFCTS

  chmod +x ${SLAV_WRK_DIR}/${SLAV_JOB};
}

if [[ ${SCRIPT_NAME} = ${THIS_SCRIPT} ]] ; then
  makeSlaveTasks;
  echo -e "???"

  ls -la ${TMP_DIR}
else
  echo " - Sourced '${THIS_SCRIPT}' from '${SCRIPT_NAME}'"
fi;
