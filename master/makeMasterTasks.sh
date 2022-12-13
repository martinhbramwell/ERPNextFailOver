#!/usr/bin/env bash
#

export SCRIPT_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )";
export SCRIPT_NAME=$( basename ${0#-} );
export THIS_SCRIPT=$( basename ${BASH_SOURCE} )

function makeMasterTasks () {
  echo -e " - Making Master Tasks script :: ${MSTR_WRK_DIR}/${MSTR_JOB}."
  cat << EOFCT > ${MSTR_WRK_DIR}/${MSTR_JOB}
#!/usr/bin/env bash
#

export SCRIPT_DIR="\$( cd -- "\$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )";

function ensurePkgIsInstalled () {
  if dpkg-query -l \${PKG} >/dev/null; then
    echo -e " - Found \${PKG} already installed";
  else
    sudo -A apt install \${PKG};
    echo -e "\n - Installed \${PKG}"
  fi;
}

function ensure_SUDO_ASKPASS () {
  echo -e " - Testing 'SUDO_ASKPASS' capability. ( SUDO_ASKPASS = >\${SUDO_ASKPASS}< )";
  if [[ "${ALLOW_SUDO_ASKPASS_CREATION}" == "yes" ]]; then
    echo -e "    - Configuration allows ASKPASS creation.";
    if [ -z ${MASTER_HOST_PWD} ]; then
      echo -e "    - Configuration provides no password.";
      return 1;
    else
      echo -e "    - Found password in configuration file. Trying uploaded ASK_PASS emmitter.";
      export SUDO_ASKPASS=${MSTR_WRK_DIR}/.supwd.sh;
    fi;
  else
    echo -e "    - SUDO_ASKPASS creation denied in configuration";
    return 1;
  fi;
  # if [ -z \${SUDO_ASKPASS} ]; then
  #   echo -e "    - Master has no pre-existing 'SUDO_ASKPASS' environment variable.";
  #   if [[ "${ALLOW_SUDO_ASKPASS_CREATION}" == "yes" ]]; then
  #     echo -e "    - Configuration allows ASKPASS creation.";
  #     if [ -z ${MASTER_HOST_PWD} ]; then
  #       echo -e "    - Configuration provides no password.";
  #     else
  #       echo -e "    - Found password in configuration file.";
  #     fi;
  #   else
  #     echo -e "    - SUDO_ASKPASS creation denied in configuration";
  #     return 1;
  #   fi;
  #   if [ -f ${MSTR_WRK_DIR}/.supwd.sh ]; then
  #     echo -e "    - Found supplied 'ASKPASS' emitter script.";
  #   else
  #     echo -e "        Not found";
  #   fi;
  # else
  #   echo -e "    - Master has a 'SUDO_ASKPASS' environment variable.  ( \${SUDO_ASKPASS}  )";
  #   # declare TEST_RSLT=\$(sudo -A touch /etc/hostname);
  #   sudo -A touch /etc/hostname;
  #   if [ \$? -ne 0 ]; then
  #     # echo -e "SUDO_ASKPASS ==> \${SUDO_ASKPASS}";
  #     if [ ! -f \${SUDO_ASKPASS} ]; then
  #       echo -e "${pRED}\n\n* * *          There is no file: '\${SUDO_ASKPASS}'                    * * * ${pDFLT}";
  #     fi
  #     return 1;
  #   fi;
  # fi;

  # declare TEST_RSLT=\$(sudo -A touch /etc/hostname);
  sudo -A touch /etc/hostname;
  if [ \$? -ne 0 ]; then
    # echo -e "SUDO_ASKPASS ==> \${SUDO_ASKPASS}";
    if [ ! -f \${SUDO_ASKPASS} ]; then
      echo -e "${pRED}\n\n* * *          There is no file: '\${SUDO_ASKPASS}'                    * * * ${pDFLT}";
    fi
    return 1;
  fi;

}

function configureDBforReplication () {
  echo -e " - Configuring MariaDB Master for replication. (${MARIADB_CONFIG_DIR}/${MARIADB_CONFIG})";
  echo -e "   - Getting database name for site '${MASTER_HOST_URL}' from '${MASTER_BENCH_PATH}/sites/${MASTER_HOST_URL}/${SITE_CONFIG}'.";

  # jq -r . ${MASTER_BENCH_PATH}/sites/${MASTER_HOST_URL}/${SITE_CONFIG};

  declare MASTER_DATABASE_NAME=\$(jq -r .db_name ${MASTER_BENCH_PATH}/sites/${MASTER_HOST_URL}/${SITE_CONFIG});

  pushd ${MARIADB_CONFIG_DIR} >/dev/null;
    echo -e "   - Providing 'binlog-do-db' with its value ("\${MASTER_DATABASE_NAME}"), in patch file '${MSTR_WRK_DIR}/${MSTR_PATCH_NAME}'.";
    sed -i "s/.*REPLACE_WITH_DATABASE_NAME.*/+binlog-do-db=\${MASTER_DATABASE_NAME}/" ${MSTR_WRK_DIR}/${MSTR_PATCH_NAME};
    # cat "${MSTR_WRK_DIR}/${MSTR_PATCH_NAME}";

    echo -e "   - Patching '${MARIADB_CONFIG}' with '${MSTR_WRK_DIR}/${MSTR_PATCH_NAME}'.\n${pFAINT_BLUE}";

    sudo -A patch --forward ${MARIADB_CONFIG} ${MSTR_WRK_DIR}/${MSTR_PATCH_NAME};
    # sudo -A patch --forward --dry-run ${MARIADB_CONFIG} ${MSTR_WRK_DIR}/${MSTR_PATCH_NAME};
    echo -e "\n${pDFLT}       Patched\n";

    echo -e "${pYELLOW} - Restarting MariaDB  ${pDFLT}";
    sudo -A systemctl restart mariadb;
    # sudo -A systemctl status mariadb;

  popd >/dev/null;
}

function backupDatabase () {
  echo -e " - Taking backup of Master database ...";

  pushd ${MASTER_BENCH_PATH} >/dev/null;
    pushd ${BACKUP_RESTORE_DIR} >/dev/null;
      ./handleBackup.sh "Pre-replication baseline";
    popd >/dev/null;

    pushd ./BKP >/dev/null;
      BACKUP_NAME="\$(cat BACKUP.txt)";
      echo -e " - Backup name is : '\${BACKUP_NAME}'";
      rm -f ${MSTR_RSLT_DIR}/20*.tgz;
      cp BACKUP.txt ${MSTR_RSLT_DIR};
      cp \${BACKUP_NAME} ${MSTR_RSLT_DIR};
    popd >/dev/null;
    # pwd;
    # echo -e "Purging temporary files from Master.";
    # rm -fr /dev/shm/M_*;
    # echo -e "${pYELLOW}----------------- Master Tasks Curtailed --------------------------${pDFLT}";
    # exit;
  popd >/dev/null;
}

function installBackupAndRestoreTools () {
  echo -e " - Checking Frappe Bench directory location :: '${MASTER_BENCH_PATH}'";
  if [ -f ${MASTER_BENCH_PATH}/Procfile ]; then
    echo -e " - Moving Backup and Restore handlers from '${MSTR_WRK_DIR}/${BACKUP_RESTORE_DIR}' to Frappe Bench directory";
    pushd ${MSTR_WRK_DIR}/${BACKUP_RESTORE_DIR} >/dev/null;
      ln -fs Master_${ENVARS} ${ENVARS};
    popd >/dev/null;
    cp -r ${MSTR_WRK_DIR}/${BACKUP_RESTORE_DIR} ${MASTER_BENCH_PATH}
  else
    echo -e "\n${pRED}* * * Specified Frappe Bench directory location, '${MASTER_BENCH_PATH}', is NOT correct. Cannot continue .... * * * ${pDFLT}"
    exit 1;
  fi;
}

function stopERPNext () {
  echo -e "${pYELLOW} - Stopping ERPNext on Master ...  ${pFAINT_BLUE}\n";
  sudo -A supervisorctl stop all;
  echo -e "\n${pDFLT}     Stopped\n";
}

mkdir -p ${MSTR_RSLT_DIR};

export BACKUP_NAME="";

declare PKG="xmlstarlet";
ensurePkgIsInstalled;

declare PKG="jq";
ensurePkgIsInstalled;


ensure_SUDO_ASKPASS;

if [ \$? -eq 0 ]; then
  echo -e " - 'SUDO_ASKPASS' environment variable is correct.";
else
  echo -e "\n${pRED}* * * 'SUDO_ASKPASS' environment variable or emitter is NOT correct. Cannot continue .... * * * ${pDFLT}"
  exit 1;
fi;

installBackupAndRestoreTools;

stopERPNext;

configureDBforReplication;

backupDatabase;

    # # tree /dev/shm;
    # # echo -e "Purging temporary files from Master.";
    # # rm -fr /dev/shm/M_*;
    # echo -e "${pYELLOW}----------------- Master Tasks Curtailed --------------------------${pDFLT}";
    # # ls -la;
    # # hostname;
    # # pwd;
    # exit;

echo -e " - Enabling Slave user access and reading status of Master";
pushd ${MSTR_WRK_DIR} >/dev/null;
  # ls -la
  mysql -AX < ${MARIADB_SCRIPT} > ${MSTR_RSLT_DIR}/${MSTR_STATUS_RSLT};
popd >/dev/null;

export STATUS_FILE=\$(xmlstarlet sel -t -v "//resultset/row/field[@name='File']" ${MSTR_RSLT_DIR}/${MSTR_STATUS_RSLT});
echo -e "   - Log FILE :: \${STATUS_FILE}";

export STATUS_POS=\$(xmlstarlet sel -t -v "//resultset/row/field[@name='Position']" ${MSTR_RSLT_DIR}/${MSTR_STATUS_RSLT});
echo -e "   - Log file POSITION :: \${STATUS_POS}";

export STATUS_DB=\$(xmlstarlet sel -t -v "//resultset/row/field[@name='Binlog_Do_DB']" ${MSTR_RSLT_DIR}/${MSTR_STATUS_RSLT});
echo -e "   - Restrict to DATABASE :: \${STATUS_DB}";

echo -e "${pYELLOW} - Stopping MariaDB so that the backup can be restored on the Slave. ${pDFLT}";
sudo -A systemctl stop mariadb;
# sudo -A systemctl status mariadb;

echo -e " - Packaging results into :: '${TMP_DIR}/${MSTR_RSLT_PKG}'";
pushd ${TMP_DIR} >/dev/null;
  tar zcvf ${MSTR_RSLT_PKG} ${MSTR_RSLT} >/dev/null;
popd >/dev/null;

echo -e "Purging temporary files from Master.";
# ls -la /dev/shm/;
# rm -fr /dev/shm/M_w*;
# rm -fr /dev/shm/M_rslt;


echo -e "\nCompleted remote job : '${MSTR_WRK_DIR}/${MSTR_JOB}'.\n\n";
exit;
EOFCT
  chmod +x ${MSTR_WRK_DIR}/${MSTR_JOB};
}

if [[ ${SCRIPT_NAME} = ${THIS_SCRIPT} ]] ; then
  makeMasterTasks;
  echo -e "???"

  ls -la ${TMP_DIR}
else
  echo " - Sourced '${THIS_SCRIPT}' from '${SCRIPT_NAME}'"
fi;
