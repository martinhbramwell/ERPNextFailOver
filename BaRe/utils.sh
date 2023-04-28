export start=$(date +'%s');
export seconds=

secs_to_human() {
    echo "$(( ${1} / 3600 ))h $(( (${1} / 60) % 60 ))m $(( ${1} % 60 ))s"
}


export pRED="\033[1;40;31m";
export pYELLOW="\033[1;40;33m";
export pGOLD="\033[0;40;33m";
export pFAINT_BLUE="\033[0;49;34m";
export pGREEN="\033[1;40;32m";
export pDFLT="\033[0m";
export pBG_YLO="\033[1;43;33m";

export ENVARS="envars.sh";
export ENVIRONMENT_VARIABLES="${CURR_SCRIPT_DIR}/${ENVARS}";

if [[ -L ${ENVIRONMENT_VARIABLES} ]]; then
  if [[ -e ${ENVIRONMENT_VARIABLES} ]]; then
    echo -e "\n\n${pGREEN}Loading environment variables from '${ENVIRONMENT_VARIABLES}'${pDFLT}";
    source ${ENVIRONMENT_VARIABLES};
  else 
    echo -e "${pRED} The local symlink '${ENVIRONMENT_VARIABLES}' to a file of environment variables is broken. Cannot proceed.${pDFLT}";
    exit 1;
  fi;
else 
  echo -e "${pRED} A required symlink '${ENVIRONMENT_VARIABLES}' to a file of environment variables was not found. Cannot proceed.${pDFLT}";
  exit 1;
fi;

declare TARGET_HOST=${ERPNEXT_SITE_URL};

declare SITES="sites";
declare SITE_PATH="${SITES}/${TARGET_HOST}";
declare PRIVATE_PATH="${SITE_PATH}/private";
declare BACKUPS_PATH="${PRIVATE_PATH}/backups";
declare FILES_PATH="${PRIVATE_PATH}/files";

declare TMP_DIR="/dev/shm";

declare BACKUP_DIR="${TARGET_BENCH}/BKP";

declare SITE_CONFIG="site_config.json";
