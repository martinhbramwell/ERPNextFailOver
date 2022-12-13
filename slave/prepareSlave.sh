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

function prepareSlave() {
  echo -e "Preparing slave ...";

  declare SLAVE_NAME=${SLAVE_HOST_URL//./_}

  if [[ "${SKIP_UPLOADS_TO_SLAVE}" == "yes" ]]; then
    echo -e "\n${pGOLD}Skipping uploads to slave. (SKIP_UPLOADS_TO_SLAVE =='${SKIP_UPLOADS_TO_SLAVE}').${pDFLT}\n"
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
        echo -e "\n${pGOLD}Skipping uploading Master backup file to slave! (UPLOAD_MASTER_BACKUP =='${UPLOAD_MASTER_BACKUP}').${pDFLT}\n"
      fi;
    popd >/dev/null;

    makeSlaveMariaDBScript;
    makeSlaveMariaDBconfPatch;

    pushd ${SLAV_WRK_DIR}/BaRe >/dev/null;
      echo "export MYPWD=\"${SLAVE_DB_ROOT_PWD}\";" >> Slave_envars.sh;
    popd >/dev/null;

    pushd ${TMP_DIR} >/dev/null
      echo -e " - Packaging Slave work files ('${SLAV_WRK_FILES}') from '${SLAV_WRK_DIR}' in '${TMP_DIR}' ...";

# echo -e "${pYELLOW}------------------------------ Curtailed ----------------------------------${pDFLT}";
# exit;

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

