#!/usr/bin/env bash
#

export SCRIPT_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )";
export CURR_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )"   && pwd )
export SCRIPT_NAME=$( basename ${0#-} );
export THIS_SCRIPT=$( basename ${BASH_SOURCE} )

echo -e "SCRIPT_DIR ${SCRIPT_DIR}";
echo -e "CURR_SCRIPT_DIR ${CURR_SCRIPT_DIR}";
echo -e "SCRIPT_NAME ${SCRIPT_NAME}";
echo -e "THIS_SCRIPT ${THIS_SCRIPT}";

source ${CURR_SCRIPT_DIR}/utils.sh;


declare SITE_ALIAS="${ERPNEXT_SITE_URL//./_}";

declare TMP_BACKUP_DIR="${TMP_DIR}/BKP";
declare BACKUP_DIR="${TARGET_BENCH}/BKP";
declare BACKUP_FILE_NAME_HOLDER="${BACKUP_DIR}/BACKUP.txt";
declare ACTIVE_DATABASE="";

  # pwd;
  # ls -la;
  # echo -e "
  #            ***  CURTAILED  ***
  #         Before restoring backup
  #     ==========================================
  # "${ENVIRONMENT_VARIABLES}"
  # ";
  # exit;

function getNewSiteNameFromFileName() {
  declare filefrag=$(echo -e "${1}" | grep -o "\-.*\.");
  filefrag=${filefrag#"-"};
  BACKUP_FILE_SITE_NAME=${filefrag%"."};
}

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
  NEW_FILE=${OLD_FILE/${BACKUP_FILE_SITE_NAME}/"${SITE_ALIAS}"};
  echo "       - '${OLD_FILE}' becomes '${NEW_FILE}'."    
  mv ${OLD_FILE} ${NEW_FILE};
  # ls -la;
  gzip ${NEW_FILE};


  OLD_FILE="${BACKUP_FILE_NAME}-files.tar";
  NEW_FILE=${OLD_FILE/${BACKUP_FILE_SITE_NAME}/"${SITE_ALIAS}"};
  echo "       - '${OLD_FILE}' becomes '${NEW_FILE}'."    
  mv ${OLD_FILE} ${NEW_FILE};

  OLD_FILE="${BACKUP_FILE_NAME}-private-files.tar";
  NEW_FILE=${OLD_FILE/${BACKUP_FILE_SITE_NAME}/"${SITE_ALIAS}"};
  echo "       - '${OLD_FILE}' becomes '${NEW_FILE}'."    
  mv ${OLD_FILE} ${NEW_FILE};

  OLD_FILE="${BACKUP_FILE_NAME}-site_config_backup.json";
  NEW_FILE=${OLD_FILE/${BACKUP_FILE_SITE_NAME}/"${SITE_ALIAS}"};
  echo "       - '${OLD_FILE}' becomes '${NEW_FILE}'."
  mv ${OLD_FILE} ${NEW_FILE};


  echo -e "${pDFLT}    - patch site name with sed.  -->  '${NEW_FILE}' from '${OLD_SITE_URL//_/.}' to '${ERPNEXT_SITE_URL}' ";

  sed -i "s/${OLD_SITE_URL//_/.}/${ERPNEXT_SITE_URL}/g" ${NEW_FILE};
  # jq -r . ${NEW_FILE};

  OLD_FILE="${BACKUP_FILE_NAME}.tgz";
  NEW_FILE=${OLD_FILE/${BACKUP_FILE_SITE_NAME}/"${SITE_ALIAS}"};

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

  # echo -e "${CURR_SCRIPT_DIR}";

  export EXISTING_DB_PASSWORD=$(jq -r .db_password "${CURR_SCRIPT_DIR}/../${SITE_PATH}/${SITE_CONFIG}");
  if [[ -z ${EXISTING_DB_PASSWORD} ]]; then
    echo -e "Unable to get MariaDB password from '${CURR_SCRIPT_DIR}/../${SITE_PATH}/${SITE_CONFIG}'.";
  else
    echo -e "Got MariaDB password from '${CURR_SCRIPT_DIR}/../${SITE_PATH}/${SITE_CONFIG}'.";
  fi;


  declare BACKUP_FILE_DATE="";
  declare BACKUP_FILE_SITE_NAME="";
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
      echo -e "    - Process archive file: '${BACKUP_FILE_FULL_NAME}' into '$(pwd)'.";

      getNewSiteNameFromFileName ${BACKUP_FILE_FULL_NAME};

      echo -e "    - Does site name, '${BACKUP_FILE_SITE_NAME}', extracted from backup file full name, match this site '${SITE_ALIAS}' ??";
      if [[ "${BACKUP_FILE_SITE_NAME}" != "${SITE_ALIAS}" ]]; then
        export OLD_SITE_URL="${BACKUP_FILE_SITE_NAME}";
        repackageWithCorrectedSiteName;
      fi;

      echo -e "    - Commencing decompression. Command is: 
         tar zxvf ${BACKUP_DIR}/${BACKUP_FILE_FULL_NAME}${pGOLD}";

      tar zxvf ${BACKUP_DIR}/${BACKUP_FILE_FULL_NAME};
      echo -e "  ${pDFLT}";

    fi;
  popd >/dev/null;

  pushd ${TARGET_BENCH} >/dev/null;
    if [[ "X${BACKUP_FILE_DATE}X" != "XX" ]]; then
      echo -e "\n    - Backup to be restored: ${TMP_BACKUP_DIR}/${BACKUP_FILE_DATE}-${SITE_ALIAS}*";
      declare BUSQ="${TMP_BACKUP_DIR}/${BACKUP_FILE_DATE}-${SITE_ALIAS}-database.sql.gz";
      declare BUPU="${TMP_BACKUP_DIR}/${BACKUP_FILE_DATE}-${SITE_ALIAS}-files.tar";
      declare BUPR="${TMP_BACKUP_DIR}/${BACKUP_FILE_DATE}-${SITE_ALIAS}-private-files.tar";
      declare BUSC="${TMP_BACKUP_DIR}/${BACKUP_FILE_DATE}-${SITE_ALIAS}-site_config_backup.json";

      # declare PASS=" --mariadb-root-password ${EXISTING_DB_PASSWORD}";
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

            # SHOW_PWD="${OLD_PWD}";

            echo -e "        Writing current database password into new site configuration '${BUSC}'.";
            sed -i "s/.*\"db_password\":.*/ \"db_password\": \"${OLD_PWD}\",/" ${BUSC};
          else

            # SHOW_PWD=${NEW_PWD};

            echo -e "        Setting new database user '${NEW_USER}' & password '${SHOW_PWD}' into current database.";
            mariadb -AD mysql --skip-column-names --batch \
                        -e "select \"        [ set password for '${NEW_USER}'@'localhost' = PASSWORD('${NEW_PWD}') ]\"";
            mariadb -AD mysql --skip-column-names --batch \
                        -e "set password for '${NEW_USER}'@'localhost' = PASSWORD('${NEW_PWD}');";
          fi;

        popd >/dev/null;

        echo -e "      - Overwriting './sites/${ERPNEXT_SITE_URL}/${SITE_CONFIG}' with ${SITE_CONFIG} from backup.";
        cp ${BUSC} ./sites/${ERPNEXT_SITE_URL}/${SITE_CONFIG}

      else
        echo -e "        Won't overwrite '${SITE_CONFIG}'";
      fi;

      ACTIVE_DATABASE=$(jq -r .db_name ./sites/${ERPNEXT_SITE_URL}/${SITE_CONFIG});
      echo -e "\n      - Restoring database ${ACTIVE_DATABASE}.  Command is:
        ==>  bench  --site ${ERPNEXT_SITE_URL} --force restore --mariadb-root-password ${SHOW_PWD} \\
                   ${FILE} \\
                   ${PRIV} \\
                         ${DATA}${pFAINT_BLUE}";

# echo -e "\n${pRED}----------------- * Restore handler curtailed * --------------------------${pDFLT}\n${EXISTING_DB_PASSWORD}";
# exit;
      echo -e "${pDFLT}         started ...";
      bench --site ${ERPNEXT_SITE_URL} --force restore ${PASS} ${FILE} ${PRIV} ${DATA};
      echo -e "         ... restored";

      pushd BKP >/dev/null;
        echo -e "      - Restoring database views";
        echo -e "${pDFLT}         started ...";
        mysql -AD ${ACTIVE_DATABASE} < ./views.ddl;
        echo -e "         ... restored";
      popd >/dev/null;


      rm -fr ${BUSQ};
      rm -fr ${BUPU};
      rm -fr ${BUPR};
      rm -fr ${BUSC};

    else
      echo -e "ERROR: Cannot find files from decompressed archive '${BACKUP_FILE_FULL_NAME}';";
    fi;
  popd >/dev/null;

  seconds=$(($(date +'%s') - $start));
}

if [[ ${SCRIPT_NAME} = ${THIS_SCRIPT} ]] ; then
  echo -e "\n - Restoring backup ...";
  # pwd;
  # ls -la;
  # whoami;

  restoreDatabase ${1};

  # echo -e "\n${pRED}----------------- Restore handler curtailed --------------------------${pDFLT}\n";
  # exit;

  if [[ 1 == 1 ]]; then
    echo -e "\n      - Restarting ERPNext${pFAINT_BLUE}";
    sudo -A supervisorctl start all;
    echo -e "${pDFLT}            restarted";
  else
    echo -e "\n      - Restarting ERPNext ${pRED}*** SKIPPED ***${pDFLT}";
  fi;

  echo -e "\n\n${pGREEN}Restore completed. Elapsed time, $(secs_to_human $seconds) seconds

  ${pDFLT}";

else
  echo " - Sourced '${THIS_SCRIPT}' from '${SCRIPT_NAME}'"
fi 
