#!/usr/bin/env bash
#

export start_time="$(date -u +%s)";

export DEBUGGING="debugging";
export pRED="\033[1;40;31m";
export pYELLOW="\033[1;40;33m";
export pGREEN="\033[1;40;32m";
export pDFLT="\033[0m";


echo -e "

${pGREEN}----------------------------- Starting -----------------------------------${pDFLT}";


declare PKG="xmlstarlet";
echo -e "Checking presence of '${PKG}' tool.";
if dpkg-query -l ${PKG} >/dev/null; then
  echo -e " - Found '${PKG}' already installed";
else
  echo -e "\n* * * Do you accept to install 'xmlstarlet' (  https://en.wikipedia.org/wiki/XMLStarlet ) * * * ";
  read  -n 1 -p "Type 'y' to approve, or any other key to quit :  " installOk
  if [ "${installOk}" == "y" ]; then
    echo -e "Ok."; 
    sudo -A apt install ${PKG};
    echo -e "\n - Installed '${PKG}'"
  else
    echo -e "\n\nOk. Cannot proceed.\n ${pRed}Quitting now. ${pDFLT}"; 
  fi
fi;

echo -e "";

export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

declare ENVARS="${SCRIPT_DIR}/envars.sh";

declare PREP_MSTR="${SCRIPT_DIR}/master/prepareMaster.sh";
declare PREP_SLV="${SCRIPT_DIR}/slave/prepareSlave.sh";
declare MAKE_MARIADB_RESTART_SCRIPT="${SCRIPT_DIR}/makeMariaDBRestartScript.sh";
declare MAKE_ASK_PASS_EMITTER="${SCRIPT_DIR}/makeAskPassEmitter.sh";

declare TMP_DIR="/dev/shm";
# declare CE_SRI_UTILS="apps/ce_sri/development/initialization";
declare MARIADB_CONFIG_DIR="/etc/mysql/mariadb.conf.d/";
declare MARIADB_CONFIG="50-server.cnf";

declare MSTR_WRK="M_work";
declare MSTR_RSLT="M_rslt";
declare MSTR_WRK_FILES="${MSTR_WRK}.tgz";
declare MSTR_WRK_DIR="${TMP_DIR}/${MSTR_WRK}";
declare MSTR_RSLT_DIR="${TMP_DIR}/${MSTR_RSLT}";
declare MSTR_RSLT_PKG="${MSTR_RSLT}.tgz";
declare MSTR_STATUS_RSLT="masterStatus.xml";

declare SLAV_WRK="S_work";
declare SLAV_RSLT="S_rslt";
declare SLAV_WRK_FILES="${SLAV_WRK}.tgz";
declare SLAV_WRK_DIR="${TMP_DIR}/${SLAV_WRK}";
declare SLAV_RSLT_DIR="${TMP_DIR}/${SLAV_RSLT}";
declare SLAV_RSLT_PKG="${SLAV_RSLT}.tgz";
declare SLAV_STATUS_RSLT="slaveStatus.xml";

declare MARIA_RST_SCRIPT="restartMariaDB.sh";
declare ASK_PASS_EMITTER=".supwd.sh";

mkdir -p ${MSTR_WRK_DIR};
rm -fr ${MSTR_WRK_DIR}/*;

mkdir -p ${SLAV_WRK_DIR};
rm -fr ${SLAV_WRK_DIR}/*;

[ -f ${ENVARS} ] || ERRORS="${ERRORS}\n  - Configuration file '${ENVARS}' was not found";

echo -e "Loading dependencies ..."
source ${ENVARS};
source ${PREP_MSTR};
source ${PREP_SLV};
source ${MAKE_MARIADB_RESTART_SCRIPT};
source ${MAKE_ASK_PASS_EMITTER};

export MASTER_IP_ADDR=${STR#${THST} has address }

[ ! -z ${MASTER_HOST_URL} ] || ERRORS="${ERRORS}\n  - Master host URL was not specified in '${ENVARS}'";
[ -f ${HOME}/.ssh/${MASTER_HOST_KEY} ] || ERRORS="${ERRORS}\n  - Master host PKI file '${HOME}/.ssh/${MASTER_HOST_KEY}' was not found";

[ ! -z ${SLAVE_HOST_URL} ] || ERRORS="${ERRORS}\n  - Slave host URL was not specified in '${ENVARS}'";
[ -f ${HOME}/.ssh/${SLAVE_HOST_KEY} ] || ERRORS="${ERRORS}\n  - Slave host PKI file '${HOME}/.ssh/${SLAVE_HOST_KEY}' was not found";


echo -e "\nWas host alias use specified?";
if [[  "${USE_HOST_ALIAS}" = "yes" ]]; then
    echo -e " - Using host aliases";
    export THE_MASTER="${MASTER_HOST_ALIAS}";
    export THE_SLAVE="${SLAVE_HOST_ALIAS}";
else
    echo -e " - Directly specifying hosts to ssh-agent";
    eval "$(ssh-agent -s)";

    echo -e "\n                                         Adding Master host PKI to agent";
    ssh-add "${HOME}/.ssh/${MASTER_HOST_KEY}";

    echo -e "\n                                         Adding Slave host PKI to agent";
    ssh-add "${HOME}/.ssh/${SLAVE_HOST_KEY}";

    export THE_MASTER=${MASTER_HOST_USR}@${MASTER_HOST_URL};
    export THE_SLAVE=${SLAVE_HOST_USR}@${SLAVE_HOST_URL};
fi;


if [[  "${TEST_CONNECTIVITY}" == "yes" ]]; then
  echo -e "\nTesting connectivity ...'";
  echo -e " - testing with command : 'ssh ${THE_MASTER} \"whoami\"'";
  [ "$(ssh ${THE_MASTER} \"whoami\")" == "${MASTER_HOST_USR}" ] || ERRORS="${ERRORS}\n  - Unable to get HOME directory of remote host '${THE_MASTER}'.";

  echo -e " - testing with command  : 'ssh ${THE_SLAVE} \"whoami\"'";
  [ "$(ssh ${THE_SLAVE} \"whoami\")" == "${SLAVE_HOST_USR}" ] || ERRORS="${ERRORS}\n  - Unable to get HOME directory of remote host '${THE_SLAVE}'.";
else
    echo -e "\n${pRED}* * * SKIPPED TESTING CONNECTIVITY * * * ${pDFLT}";
fi;

if [[ "${ERRORS}" != "${ERROR_MSG}" ]]; then
  echo -e "\n${ERRORS}\n\n${pRED}Cannot continue.\n~~~~~~~~~~~~~~~${pDFLT}";
  exit;
else
  echo -e "\n                                  No errors found";
  echo -e "                                    -- o 0 o --";
  echo -e "\n\nReady to prepare Master/Slave replication: "
  echo -e "  - Master: "
  echo -e "     - User: ${MASTER_HOST_USR}"
  echo -e "     - Host: $(host ${MASTER_HOST_URL})"
  echo -e "  - Slave: "
  echo -e "     - User: ${SLAVE_HOST_USR}"
  echo -e "     - Host: $(host ${SLAVE_HOST_URL})"
  echo -e ""
  if [[ -z ${1} ]]; then
    read -p "Press any key to proceed : "  -n1 -s;
    echo -e ""
    echo -e "|"
    echo -e "|"
    echo -e "V"
  fi;
fi;

declare -a HOSTS

HOSTS[0]="Master|${SLAVE_HOST_USR}|${MSTR_WRK_DIR}|${MASTER_HOST_URL}|${MASTER_HOST_PWD}";
HOSTS[1]="Slave|${MASTER_HOST_USR}|${SLAV_WRK_DIR}|${SLAVE_HOST_URL}|${SLAVE_HOST_PWD}";

echo -e "Making generic host-specific scripts";
for HOST in "${HOSTS[@]}"
do
  IFS="|" read -r -a arr <<< "${HOST}"

  ROL="${arr[0]}"

  echo -e " - For ${ROL}";
  USR="${arr[1]}"
  DIR="${arr[2]}"
  HST="${arr[3]}"
  APD="${arr[4]}"
  makeMariaDBRestartScript;
  makeAskPassEmitter;
done

echo -e "${pYELLOW}------------------------------ Curtailed ----------------------------------${pDFLT}
${SLAVE_DB_PWD}";
exit;

prepareMaster;

echo -e "${pYELLOW}------------- prepareMasterAndSlave Curtailed ---------------------${pDFLT}";
exit;

declare MASTER_OK="no";

pushd ${TMP_DIR} >/dev/null;
  # rm -fr ${MSTR_RSLT}*;
  echo -e "Downloading Master status file '${MSTR_RSLT_PKG}' to '$(pwd)'."
  scp ${THE_MASTER}:${TMP_DIR}/${MSTR_RSLT_PKG} . &>/dev/null;
  if [ $? -eq 0 ]; then
    tar zxvf ${MSTR_RSLT_PKG} >/dev/null;
    pushd ${MSTR_RSLT} >/dev/null;
      if [ $? -eq 0 ]; then
        xmlstarlet sel -t -v "//resultset/row" ${MSTR_STATUS_RSLT} >/dev/null;
        if [ $? -eq 0 ]; then
          MASTER_OK="yes"
          echo -e "\nReady to 'prepareSlave'";
          prepareSlave;
          
# echo -e "${pYELLOW}------------------------------ Curtailed ----------------------------------${pDFLT}";
# exit;

          ssh ${THE_SLAVE} ${SLAV_WRK_DIR}/${MARIA_RST_SCRIPT};
          sleep 5;
          ssh ${THE_MASTER} ${MSTR_WRK_DIR}/${MARIA_RST_SCRIPT};
        else
          echo -e "\n\n${pRED}* * * Expected Master status data was not found .... * * * ${pDFLT}"
          cat ${TMP_DIR}/${MSTR_STATUS_RSLT};
        fi;
      else
        echo -e "\n\n${pRED}* * * Unable to decompress Master results package file .... * * * ${pDFLT}"
      fi;
    popd >/dev/null;
  else
    echo -e "\n\n${pRED}* * * Expected result package could not be retrieved from Master * * * ${pDFLT}"
  fi;
popd >/dev/null;


if [ "${MASTER_OK}" == "yes" ]; then
  echo -e "${pGREEN}------------------------------ Finished ----------------------------------${pDFLT}";
else
  echo -e "\n\n${pRED}------------  Could not configure Slave.  Bad result from Master.  -------------------------${pDFLT}";
fi

# ls -la ${TMP_DIR}
# cat ${TMP_DIR}/50-server.cnf.patch;

exit;

for clbg in {40..47} {100..107} 49 ; do
  #Foreground
  for clfg in {30..37} {90..97} 39 ; do
    #Formatting
    for attr in 0 1 2 4 5 7 ; do
      #Print the result
      echo -en "\e[${attr};${clbg};${clfg}m ^[${attr};${clbg};${clfg}m \e[0m"
    done
    echo #Newline
  done
done
