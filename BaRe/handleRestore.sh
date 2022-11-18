#!/usr/bin/env bash
#

export SCRIPT_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )";
export SCRIPT_NAME=$( basename ${0#-} );
export THIS_SCRIPT=$( basename ${BASH_SOURCE} )
export start=$(date +'%s');
secs_to_human() {
    echo "$(( ${1} / 3600 ))h $(( (${1} / 60) % 60 ))m $(( ${1} % 60 ))s"
}


source ${SCRIPT_DIR}/envars.sh;

export pRED="\033[1;40;31m";
export pYELLOW="\033[1;40;33m";
export pGOLD="\033[0;40;33m";
export pFAINT_BLUE="\033[0;49;34m";
export pGREEN="\033[1;40;32m";
export pDFLT="\033[0m";
export pBG_YLO="\033[1;43;33m";

declare YEAR=$(date +"%Y");
declare TARGET_HOST=${ERPNEXT_SITE_URL};

declare SITES="sites";
declare SITE_PATH="${SITES}/${TARGET_HOST}";
declare PRIVATE_PATH="${SITE_PATH}/private";
declare BACKUPS_PATH="${PRIVATE_PATH}/backups";
declare FILES_PATH="${PRIVATE_PATH}/files";

declare SITE_ALIAS="${ERPNEXT_SITE_URL//./_}";
declare TMP_BACKUP_DIR="/dev/shm/BKP";
declare BACKUP_DIR="${TARGET_BENCH}/BKP";
declare BACKUP_FILE_NAME_HOLDER="${BACKUP_DIR}/BACKUP.txt";
declare ACTIVE_DATABASE="";

declare SITE_CONFIG="site_config.json";

function repackageWithCorrectedSiteName() {
  echo -e "       The backup is from a different ERPNext site.";
  declare BACKUP_FILE_NAME=${BACKUP_FILE_FULL_NAME%".tgz"}
  rm -fr *;
  tar zxvf ${BACKUP_DIR}/${BACKUP_FILE_FULL_NAME} > /dev/null;
  echo -e "       Will rename all backup files ...${pFAINT_BLUE}";
  gunzip ${BACKUP_FILE_NAME}-database.sql.gz >/dev/null;
  # ls -la ${BACKUP_FILE_NAME}-*;

  declare OLD_FILE="";
  declare NEW_FILE="";

  OLD_FILE="${BACKUP_FILE_NAME}-database.sql";
  NEW_FILE=${OLD_FILE/${filefrag}/"${SITE_ALIAS}"};
  echo "       - '${OLD_FILE}' becomes '${NEW_FILE}'."    
  mv ${OLD_FILE} ${NEW_FILE};
  # ls -la;
  gzip ${NEW_FILE};


  OLD_FILE="${BACKUP_FILE_NAME}-files.tar";
  NEW_FILE=${OLD_FILE/${filefrag}/"${SITE_ALIAS}"};
  echo "       - '${OLD_FILE}' becomes '${NEW_FILE}'."    
  mv ${OLD_FILE} ${NEW_FILE};

  OLD_FILE="${BACKUP_FILE_NAME}-private-files.tar";
  NEW_FILE=${OLD_FILE/${filefrag}/"${SITE_ALIAS}"};
  echo "       - '${OLD_FILE}' becomes '${NEW_FILE}'."    
  mv ${OLD_FILE} ${NEW_FILE};

  OLD_FILE="${BACKUP_FILE_NAME}-site_config_backup.json";
  NEW_FILE=${OLD_FILE/${filefrag}/"${SITE_ALIAS}"};
  echo "       - '${OLD_FILE}' becomes '${NEW_FILE}'."
  mv ${OLD_FILE} ${NEW_FILE};


  echo -e "${pDFLT}    - patch site name with sed.  -->  '${NEW_FILE}' from '${OLD_SITE_URL//_/.}' to '${ERPNEXT_SITE_URL}' ";

  sed -i "s/${OLD_SITE_URL//_/.}/${ERPNEXT_SITE_URL}/g" ${NEW_FILE};
  # jq -r . ${NEW_FILE};

  OLD_FILE="${BACKUP_FILE_NAME}.tgz";
  NEW_FILE=${OLD_FILE/${filefrag}/"${SITE_ALIAS}"};

  echo -e "${pDFLT}    - Creating new package from repackaged contents of '${BACKUP_FILE_FULL_NAME}'."
           tar zcvf ${BACKUP_DIR}/${NEW_FILE} ${NEW_FILE%".tgz"}-* >/dev/null;

  echo -e "        Resulting file is -"
  echo -e "         - ${BACKUP_DIR}/${NEW_FILE}";

  echo -e "    - Writing new package file name into file name holder : '${BACKUP_FILE_NAME_HOLDER}'."
  echo -e "${NEW_FILE}" > ${BACKUP_FILE_NAME_HOLDER};

  # echo -e "\n${pRED}-----------------    Restore handler curtailed    --------------------------${pDFLT}\n"
  # pwd;
  # ls -la;
  # exit;
}

function restoreDatabase() {

  echo -e "    - File locations used:${pFAINT_BLUE}";
  echo -e "      - SITE_PATH = ${SITE_PATH}";
  echo -e "      - PRIVATE_PATH = ${SITE_PATH}/${PRIVATE_PATH}";
  echo -e "      - BACKUPS_PATH = ${SITE_PATH}/${BACKUPS_PATH}";
  echo -e "      - FILES_PATH = ${SITE_PATH}/${FILES_PATH}\n";

  echo -e "      - SITE_ALIAS = ${SITE_ALIAS}";
  echo -e "      - TMP_BACKUP_DIR = ${TMP_BACKUP_DIR}";
  echo -e "      - BACKUP_DIR = ${BACKUP_DIR}";
  echo -e "      - BACKUP_FILE_NAME_HOLDER = ${BACKUP_FILE_NAME_HOLDER}";
  echo -e "${pDFLT}";

  export MYPWD=$(jq -r .db_password "../${SITE_PATH}/${SITE_CONFIG}");
  if [[ -z ${MYPWD} ]]; then
    echo -e "Unable to get MariaDB password from '../${SITE_PATH}/${SITE_CONFIG}'.";
  fi;

  declare BACKUP_FILE_DATE="";
  echo -e "    - Ensuring work directory exists";
  mkdir -p ${TMP_BACKUP_DIR};

  pushd ${TMP_BACKUP_DIR} >/dev/null;

    echo -e "    - Getting backup file name from name holder file: '${BACKUP_FILE_NAME_HOLDER}'";
    if [ ! -f ${BACKUP_FILE_NAME_HOLDER} ]; then
      echo -e "\n* * * ERROR: Backup file name file '${BACKUP_FILE_NAME_HOLDER}'! * * * \n";
      exit;
    fi;

    declare BACKUP_FILE_FULL_NAME=$(cat ${BACKUP_FILE_NAME_HOLDER});
    declare BACKUP_FILE_DATE=$(echo ${BACKUP_FILE_FULL_NAME} | cut -d - -f 1)

    if [ ! -f ${BACKUP_DIR}/${BACKUP_FILE_FULL_NAME} ]; then
      echo -e "\n* * * Backup '${BACKUP_FILE_FULL_NAME}' was not found at $(pwd)! * * * \n";
    else
      echo -e "    - Will decompress archive file: '${BACKUP_FILE_FULL_NAME}'.";
      declare filefrag="";

      filefrag=$(echo -e "${BACKUP_FILE_FULL_NAME}" | grep -o "\-.*\.");
      filefrag=${filefrag#"-"};
      filefrag=${filefrag%"."};


      echo -e "    - Does site name, '${filefrag}', extracted from backup file full name, match this site '${SITE_ALIAS}' ??";
      if [[ "${filefrag}" != "${SITE_ALIAS}" ]]; then
        export OLD_SITE_URL="${filefrag}";
        repackageWithCorrectedSiteName;
      fi;

# BACKUP_FILE_FULL_NAME=$(cat ${BACKUP_FILE_NAME_HOLDER});
# ls -la ${BACKUP_DIR}/${BACKUP_FILE_FULL_NAME};
# echo -e "tar zxvf ${BACKUP_DIR}/${BACKUP_FILE_FULL_NAME}";

# pwd;
# ls -la;

      echo -e "    - Purging temporary data ${pRED}* * * Skipped * * * ${pDFLT}";
      # rm -fr ${BACKUP_FILE_DATE}*;

  # echo -e "\n${pRED}----------------- Restore handler curtailed --------------------------${pDFLT}\n";
  # exit;

      # tar zxvf ${BACKUP_DIR}/${BACKUP_FILE_FULL_NAME};
      # ls -la ${BACKUP_FILE_DATE}*;
     # tar zxvf ${BACKUP_FILE_FULL_NAME} \
      #       && BACKUP_FILE_DATE=$(echo ${BACKUP_FILE_FULL_NAME} | cut -d - -f 1) \
      #       || echo SHIT;
      # ls -la;
    fi;
  popd >/dev/null;

  pushd ${TARGET_BENCH} >/dev/null;
    if [[ "X${BACKUP_FILE_DATE}X" != "XX" ]]; then
      echo -e "\n    - Backup to be restored: ${BACKUP_FILE_DATE} ~~~~~~~~~ (${TMP_BACKUP_DIR})";
      declare BUSQ="${TMP_BACKUP_DIR}/${BACKUP_FILE_DATE}-${SITE_ALIAS}-database.sql.gz";
      declare BUPU="${TMP_BACKUP_DIR}/${BACKUP_FILE_DATE}-${SITE_ALIAS}-files.tar";
      declare BUPR="${TMP_BACKUP_DIR}/${BACKUP_FILE_DATE}-${SITE_ALIAS}-private-files.tar";
      declare BUSC="${TMP_BACKUP_DIR}/${BACKUP_FILE_DATE}-${SITE_ALIAS}-site_config_backup.json";

      # ls -la ${BUSQ};
      # echo -e "---------";
      # ls -la ${BUPU};
      # echo -e "---------";
      # ls -la ${BUPR};
      # echo -e "---------";
      # ls -la ${BUSC};
      # echo -e "---------";
      # ls -la ${TMP_BACKUP_DIR};
      # echo -e "---------";

      declare PASS=" --mariadb-root-password ${MYPWD}";
      declare DATA=" ${BUSQ}";
      declare FILE=" --with-public-files ${BUPU}";
      declare PRIV=" --with-private-files ${BUPR}";

      # echo -e "\n/* ~~~~~~~~  Stopping ERPNext ~~~~~~~~~ */";
      # sudo -A supervisorctl status all;


      echo -e "    - Should '${SITE_CONFIG}' of '${ERPNEXT_SITE_URL}' be overwritten?\n       Restore parameters file = '${RESTORE_SITE_CONFIG}'";

      if [[ "${RESTORE_SITE_CONFIG}" == "yes" ]]; then

        pushd "./sites/${ERPNEXT_SITE_URL}/" >/dev/null;
          declare SITE_CONFIG_COPY_NAME="";
          SITE_CONFIG_COPY_NAME="${SITE_CONFIG%%.*}_$(date "+%Y-%m-%d_%H.%M").${SITE_CONFIG##*.}";
          echo -e "      - Creating dated safety copy of '${SITE_CONFIG}' :: ${SITE_CONFIG_COPY_NAME}.";
          cp ${SITE_CONFIG} ${SITE_CONFIG_COPY_NAME};

          declare NEW_USER=$(jq -r .db_name ${BUSC});
          declare NEW_PWD=$(jq -r .db_password ${BUSC});
          declare OLD_PWD=$(jq -r .db_password ${SITE_CONFIG});

          declare SHOW_PWD="********";

          echo -e "    - Should 'db_password' of site '${ERPNEXT_SITE_URL}' be overwritten?\n       Keep current database password = '${KEEP_SITE_PASSWORD}'";
          if [[ "${KEEP_SITE_PASSWORD}" == "yes" ]]; then

            SHOW_PWD="${OLD_PWD}";

            echo -e "        Writing current database password into new site configuration '${BUSC}'.";
            sed -i "s/.*\"db_password\":.*/  \"db_password\": \"${OLD_PWD}\",/" ${BUSC};
          else

            SHOW_PWD=${NEW_PWD};

            echo -e "        Setting new database user '${NEW_USER}' & password '${SHOW_PWD}' into current database.";
            mariadb -AD mysql --skip-column-names --batch \
                        -e "select \"        [ set password for '${NEW_USER}'@'localhost' = PASSWORD('${SHOW_PWD}') ]\"";
            mariadb -AD mysql --skip-column-names --batch \
                        -e "set password for '${NEW_USER}'@'localhost' = PASSWORD('${NEW_PWD}');";
          fi;



        popd >/dev/null;

# echo -e "\n${pRED}----------------- Restore handler -- ${SITE_CONFIG} KEEP_SITE_PASSWORD = '${KEEP_SITE_PASSWORD}' --------------------------${pDFLT}\n";
# exit;

        echo -e "      - Overwriting './sites/${ERPNEXT_SITE_URL}/${SITE_CONFIG}' with ${SITE_CONFIG} from backup.";
        # jq -r . ./sites/${ERPNEXT_SITE_URL}/${SITE_CONFIG}

        # sed -i "s/${filefrag//_/.}/${ERPNEXT_SITE_URL}/g" ${NEW_FILE};
        # jq -r . ${NEW_FILE};

        # ls -la ./sites/${ERPNEXT_SITE_URL}/${SITE_CONFIG};
        # ls -la ${BUSC};
        # cp ${BUSC} ./sites/${ERPNEXT_SITE_URL}/${SITE_CONFIG}

      else
        echo -e "        Won't overwrite '${SITE_CONFIG}'";
      fi;


      ACTIVE_DATABASE=$(jq -r .db_name ./sites/${ERPNEXT_SITE_URL}/${SITE_CONFIG});
      echo -e "\n      - Restoring database ${ACTIVE_DATABASE} ";
      echo -e "           Command :: $ bench --site ${ERPNEXT_SITE_URL} --force restore ${PASS} ${FILE} ${PRIV} ${DATA} \n\n${pFAINT_BLUE}";
               bench --site ${ERPNEXT_SITE_URL} --force restore ${PASS} ${FILE} ${PRIV} ${DATA};
      echo -e "\n${pDFLT}           Restored\n";

      pushd BKP >/dev/null;
        echo -e "      - Restoring database views";
        mysql -AD ${ACTIVE_DATABASE} < ./views.ddl;
        echo -e "           Restored\n";
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

# echo -e "\n${pRED}----------------- Restore handler curtailed --------------------------${pDFLT}\n";
# exit;

if [[ ${SCRIPT_NAME} = ${THIS_SCRIPT} ]] ; then
  echo -e "\n - Restoring backup ...";
  restoreDatabase ${1};

  if [[ 1 == 1 ]]; then
    echo -e "\n      - Restarting ERPNext${pFAINT_BLUE}";
    sudo -A supervisorctl start all;
    echo -e "\n${pDFLT}          Restarted";
  else
    echo -e "\n      - Restarting ERPNext ${pRED}*** SKIPPED ***${pDFLT}";
  fi;

  echo -e "\n\n${pGREEN}Restore completed. Elapsed time, $(secs_to_human $seconds) seconds



  ${pDFLT}";

else
  echo " - Sourced '${THIS_SCRIPT}' from '${SCRIPT_NAME}'"
fi 
