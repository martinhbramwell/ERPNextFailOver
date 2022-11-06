#!/usr/bin/env bash
#
export SCRIPT_NAME=$(basename "$0");

export ENVIRONMENT_VARIABLES="/opt/ce_sri/envars.sh"
# ls -la ${ENVIRONMENT_VARIABLES};
source ${ENVIRONMENT_VARIABLES};

declare TARGET_HOST=${ERPNEXT_SITE_URL}
declare SITE_PATH="sites";
declare PRIVATE_PATH="${TARGET_HOST}/private";
declare BACKUPS_PATH="${PRIVATE_PATH}/backups";
declare FILES_PATH="${PRIVATE_PATH}/files";
declare BACKUPS_FILES_ABS_PATH="${TARGET_BENCH}/${SITE_PATH}/${BACKUPS_PATH}";

declare BACKUP_DIR="${TARGET_BENCH}/BKP";

declare TO="${BACKUP_DIR}"
declare FROM="${TARGET_BENCH}/${SITE_PATH}/${BACKUPS_PATH}";

# ls -la ${BACKUPS_FILES_ABS_PATH}

declare TMP_DIR="/dev/shm";
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

  echo -e "\n\n\n/* ~~~~~~~~  Backing up \"${COMMENT}\" ~~~~~~~~~ */";

  pushd sites/${SOURCE_HOST} >/dev/null;
    DB_NAME=$(jq -r .db_name site_config.json);
    pushd private/files >/dev/null;
      echo -e "  - Saving database views constructors to site private files directory. (db: ${DB_NAME})";
      mysql -AD ${DB_NAME} \
           --skip-column-names \
           --batch \
           -e 'select CONCAT("DROP TABLE IF EXISTS ", TABLE_NAME, "; CREATE OR REPLACE VIEW ", TABLE_NAME, " AS ", VIEW_DEFINITION, "; ") as ddl FROM information_schema.views WHERE table_schema = (SELECT database() FROM dual)' \
        > ddlViews.sql;
      # ls -la;
      # cat ddlViews.sql;
    popd >/dev/null;
  popd >/dev/null;

  mkdir -p ${BACKUP_DIR};
  
  
  echo -e "  - Archiving database (${DB_NAME}) and files to ${FROM}";
  echo -e "  - Directing log result to ${TMP_DIR}/${RPRT}";

  echo -e "  - Backup command is:\n    ==>   bench --site ${SOURCE_HOST} backup --with-files > ${TMP_DIR}/${RPRT};";
  bench --site ${SOURCE_HOST} backup --with-files > ${TMP_DIR}/${RPRT};

  echo -e "\n\n/* ~~~~~~~~  Re-packaging ~~~~~~~~~ */";

  line=$(grep Config ${TMP_DIR}/${RPRT} | cut -d ' ' -f 4)
  # echo -e "\nline : ${line}"
  prefix="./${ERPNEXT_SITE_URL}/private/backups/"
  suffix="-site_config_backup.json"
  part=${line#"$prefix"}
  # echo -e "part : ${part}"
  BACKUP_FILE_UID=${part%"$suffix"}
  # echo -e "BACKUP_FILE_UID : ${BACKUP_FILE_UID}"

popd >/dev/null;

echo -e "  - Comment :: \"${COMMENT}\"";
echo -e "  - Source : ${FROM}";
echo -e "  - Dest : ${TO}";
echo -e "  - Name : ${BACKUP_FILE_UID}";

# tree -L 2 ${TARGET_BENCH}; 


pushd ${FROM} >/dev/null;
  echo -e "  - Compression command is:\n    ==>   tar zcvf ${TO}/${BACKUP_FILE_UID}.tgz ./${BACKUP_FILE_UID}*";
  tar zcvf ${TO}/${BACKUP_FILE_UID}.tgz ./${BACKUP_FILE_UID}* >/dev/null;
  rm -f ./${BACKUP_FILE_UID}*;
popd >/dev/null;

pushd ${TO} >/dev/null;
  # pwd;
  # ls -la
  echo -e "${BACKUP_FILE_UID}.tgz" > ProdBckup.txt;
  cp ProdBckup.txt BACKUP.txt;
  echo -e "${COMMENT} :: ${BACKUP_FILE_UID}.tgz" >> NotesForBackups.txt;
  echo -e "\n\n/* ~~~~~~~~  Result ~~~~~~~~~ */";
  cat NotesForBackups.txt;
popd >/dev/null;

echo -e "/* ~~~~~~~~  Done ~~~~~~~~~ */\n\n";
