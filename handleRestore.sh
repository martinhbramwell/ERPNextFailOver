#!/usr/bin/env bash
#

export SCRIPT_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )";
export SCRIPT_NAME=$( basename ${0#-} );
export THIS_SCRIPT=$( basename ${BASH_SOURCE} )
export start=$(date +'%s');
secs_to_human() {
    echo "$(( ${1} / 3600 ))h $(( (${1} / 60) % 60 ))m $(( ${1} % 60 ))s"
}


source ${SCRIPT_DIR}/../../envars.sh;

declare YEAR=$(date +"%Y");
declare SITE_PATH="./sites/${ERPNEXT_SITE_URL}";
declare PRIVATE_PATH="${SITE_PATH}/private";
declare BACKUPS_PATH="${PRIVATE_PATH}/backups";
declare FILES_PATH="${PRIVATE_PATH}/files";
declare SITE_ALIAS="${ERPNEXT_SITE_URL//./_}";
declare TMP_BACKUP_DIR="/dev/shm/BKP";
declare BACKUP_DIR="${TARGET_BENCH}/BKP";
declare BACKUP_FILE_NAME_HOLDER="${BACKUP_DIR}/BACKUP.txt";
declare ACTIVE_DATABASE="";
declare DOMAIN="";

function restoreDatabase() {

  declare RESTORE="restoreParms";
  declare RESTORE_PARAM=${1};
  echo -e "SITE_PATH = ${SITE_PATH}";
  echo -e "PRIVATE_PATH = ${PRIVATE_PATH}";
  echo -e "BACKUPS_PATH = ${BACKUPS_PATH}";
  echo -e "FILES_PATH = ${FILES_PATH}";
  echo -e "SITE_ALIAS = ${SITE_ALIAS}";
  echo -e "TMP_BACKUP_DIR = ${TMP_BACKUP_DIR}";
  echo -e "BACKUP_DIR = ${BACKUP_DIR}";
  echo -e "BACKUP_FILE_NAME_HOLDER = ${BACKUP_FILE_NAME_HOLDER}";


  if [[ -z ${MYPWD} ]]; then
    echo -e "Must supply mariadb-root-password environment variable 'MYPWD'
    export MYPWD='';";
    exit;
  fi;

  declare BACKUP_FILE_DATE="";
  mkdir -p ${TMP_BACKUP_DIR};
  pushd ${TMP_BACKUP_DIR} >/dev/null;

    echo -e "BACKUP_DIR => ${TMP_BACKUP_DIR}";

    if [ ! -f ${BACKUP_FILE_NAME_HOLDER} ]; then
      echo -e "\n* * * ERROR: Backup file name file '${BACKUP_FILE_NAME_HOLDER}'! * * * \n";
      exit;
    fi;

    declare BACKUP_FILE_FULL_NAME=$(cat ${BACKUP_FILE_NAME_HOLDER});
    declare BACKUP_FILE_DATE=$(echo ${BACKUP_FILE_FULL_NAME} | cut -d - -f 1)

    if [ ! -f ${BACKUP_DIR}/${BACKUP_FILE_FULL_NAME} ]; then
      echo -e "\n* * * Backup '${BACKUP_FILE_FULL_NAME}' was not found at $(pwd)! * * * \n";
    else
      echo -e "\n/* ~~~~~~~~  Archive to decompress: ${BACKUP_FILE_FULL_NAME} ~~~~~~~~~*/";
      declare filefrag="";
      filefrag=$(echo -e "${BACKUP_FILE_FULL_NAME}" | grep -o "\-.*\.");
      filefrag=${filefrag#"-"};
      filefrag=${filefrag%"."};

      if [[ "${filefrag}" != "${SITE_ALIAS}" ]]; then
        echo -e "Back up of '${filefrag}' does not match current site '${SITE_ALIAS}'";
        declare BACKUP_FILE_NAME=${BACKUP_FILE_FULL_NAME%".tgz"}
        rm -fr *;
        tar zxvf ${BACKUP_DIR}/${BACKUP_FILE_FULL_NAME} > /dev/null;
        echo -e ".... ${BACKUP_FILE_NAME}";
        gunzip ${BACKUP_FILE_NAME}-database.sql.gz;
        ls -la ${BACKUP_FILE_NAME}-*;

        declare OLD_FILE="";
        declare NEW_FILE="";

        OLD_FILE="${BACKUP_FILE_NAME}-database.sql";
        NEW_FILE=${OLD_FILE/${filefrag}/"${SITE_ALIAS}"};
        echo "-- ${OLD_FILE} --"    
        echo "-- ${NEW_FILE} --"    
        mv ${OLD_FILE} ${NEW_FILE};
        gzip ${NEW_FILE};

        OLD_FILE="${BACKUP_FILE_NAME}-files.tar";
        NEW_FILE=${OLD_FILE/${filefrag}/"${SITE_ALIAS}"};
        echo "-- ${OLD_FILE} --"    
        echo "-- ${NEW_FILE} --"    
        mv ${OLD_FILE} ${NEW_FILE};

        OLD_FILE="${BACKUP_FILE_NAME}-private-files.tar";
        NEW_FILE=${OLD_FILE/${filefrag}/"${SITE_ALIAS}"};
        echo "-- ${OLD_FILE} --"    
        echo "-- ${NEW_FILE} --"    
        mv ${OLD_FILE} ${NEW_FILE};

        OLD_FILE="${BACKUP_FILE_NAME}-site_config_backup.json";
        NEW_FILE=${OLD_FILE/${filefrag}/"${SITE_ALIAS}"};
        echo "-- ${OLD_FILE} --"    
        echo "-- ${NEW_FILE} --"    
        mv ${OLD_FILE} ${NEW_FILE};

        jq -r . ${NEW_FILE};

        OLD_FILE="${BACKUP_FILE_NAME}.tgz";
        NEW_FILE=${OLD_FILE/${filefrag}/"${SITE_ALIAS}"};
        echo -e "${BACKUP_DIR}/${NEW_FILE}";

        echo -e "tar zcvf ${BACKUP_DIR}/${NEW_FILE} ${NEW_FILE%".tgz"}-* ";
                 tar zcvf ${BACKUP_DIR}/${NEW_FILE} ${NEW_FILE%".tgz"}-*;

        echo -e "echo -e \"${NEW_FILE}\" > ${BACKUP_FILE_NAME_HOLDER}";
                 echo -e "${NEW_FILE}" > ${BACKUP_FILE_NAME_HOLDER};


      fi;

      pwd;

      rm -fr ${BACKUP_FILE_DATE}*;
      echo -e "xxxx";
      ls -la;
      BACKUP_FILE_FULL_NAME=$(cat ${BACKUP_FILE_NAME_HOLDER});
      ls -la ${BACKUP_DIR}/${BACKUP_FILE_FULL_NAME};
      echo -e "tar zxvf ${BACKUP_DIR}/${BACKUP_FILE_FULL_NAME}";
      tar zxvf ${BACKUP_DIR}/${BACKUP_FILE_FULL_NAME};
      ls -la ${BACKUP_FILE_DATE}*;
      # tar zxvf ${BACKUP_FILE_FULL_NAME} \
      #       && BACKUP_FILE_DATE=$(echo ${BACKUP_FILE_FULL_NAME} | cut -d - -f 1) \
      #       || echo SHIT;
      # ls -la;
    fi;
  popd >/dev/null;

  pushd ${TARGET_BENCH} >/dev/null;
    if [[ "X${BACKUP_FILE_DATE}X" != "XX" ]]; then
      echo -e "\n/* ~~~~~~~~  Backup to be restored: ${BACKUP_FILE_DATE} ~~~~~~~~~*/";
      declare BUSQ="${TMP_BACKUP_DIR}/${BACKUP_FILE_DATE}-${SITE_ALIAS}-database.sql.gz";
      declare BUPU="${TMP_BACKUP_DIR}/${BACKUP_FILE_DATE}-${SITE_ALIAS}-files.tar";
      declare BUPR="${TMP_BACKUP_DIR}/${BACKUP_FILE_DATE}-${SITE_ALIAS}-private-files.tar";
      declare BUSC="${TMP_BACKUP_DIR}/${BACKUP_FILE_DATE}-${SITE_ALIAS}-site_config_backup.json";

      declare BUKF="${TMP_BACKUP_DIR}/${BACKUP_FILE_DATE}-${SITE_ALIAS}-${KEY_FILE_NAME}";

      ls -la ${BUPR};
      ls -la ${BUPU};
      ls -la ${BUSQ};
      ls -la ${TMP_BACKUP_DIR};
      # echo -e "\n/* ~~~~~~~~  Curtailed ~~~~~~~~~ */";
      # exit;

      declare PASS=" --mariadb-root-password ${MYPWD}";
      declare DATA=" ${BUSQ}";
      declare FILE=" --with-public-files ${BUPU}";
      declare PRIV=" --with-private-files ${BUPR}";

      echo -e "\n/* ~~~~~~~~  Stopping ERPNext ~~~~~~~~~ */";
      sudo -A supervisorctl stop all;

      DOMAIN=${ERPNEXT_SITE}.${ERPNEXT_DNS}.${ERPNEXT_TLD};
      echo -e "Restore parameter '${RESTORE_PARAM}' vs '${RESTORE}' ??";
      if [[ "${RESTORE}" == "${RESTORE_PARAM}" ]]; then
        echo -e "\n/* ~~~~~~~~  Patching  site_config.json ~~~~~~~~~ */";
        # jq -r . ${BUSC}
        # jq -r . ./sites/${DOMAIN}/site_config.json
        # ls -la ./sites/${DOMAIN}/site_config.json;
        # ls -la ${BUSC};
        echo -e "Copying '${BUSC}' to './sites/${DOMAIN}/site_config.json'";
        cp ${BUSC} ./sites/${DOMAIN}/site_config.json
      else
        echo -e "Won't restore 'site_config.json'";
      fi;


      ACTIVE_DATABASE=$(jq -r .db_name ./sites/${DOMAIN}/site_config.json);
      echo -e "\n/* <~~~~~~~~~~~~~ Restoring database ${ACTIVE_DATABASE} ~~~~~~~~~~~~~~~> */";
      echo -e "bench --site ${ERPNEXT_SITE_URL} --force restore ${PASS} ${DATA} ${FILE} ${PRIV}";
               bench --site ${ERPNEXT_SITE_URL} --force restore ${PASS} ${DATA} ${FILE} ${PRIV};
      echo -e "/* <~~~~~~~~~~~~~~ Restored ~~~~~~~~~~~~~~~> */";

      pushd BKP >/dev/null;
        echo -e "\n/* <~~~~~~~~~~~~~ Restoring database views ~~~~~~~~~~~~~~~> */";
        mysql -AD ${ACTIVE_DATABASE} < ./views.ddl;
        echo -e "/* <~~~~~~~~~~~~~~ Restored ~~~~~~~~~~~~~~~> */";
      popd >/dev/null;

      rm -fr ${BUSQ};
      rm -fr ${BUPU};
      rm -fr ${BUPR};
      rm -fr ${BUSC};

    else
      echo -e "ERROR: Cannot find files from decompressed archive '${BACKUP_FILE_FULL_NAME}';";
    fi;
  popd >/dev/null;

  export seconds=$(($(date +'%s') - $start));
}

if [[ ${SCRIPT_NAME} = ${THIS_SCRIPT} ]] ; then
  echo -e "start restoring backup";
  restoreDatabase ${1};

  if [[ 0 == 1 ]]; then
    echo -e "\n/* ~~~~~~~~  Restarting ERPNext ~~~~~~~~~ */";
    sudo -A supervisorctl start all;
  else
    echo -e "\n/* ~~~~~~~~  Restarting ERPNext *** SKIPPED *** ~~~~~~~~~ */";
  fi;

  echo -e "\n\n/* <~~~~~~~~~~~~~~ Elapsed  $(secs_to_human $seconds) seconds ~~~~~~~~~~~~~~~> */







  ";

else
  echo " - Sourced '${THIS_SCRIPT}' from '${SCRIPT_NAME}'"
fi 
