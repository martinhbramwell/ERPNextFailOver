#!/usr/bin/env bash
#
export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source ${SCRIPT_DIR}/envars.sh;

declare IS_CRON="";
if [[ ! -z ${1} ]]; then IS_CRON="${1}"; fi;

debug() {
    if [ "${IS_CRON}" == "RunFromCron" ]; then return; fi;
    echo -e "${1}";
}


START_DATE="2022-01-01 01:01:30";
# START_DATE="2020-01-01 01:01:30";
toDate=$(date -d "${START_DATE}" +%s)

END_DATE=$(date);
endDate=$(date -d "${END_DATE}" +%s)
debug "endDate = ${endDate}";
# echo -e "endDate = ${endDate}";

declare bkupsDirectory="${TARGET_BENCH}/BKP";
declare bkupsLogFile="${bkupsDirectory}/NotesForBackups.txt";
declare debugMode=True;

# writeToLog() {
#     declare report=$(date --date="@${1}" "+%Y%m%d_%H%M%S-${ERPNEXT_SITE_URL}.tgz # %I %p %Z, %A %B %d, %Y")
#     debug "${report}" >>  ${bkupsLogFile};
# }

# writeTgz() {
#     local theTimeStamp=${1}
#     local tgz=$(date --date="@${theTimeStamp}" "+%Y%m%d_%H%M%S-${ERPNEXT_SITE_URL}.tgz")
#     local dtsttmp=$(date --date="@${theTimeStamp}");
#     # debug "dtsttmp = ${dtsttmp}";
#     touch -d "${dtsttmp}" ${bkupsDirectory}/${tgz}
# }

declare firstHourOfDay=8;
declare lastHourOfDay=21;
declare lastDayOfWeek=5;

declare Comment="";
declare cntr=0
declare delta=2
declare incr="hour"

declare theTimeStamp="";
declare Hour="";
declare DoW="";
declare Comment="";
processEvent() {
    local theTimeStamp=${1};
    # debug "${theTimeStamp}";
    Hour=$(date --date="@${theTimeStamp}" "+%H");
    DoW=$(date --date="@${theTimeStamp}" "+%u");

    when=$(date --date="@${theTimeStamp}" "+%Y-%m-%d %R %Z");
    if   (( 10#${Hour} < ${firstHourOfDay})); then
        debug "Skipped cron job. Too early : ${when}";
    elif (( 10#${Hour} > ${lastHourOfDay})); then
        debug "Skipped cron job. Too late : ${when}";
    elif (( 10#${DoW} > ${lastDayOfWeek})); then
        debug "Skipped cron job. Weekend : ${when}";
    else
        # local Comment=$(date --date="@${1}" "+%Y%m%d_%H%M%S-${ERPNEXT_SITE_URL}.tgz # %I %p %Z, %A %B %d, %Y")
        local Comment=$(date --date="@${1}" "+# %I %p %Z, %A %B %d, %Y")
        debug "Doing cron job.\nLog record: ${Comment}";
        ${SCRIPT_DIR}/handleBackup.sh "${Comment}" &>/dev/null;
        # ${SCRIPT_DIR}/handleBackup.sh "${Comment}";
        # writeToLog "${theTimeStamp}";
        # writeTgz "${theTimeStamp}";
    fi;
}

purgeLog() {
    # cat ${bkupsLogFile};
    > ${bkupsLogFile};
}

createTestRecords() {
    local START_DATE=${1};
    local endDate=$(date -d "${2}" "+%s");
    pushd ${SCRIPT_DIR} >/dev/null;
        purgeLog;
        # debug "${START_DATE} ${cntr} ${incr}";
        local toDate=$(date -d "${START_DATE} ${cntr} ${incr}" "+%s")
        # debug "toDate = ${toDate}";
        # debug "endDate = ${endDate}";
        until [ ${toDate} -ge ${endDate} ]; do
            toDate=$(date -d "${START_DATE} ${cntr} ${incr}" +%s)
            processEvent ${toDate};
            cntr=$((${delta}+${cntr}))
        done
    popd >/dev/null;
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    debug "Cron job started......";

    TZ="America/Guayaquil"
    # Get the current time in the zone
    zone=$(TZ=${TZ} date "+%Y%m%d %R")
    zone_time=$(date -d "${zone}" "+%s")
    debug "Zone '${TZ}' time is ${zone_time}";
    processEvent ${zone_time};


    # SD=$(date --date="${START_DATE}" "+Start date: %Y-%m-%d %R %Z (%A %B %d, %Y)");
    # ED=$(date --date="${END_DATE}"   "+  End date: %Y-%m-%d %R %Z (%A %B %d, %Y)");
    # debug "\n${SD}\n${ED}";
    # createTestRecords "${START_DATE}" "${END_DATE}";

    debug "Cron job terminated\n\n";
fi;

