#!/usr/bin/env bash
#

export SCRIPT_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )";

declare MAKE_MSTR_JOB="./master/makeMasterTasks.sh";
source ${MAKE_MSTR_JOB};

declare MAKE_MSTR_PATCH="./master/makeMasterMariaDBconfPatch.sh";
source ${MAKE_MSTR_PATCH};

declare MAKE_MSTR_MARIA_SQL="./master/makeMasterMariaDBScript.sh";
source ${MAKE_MSTR_MARIA_SQL};

declare MSTR_PATCH_NAME="master_${MARIADB_CONFIG}.patch";
declare MSTR_JOB="masterTasks.sh";
declare MARIADB_SCRIPT="setUpMaster.sql";

function prepareMaster() {
  echo -e "\n\nPreparing master ...";

  echo -e "Moving backup and restore handlers '${BACKUP_HANDLER}' to transfer directory '${TMP_DIR}/${MSTR_WRK}'";
  cp -r ${BACKUP_RESTORE_PATH} ${TMP_DIR}/${MSTR_WRK};

  makeMasterTasks;
  makeMasterMariaDBScript;
  makeMasterMariaDBconfPatch;

  pushd ${TMP_DIR} >/dev/null
    tar zcvf ${MSTR_WRK_FILES} ${MSTR_WRK} >/dev/null;
  popd >/dev/null

  echo -e "Uploading Master tasks files '${MSTR_WRK_FILES}' to '${THE_MASTER}:${TMP_DIR}'."
  scp ${TMP_DIR}/${MSTR_WRK_FILES} ${THE_MASTER}:${TMP_DIR} >/dev/null;

  echo -e "Extracting content from uploaded file '${MSTR_WRK_FILES}' on Master."
  ssh ${THE_MASTER} tar zxvf ${TMP_DIR}/${MSTR_WRK_FILES} -C /dev/shm >/dev/null;

  # # ls -la;
  # echo -e "${pYELLOW}------------- prepareMaster Curtailed ---------------------${pDFLT}";
  # exit;

  echo -e "Executing script '${MSTR_JOB}' on Master."
  ssh -t ${THE_MASTER} ${MSTR_WRK_DIR}/${MSTR_JOB};

}

export SCRIPT_NAME=$( basename ${0#-} );
export THIS_SCRIPT=$( basename ${BASH_SOURCE} )

if [[ ${SCRIPT_NAME} = ${THIS_SCRIPT} ]] ; then

  prepareMaster;

  ls -la ${TMP_DIR}
else
  echo " - Sourced '${THIS_SCRIPT}' from '${SCRIPT_NAME}'"
fi 
