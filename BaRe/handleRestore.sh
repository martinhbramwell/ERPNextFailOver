#!/usr/bin/env bash
#

export SCRIPT_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )";
export CURR_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )"   && pwd )
export SCRIPT_NAME=$( basename ${0#-} );
export THIS_SCRIPT=$( basename ${BASH_SOURCE} )

# echo -e "SCRIPT_DIR ${SCRIPT_DIR}";
# echo -e "CURR_SCRIPT_DIR ${CURR_SCRIPT_DIR}";
# echo -e "SCRIPT_NAME ${SCRIPT_NAME}";
# echo -e "THIS_SCRIPT ${THIS_SCRIPT}";

source ${CURR_SCRIPT_DIR}/utils.sh;


declare SITE_ALIAS="${ERPNEXT_SITE_URL//./_}";

declare TMP_BACKUP_DIR="${TMP_DIR}/BKP";
declare BACKUP_DIR="${TARGET_BENCH}/BKP";
declare BACKUP_FILE_NAME_HOLDER="${BACKUP_DIR}/BACKUP.txt";
declare ACTIVE_DATABASE="";

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

export GOOGLE_SOCIAL_LOGIN_PACKAGE="GSLP.json";
function buildGoogleSocialLoginPackage() {
  local CLIENT_ID="$(echo ${GOOGLE_SL_PARMS} | jq -r .client_id)";
  local CLIENT_SECRET="$(echo ${GOOGLE_SL_PARMS} | jq -r .client_secret)";
  cat > ${TMP_DIR}/${GOOGLE_SOCIAL_LOGIN_PACKAGE} <<EOF
{
  "name": "google",
  "enable_social_login": 1,
  "social_login_provider": "Google",
  "client_id": "${CLIENT_ID}",
  "provider_name": "Google",
  "client_secret": "${CLIENT_SECRET}",
  "icon": "/assets/frappe/icons/social/google.svg",
  "base_url": "https://www.googleapis.com",
  "authorize_url": "https://accounts.google.com/o/oauth2/auth",
  "access_token_url": "https://accounts.google.com/o/oauth2/token",
  "redirect_url": "/api/method/frappe.www.login.login_via_google",
  "api_endpoint": "oauth2/v2/userinfo",
  "custom_base_url": 0,
  "auth_url_data": "{\"scope\": \"https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email\", \"response_type\": \"code\"}",
  "doctype": "Social Login Key"
}
EOF
}

function restoreSocialLoginConfig() {

  local DSIT="../sites/${ERPNEXT_SITE_URL}"

  local PRIVATES="${DSIT}/private/files"
  source ${PRIVATES}/apikey.sh;
  # echo -e ${KEYS}
  local RESOURCE_URL="https://${ERPNEXT_SITE_URL}/api/resource";
  local SWITCHES="--location  --no-progress-meter --request";
  local AUTH_HEADER="Authorization: token ${KEYS}";
  local CONTENT_HEADER="Content-Type: application/json";
  local SLK="Social%20Login%20Key";
  local SOCIAL_LOGIN_CONF_FILE="social_login_parameters.json";
  local SOCIAL_LOGIN_CONF=${DSIT}/${SOCIAL_LOGIN_CONF_FILE};
  local SOCIAL_LOGIN_PARAMETERS="";
  local GOOGLE_SL_PARMS="";

  # echo -e curl ${SWITCHES} GET "${RESOURCE_URL}/Company" --header "${AUTH_HEADER}"

  local RSLT=$(curl ${SWITCHES} GET "${RESOURCE_URL}/Company" --header "${AUTH_HEADER}");
  # echo -e $?;
  local ERR_MSG="${pRED}     *** API call to get name of company failed. ***${pDFLT}
    Command was : curl ${SWITCHES} GET \"${RESOURCE_URL}/Company\" --header \"${AUTH_HEADER}\"";
  local ERR="Error"
  if [ $? != 0 ]; then
    echo -e "${ERR_MSG}";
  elif [[ "${RSLT}" =~ .*"${ERR}".* ]]; then
    echo -e "${ERR_MSG}\n${RSLT}";
  else
    # echo -e $?;
    # echo ${RSLT} | jq -r .;
    COMPANY=$(echo ${RSLT} | jq -r .data[0].name)
    # COMPANY=$(curl ${SWITCHES} DELETE "${RESOURCE_URL}/Social Login Key/google" --header "${AUTH_HEADER}" | jq -r .data);

    if [[ ! -f ${SOCIAL_LOGIN_CONF} ]]; then
      echo -e "\n\n${pYELLOW}Unable to find Social Login (Google) config for ${COMPANY} at '$(pwd)/${SOCIAL_LOGIN_CONF}'${pDFLT}";
    else
      echo -e "\n\n${pYELLOW}Ready to restore Social Login (Google) configuration file for \"${COMPANY}\".${pDFLT}";
      echo -e "  - deleting previous Social Login config...";
      R0SLT=$(curl ${SWITCHES} DELETE --header "${AUTH_HEADER}" --header "${CONTENT_HEADER}" "${RESOURCE_URL}/${SLK}/google");
      # echo ${RSLT} | jq -r .;
      MSG=$(echo ${RSLT} | jq -r .message)
      echo -e "          - deleted  (\"message\": \"${MSG}\")";
      echo -e "  - inserting correct Social Login config";

      GOOGLE_SL_PARMS=$(jq -r '.[]  | select(.name == "Google") | .parameters.web' ${SOCIAL_LOGIN_CONF});
      buildGoogleSocialLoginPackage;

      SOCIAL_LOGIN_PARAMETERS="${TMP_DIR}/${GOOGLE_SOCIAL_LOGIN_PACKAGE}";

      # cat "${SOCIAL_LOGIN_PARAMETERS}";
      # echo -e "curl ${SWITCHES} POST --header \"${AUTH_HEADER}\" --header \"${CONTENT_HEADER}\" -d @${SOCIAL_LOGIN_PARAMETERS} \"${RESOURCE_URL}/${SLK}";
      # curl ${SWITCHES} POST --header "${AUTH_HEADER}" --header "${CONTENT_HEADER}" -d @${SOCIAL_LOGIN_PARAMETERS} "${RESOURCE_URL}/${SLK}";
      RSLT=$(curl ${SWITCHES} POST --header "${AUTH_HEADER}" --header "${CONTENT_HEADER}" -d @${SOCIAL_LOGIN_PARAMETERS} "${RESOURCE_URL}/${SLK}");

      # echo ${RSLT} | jq -r .;
      MSG=$(echo ${RSLT} | jq -r .data.social_login_provider)
      echo -e "          - inserted  (\"social_login_provider\": \"${MSG}\")";
  exit;

    fi;
  fi;
}


# echo -e "
#            ***  CURTAILED  ***
#         Before restoring backup
#     ==========================================
# "${ENVIRONMENT_VARIABLES}"
# ";

# exit;
export OLD_SITE_ERPNEXT_VERSION="";
export CURRENT_ERPNEXT_VERSION="";

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
    echo -e "${pRED}* * * Unable to get MariaDB password from '${CURR_SCRIPT_DIR}/../${SITE_PATH}/${SITE_CONFIG}' * * * .${pDFLT}";
  else
    echo -e "    - Got MariaDB password from '${CURR_SCRIPT_DIR}/../${SITE_PATH}/${SITE_CONFIG}'.";
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

    local BACKUP_FILE_FULL_NAME=$(cat ${BACKUP_FILE_NAME_HOLDER});
    local BACKUP_FILE_DATE=$(echo ${BACKUP_FILE_FULL_NAME} | cut -d - -f 1);


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



  # echo -e "\n${pRED}----------------- * Restore handler curtailed * --------------------------${pDFLT}
  # ${BACKUP_DIR}/${BACKUP_FILE_FULL_NAME}";
  # ls -la ${BACKUP_DIR}/${BACKUP_FILE_FULL_NAME};
  # exit;

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

      echo -e "${pDFLT}         started ...${pFAINT_BLUE}";
      bench --site ${ERPNEXT_SITE_URL} --force restore ${PASS} ${FILE} ${PRIV} ${DATA};
      echo -e "${pDFLT}         ... restored";

      # CURRENT_ERPNEXT_VERSION=$(bench version);
      CURRENT_ERPNEXT_VERSION=$(bench version | grep erpnext | cut -d' ' -f 2 | cut -d'.' -f 1);
      echo -e "\n      - Found current site version :: ${CURRENT_ERPNEXT_VERSION}";

      pushd ./sites/${ERPNEXT_SITE_URL}/private/files >/dev/null;
        if [[ -f erpnextVersion.txt ]]; then
          OLD_SITE_ERPNEXT_VERSION=$(echo -e "$(cat erpnextVersion.txt | cut -d' ' -f 2)" | cut -d'.' -f 1);
          echo -e "\n      - Found version of old site :: ${OLD_SITE_ERPNEXT_VERSION}";
        else
          echo -e "${pYELLOW}* * * WARNING: Unable to determine ERPNext version of old site * * * .
                  Will assume it is version 13.
                  A file './sites/${ERPNEXT_SITE_URL}/private/files/erpnextVersion.txt' was expected but not found.
                  The file should contain, for example, \"erpnext 13.18.7\".
          ${pDFLT}";
          # OLD_SITE_ERPNEXT_VERSION=${CURRENT_ERPNEXT_VERSION};
          OLD_SITE_ERPNEXT_VERSION=13;
        fi;

        # echo -e "\n      - Restoring database views";
        # echo -e "${pDFLT}         started ...";
        # mysql -AD ${ACTIVE_DATABASE} < ./ddlViews.sql;
        # echo -e "         ... restored";
      popd >/dev/null;


      rm -fr ${BUSQ};
      rm -fr ${BUPU};
      rm -fr ${BUPR};
      rm -fr ${BUSC};

    else
      echo -e "ERROR: Cannot find files from decompressed archive '${BACKUP_FILE_FULL_NAME}';";
    fi;
  popd >/dev/null;

}

if [[ ${SCRIPT_NAME} = ${THIS_SCRIPT} ]] ; then
  echo -e "\n - Restoring backup ...";

  restoreDatabase ${1};

  if [[ 1 == 1 ]]; then
    if [[ ${CURRENT_ERPNEXT_VERSION} -gt ${OLD_SITE_ERPNEXT_VERSION} ]]; then
      # echo -e "\n      - Must run bench 'migrate' and 'clear-cache'.${pFAINT_BLUE}";

      echo -e "${pYELLOW}     - Correcting V13 to V14 discrepancies.${pDFLT} ";
      echo -e "${pGOLD}        ~ Migrate.${pDFLT} ";
      bench --site ${ERPNEXT_SITE_URL} migrate;
      echo -e "${pGOLD}        ~ Clear cache.${pDFLT} ";
      bench --site ${ERPNEXT_SITE_URL} clear-cache;
      echo -e "${pGOLD}        ~ Enable Scheduler.${pDFLT} ";
      bench --site ${ERPNEXT_SITE_URL} enable-scheduler;

    fi;
    echo -e "\n      - Restarting ERPNext${pFAINT_BLUE}";
    sudo -A supervisorctl start all;
    echo -e "${pDFLT}            restarted";

    echo -e "\n - Delaying for restart to complete...";
    sleep 10;

    # pushd ${TARGET_BENCH} >/dev/null;
    #   pushd ./sites/${ERPNEXT_SITE_URL}/private/files >/dev/null;
    #     # OLD_SITE_ERPNEXT_VERSION=$(echo -e "$(cat erpnextVersion.txt | cut -d' ' -f 2)" | cut -d'.' -f 1);
    #     # echo -e "\n      - Found version of old site :: ${OLD_SITE_ERPNEXT_VERSION}";

    #     echo -e "\n      - Restoring database views to database :: ${ACTIVE_DATABASE}";
    #     echo -e "${pDFLT}         started ...";
    #     cat ./ddlViews.sql;
    #     mysql -AD ${ACTIVE_DATABASE} < ./ddlViews.sql;
    #     echo -e "         ... restored";
    #   popd >/dev/null;
    # popd >/dev/null;


    # echo -e "\n${pRED}----------------- Restore handler curtailed --------------------------${pDFLT}
    # OLD_SITE_ERPNEXT_VERSION = ${OLD_SITE_ERPNEXT_VERSION}
    # CURRENT_ERPNEXT_VERSION = ${CURRENT_ERPNEXT_VERSION}
    # ";
    # pwd;
    # # whoami;
    # exit;

    echo -e "\n - Restoring Social Login ...";
    restoreSocialLoginConfig;
    echo -e "${pDFLT}   restored";
  else
    echo -e "\n      - Restarting ERPNext ${pRED}*** SKIPPED ***${pDFLT}";
  fi;


  seconds=$(($(date +'%s') - ${start}));
  echo -e "\n\n${pGREEN}Restore completed. Elapsed time, $(secs_to_human ${seconds}) seconds

  ${pDFLT}";

else
  echo " - Sourced '${THIS_SCRIPT}' from '${SCRIPT_NAME}'"
fi 
