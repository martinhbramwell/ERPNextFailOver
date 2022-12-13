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


declare TO="${BACKUP_DIR}"
declare FROM="${TARGET_BENCH}/${BACKUPS_PATH}";

declare RPRT="backup_report.txt";
declare DB_NAME="";

declare PREFIX="./${BACKUPS_PATH}/"
declare COMMENT="";

if [[ -z ${1} ]]; then
  echo -e "Usage:  ${SCRIPT_NAME} \"Obligatory comment in double quotes\"
";
  exit;
else
  COMMENT="${1}";
fi;


pushd ${TARGET_BENCH} >/dev/null;
  SOURCE_HOST=${TARGET_HOST};

  echo -e "\n - Backing up \"${COMMENT}\" for site ${SOURCE_HOST} (in ${BACKUP_DIR}).";

  pushd sites/${SOURCE_HOST} >/dev/null;
    DB_NAME=$(jq -r .db_name ${SITE_CONFIG});
    pushd private/files >/dev/null;
      echo -e "   - Saving database views constructors to site private files directory. (db: ${DB_NAME})";
      mysql -AD ${DB_NAME} \
           --skip-column-names \
           --batch \
           -e 'select CONCAT("DROP TABLE IF EXISTS ", TABLE_NAME, "; CREATE OR REPLACE VIEW ", TABLE_NAME, " AS ", VIEW_DEFINITION, "; ") as ddl FROM information_schema.views WHERE table_schema = (SELECT database() FROM dual)' \
        > ddlViews.sql;
    popd >/dev/null;
  popd >/dev/null;

  mkdir -p ${BACKUP_DIR};
  
  
  echo -e "   - Backup command is:\n        ==>  bench --site ${SOURCE_HOST} backup --with-files > ${TMP_DIR}/${RPRT};";
  echo -e "     - Will archive database (${DB_NAME}) and files to ${FROM}";
  echo -e "     - Will write log result to ${TMP_DIR}/${RPRT}";

  echo -e "         started ...";
  bench --site ${SOURCE_HOST} backup --with-files > ${TMP_DIR}/${RPRT};
  echo -e "         ... done";

  echo -e "\n - Re-packaging database backup.";

  line=$(grep Config ${TMP_DIR}/${RPRT} | cut -d ' ' -f 4)
  # echo -e "\nline : ${line}"
  prefix="./${ERPNEXT_SITE_URL}/private/backups/"
  suffix="-site_config_backup.json"
  part=${line#"$prefix"}
  # echo -e "part : ${part}"
  BACKUP_FILE_UID=${part%"$suffix"}
  # echo -e "BACKUP_FILE_UID : ${BACKUP_FILE_UID}"

popd >/dev/null;

echo -e "   - Comment :: \"${COMMENT}\"";
echo -e "   - Source : ${FROM}";
echo -e "   - Dest : ${TO}";
echo -e "   - Name : ${BACKUP_FILE_UID}";

# tree -L 2 ${TARGET_BENCH}; 

# echo -e "${pYELLOW}----------------- handleBackup Curtailed --------------------------${pDFLT}";
# # ls -la;
# # hostname;
# pwd;
# exit;

pushd ${FROM} >/dev/null;
  echo -e "   - Compression command is:\n        ==>  tar zcvf ${TO}/${BACKUP_FILE_UID}.tgz ./${BACKUP_FILE_UID}*";
  echo -e "         started ...";
  tar zcvf ${TO}/${BACKUP_FILE_UID}.tgz ./${BACKUP_FILE_UID}* >/dev/null;
  rm -f ./${BACKUP_FILE_UID}*;
  echo -e "         ... done";
popd >/dev/null;

pushd ${TO} >/dev/null;
  # pwd;
  # ls -la
  echo -e "${BACKUP_FILE_UID}.tgz" > ProdBckup.txt;
  cp ProdBckup.txt BACKUP.txt;
  touch NotesForBackups.txt;
  echo -e "${COMMENT} :: ${BACKUP_FILE_UID}.tgz" >> NotesForBackups.txt;
  echo -e "\n - The 5 most recent logged repackaging results in '$(pwd)/${pGOLD}NotesForBackups.txt${pDFLT}' are :${pGOLD}";
  tail -n 5 NotesForBackups.txt;
popd >/dev/null;

seconds=$(($(date +'%s') - $start));


echo -e "\n\n${pGREEN}Backup process completed! Elapsed time, $(secs_to_human $seconds) seconds

${pDFLT}";
