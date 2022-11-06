#!/usr/bin/env bash
#

export SCRIPT_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )";
export SCRIPT_NAME=$( basename ${0#-} );
export THIS_SCRIPT=$( basename ${BASH_SOURCE} )

function makeMasterTasks () {
  echo -e " - Making Master Tasks script :: ${MSTR_WRK_DIR}/${MSTR_JOB}"
  cat << EOFCT > ${MSTR_WRK_DIR}/${MSTR_JOB}
#!/usr/bin/env bash
#

function ensure_XMLStarlet () {
  declare PKG="xmlstarlet";
  if dpkg-query -l \${PKG} >/dev/null; then
    echo -e " - Found \${PKG} already installed";
  else
    sudo -A apt install \${PKG};
    echo -e "\n - Installed \${PKG}"
  fi;
}

function ensure_SUDO_ASKPASS () {
  if [ -z \${SUDO_ASKPASS} ]; then
    echo -e " - Master has no 'SUDO_ASKPASS' environment variable.";
    if [ -f ${MSTR_WRK_DIR}/.supwdsh ]; then
      echo -e "Found";
    else
      echo -e "Not found";
      if [[ "${ALLOW_SUDO_ASKPASS_CREATION}" == "yes" ]]; then
        echo -e "Allowed";
        if [ -z ${MASTER_HOST_PWD} ]; then
          echo -e "No password";
        else
          echo -e "Found password";
        fi;
      else
        echo -e "Denied";
      fi;
    fi;
  else
    echo -e " - Master has a 'SUDO_ASKPASS' environment variable.";
    # declare TEST_RSLT=\$(sudo -A touch /etc/hostname);
    sudo -A touch /etc/hostname;
    if [ \$? -ne 0 ]; then
      # echo -e "SUDO_ASKPASS ==> \${SUDO_ASKPASS}";
      if [ ! -f \${SUDO_ASKPASS} ]; then
        echo -e "${pRED}\n\n* * *          There is no file: '\${SUDO_ASKPASS}'                    * * * ${pDFLT}";
      fi
      return 1;
    fi;
  fi;
}


export BACKUP_NAME="";
export SUDO_ASKPASS=${MSTR_WRK_DIR}/.supwd.sh;

ensure_XMLStarlet;
ensure_SUDO_ASKPASS;
if [ \$? -eq 0 ]; then
  echo -e " - 'SUDO_ASKPASS' environment variable is correct";
else
  echo -e "\n${pRED}* * * 'SUDO_ASKPASS' environment variable is NOT correct. Cannot continue .... * * * ${pDFLT}"
  exit 1;
fi;

  echo -e "${pYELLOW}----------------- Master Tasks Curtailed --------------------------${pDFLT}";
  exit;

mkdir -p ${MSTR_RSLT_DIR};

echo -e "${pYELLOW} - Stopping ERPNext on Master ...  ${pDFLT}";
sudo -A supervisorctl stop all;

echo -e " - Configuring MariaDB Master for replication";
pushd ${MARIADB_CONFIG_DIR} >/dev/null;

  echo -e " - Patching '${MARIADB_CONFIG}' with '${MSTR_WRK_DIR}/${MSTR_PATCH_NAME}'";
  sudo -A patch ${MARIADB_CONFIG} ${MSTR_WRK_DIR}/${MSTR_PATCH_NAME} >/dev/null;
  # sudo -A patch --dry-run ${MARIADB_CONFIG} ${MSTR_WRK_DIR}/${MSTR_PATCH_NAME};

  echo -e "${pYELLOW} - Restarting MariaDB  ${pDFLT}";
  sudo -A systemctl restart mariadb;
  # sudo -A systemctl status mariadb;

popd >/dev/null;

echo -e " - Taking backup of Master database: '${ERPNEXT_SITE_DB}'";
pushd \${HOME}/${MASTER_BENCH_NAME} >/dev/null;
  pushd ./apps/ce_sri/development/initialization >/dev/null;
    # # ls -la;
    ./QikBackup.sh "Pre-replication baseline";
  popd >/dev/null;
  pushd ./BKP >/dev/null;
    BACKUP_NAME="\$(cat BACKUP.txt)";
    echo -e " - Backup name is : '\${BACKUP_NAME}'";
    rm -f ${MSTR_RSLT_DIR}/20*.tgz;
    cp BACKUP.txt ${MSTR_RSLT_DIR};
    cp \${BACKUP_NAME} ${MSTR_RSLT_DIR};
  popd >/dev/null;
popd >/dev/null;

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
