#!/usr/bin/env bash
#
export SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )";
export SCRIPT_NAME=$(basename "$0");

export REMOTE_PROJECT_DIR="returnable";

source ../envars.sh;

declare SLAVE_HOST_ALIAS=${SERVER};
declare SLAVE_HOST_USR=${ERP_USER_NAME};
declare SLAVE_BENCH_NAME=${TARGET_BENCH_NAME};

export REMOTE_PROJECT="${SLAVE_HOST_ALIAS}:/home/${SLAVE_HOST_USR}/${SLAVE_BENCH_NAME}/BaRe";


if [[ -z ${1} ]]; then
  echo -e "Usage: ./rSync y"
  echo -e "Will synchronize this directory '$(pwd)' with :: ${REMOTE_PROJECT}";
  exit;
else
  echo -e "Synching this directory '$(pwd)' with remote directory :: ${REMOTE_PROJECT}";
fi;

while inotifywait -qqr -e close_write,move,create,delete ./*; do
  rsync -rzavx --update . ${REMOTE_PROJECT};
done;

  # echo -e "\n\n/* ~~~~~~~~~ Curtailed ~~~~~~~ ${SCRIPT_DIR}/${SCRIPT_NAME} ~~~~~~~~ */

  # ";
  # exit;
