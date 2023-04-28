#!/usr/bin/env bash
#

abort() {
    echo >&2 '
***************
*** ABORTED ***
***************
'
    echo "An error occurred. Exiting..." >&2
    exit 1
}

trap 'abort' 0

export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source ${SCRIPT_DIR}/envars.sh;

set -e;

echo -e "trimLog.sh";

declare TMP_DIR="/dev/shm";

declare WORK_SCRIPT_NAME="copyBackUps.sh";

declare WORK_DIR="${TMP_DIR}/Work";
declare WORK_FILE_NAME="backUpsWork.log";
declare WORK_FILE="${WORK_DIR}/${WORK_FILE_NAME}";
declare WORK_SCRIPT="${WORK_DIR}/${WORK_SCRIPT_NAME}";

declare BKP_DIR="${TARGET_BENCH}/BKP";
declare BKP_FILE_NAME="NotesForBackups.txt";
declare BKP_LATEST_NAME="BACKUP.txt";
declare BKP_FILE="${BKP_DIR}/${BKP_FILE_NAME}";
declare BKP_LATEST="${BKP_DIR}/${BKP_LATEST_NAME}";

extractDate() {
    declare strDate=${1};
    local __rslt=${2}

    declare theDay=$(echo "${strDate}" | cut -c1-8)
    declare theHour=$(echo "${strDate}" | cut -c10-11)
    declare theMinute=$(echo "${strDate}" | cut -c12-13)
    declare theSecond=$(echo "${strDate}" | cut -c14-15)

    local fileTimeStamp=$(date -d "${theDay} ${theHour}:${theMinute}:${theSecond}" "+%s")
    eval $__rslt="'${fileTimeStamp}'"
}

processRequiredFile() {
  local backupRecord=${1};
  local backupFile=${backupRecord%%#*}
  echo -e "cp ${BKP_DIR}/${backupFile} ${WORK_DIR}" >> ${WORK_SCRIPT};
  echo -e "${backupRecord} ${2}" >> ${WORK_FILE};
}

secureRecentBackups() {
  declare workDate="${1}";
  declare limitEpoch=$(date --date="${workDate}" "+%s");
  echo -e "Securing recent ERPNext database backup files
      between  ${limitEpoch} ($(date --date="${workDate}" "+%B %d, %Y")) and now $(date "+%s")";

  BIFS=${IFS};
  IFS=$'\n'

  declare limit=4;
  declare counter=0;

  tac ${BKP_FILE} | while read backupRecord; do

    recordTimeStamp=${backupRecord%%-*}
    # echo "Record times stamp is : "${recordTimeStamp};
    extractDate "${recordTimeStamp}" recordEpoch;
    # echo -e "record epoch = ${recordEpoch} vs limit epoch = ${limitEpoch}";

    if [[ "${limitEpoch}" > "${recordEpoch}" ]]; then exit; fi;

    echo -e "Put aside back up: ${backupRecord}";
    processRequiredFile "${backupRecord}" "Back up";

    if [[ ${counter} -ge ${limit} ]]; then exit; fi;

    ((counter+=1))

  done;

  IFS=${BIFS};

  echo -e "\n..........................................\n\n";
}

secureRequiredOlderBackups() {
  declare workDate="${1}";
  echo "Trimming ERPNext database backup files before $(date --date="${workDate}" "+%B %d %Y").";

  BIFS=${IFS};
  IFS=$'\n'

  declare LAST_BKUP_NO="";
  declare LAST_DAY__NO="";
  declare LAST_WEEK_NO="";
  declare LAST_MNTH_NO="";
  declare LAST_YEAR_NO="";

  declare BKUP_NO="";
  declare DAY__NO="";
  declare WEEK_NO="";
  declare MNTH_NO="";
  declare YEAR_NO="";

  declare limit=10000;
  declare counter=0;
  # declare RECENT_BKUP=0;
  declare RECENT__DAY=0;
  declare RECENT_WEEK=0;
  declare RECENT_MNTH=0;
  declare RECENT_YEAR=0;

  declare limitEpoch=$(date --date="${workDate}" "+%s");

  tac ${BKP_FILE} | while read backupRecord; do
    recordTimeStamp=${backupRecord%%-*}
    # echo "Record times stamp is : "${recordTimeStamp};
    extractDate "${recordTimeStamp}" recordEpoch;
    # echo -e "record epoch = ${recordEpoch}";
    if [[ ${recordEpoch} -lt ${limitEpoch} ]]; then

      BKUP_NO=$(date --date="@${recordEpoch}" "+%H")
      DAY__NO=$(date --date="@${recordEpoch}" "+%w")
      WEEK_NO=$(date --date="@${recordEpoch}" "+%U")
      MNTH_NO=$(date --date="@${recordEpoch}" "+%m")
      YEAR_NO=$(date --date="@${recordEpoch}" "+%Y")

      if [[ ${counter} -eq 0 ]]; then
        LAST_BKUP_NO=${BKUP_NO}
        LAST_DAY__NO=${DAY__NO}
        LAST_WEEK_NO=${WEEK_NO}
        LAST_MNTH_NO=${MNTH_NO}
        LAST_YEAR_NO=${YEAR_NO}
      fi;

      echo -e "${YEAR_NO} ${MNTH_NO} ${WEEK_NO} ${DAY__NO} ${BKUP_NO} (${counter}/${limit})";

      if [[ "10#${YEAR_NO}" != "10#${LAST_YEAR_NO}" ]]; then
        echo -e "Year : ${YEAR_NO}/${LAST_YEAR_NO}  (${backupRecord})";
        processRequiredFile "${backupRecord}" "Year";
        RECENT_YEAR=1;
      else
        if [[ ${RECENT_YEAR} -lt 1 ]]; then
          if [[ "10#${MNTH_NO}" != "10#${LAST_MNTH_NO}" ]]; then
            echo -e "Month : ${MNTH_NO}/${LAST_MNTH_NO}  (${backupRecord})";
            processRequiredFile "${backupRecord}" "Month";
            RECENT_MNTH=1;
          else
            if [[ ${RECENT_MNTH} -lt 1 ]]; then
              if [[ "10#${WEEK_NO}" != "10#${LAST_WEEK_NO}" ]]; then
                echo -e "Week  : ${WEEK_NO}/${LAST_WEEK_NO}  (${backupRecord})";
                processRequiredFile "${backupRecord}" "Week";
                RECENT_WEEK=1;
              else
                if [[ ${RECENT_WEEK} -lt 1 ]]; then
                  if [[ "10#${DAY__NO}" != "10#${LAST_DAY__NO}" ]]; then
                    echo -e "Day  : ${DAY__NO}/${LAST_DAY__NO}  (${backupRecord})";
                    processRequiredFile "${backupRecord}" "Day";
                    RECENT__DAY=1;
                  else
                    if [[ ${RECENT__DAY} -lt 1 ]]; then
                      if [[ "10#${BKUP_NO}" != "10#${LAST_BKUP_NO}" ]]; then
                        echo -e "Back up  : ${BKUP_NO}/${LAST_BKUP_NO}  (${backupRecord})";
                        processRequiredFile "${backupRecord}" "Back up";
                        # RECENT_BKUP=1;
                      fi;
                    fi;
                  fi;
                fi;
              fi;
            fi;
          fi;
        fi;
      fi;

      LAST_BKUP_NO=${BKUP_NO}
      LAST_DAY__NO=${DAY__NO}
      LAST_WEEK_NO=${WEEK_NO}
      LAST_MNTH_NO=${MNTH_NO}
      LAST_YEAR_NO=${YEAR_NO}

      ((counter+=1));
      if [[ ${counter} -ge ${limit} ]]; then exit; fi;
    else
      echo "Record times stamp is : "${recordTimeStamp};
    fi;

  done;

  IFS=${BIFS};

  echo -e "\n..........................................\n\n";
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  declare workDate=$(date -d "-10 days" "+%A %B %d, %Y");

  if [ ! -f "${BKP_FILE}" ]; then
    echo "File \""${BKP_FILE}"\" does not exist";
    exit;
  fi

  echo -e "Trimming ....
  mkdir -p ${WORK_DIR};
  > ${WORK_FILE};
  > ${WORK_SCRIPT};
  chmod +x ${WORK_SCRIPT};
";
  
  mkdir -p ${WORK_DIR};
  > ${WORK_FILE};
  > ${WORK_SCRIPT};
  chmod +x ${WORK_SCRIPT};

  secureRecentBackups "${workDate}";

  secureRequiredOlderBackups "${workDate}";

  echo -e "Executing generated script '${WORK_SCRIPT}' to collect required backup files.";
  ${WORK_SCRIPT}

  echo -e "Replacing backup log file '${BKP_FILE}' with '${WORK_FILE}'";
  # tac ${WORK_FILE}
  echo -e "tac ${WORK_FILE} > ${BKP_FILE}";
  tac ${WORK_FILE} > ${BKP_FILE};
  # head -n 10 ${BKP_FILE};
  # echo -e "==========\n\n";

  echo -e "Deleting all backups in permanent directory...";
  rm -f ${BKP_DIR}/20*.tgz;

  echo -e "Copying require backups into permanent directory...";
  cp ${WORK_DIR}/20*.tgz ${BKP_DIR};

  echo -e "Noting most recent backup ...";
  tail -n 1 ${BKP_FILE} > ${BKP_LATEST};

fi;

trap : 0

echo >&2 '
************
*** DONE *** 
************
'
