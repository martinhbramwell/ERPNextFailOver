#!/usr/bin/env bash
#
# set -e;

WATCH_DIRECTORY=$1;
shift;

EVENT_TASK=$1;
shift;

IGNORE_PATHS="$@";

function listVariables() {
  echo -e "Variables ::
   WATCH_DIRECTORY = ${WATCH_DIRECTORY};
   EVENT_TASK = ${EVENT_TASK};
  ";
}

function doIt() {
  sleep 1;
  ${EVENT_TASK};
};

echo -e "\nros.sh -- Run On Save :  Executes the indicated command when any file is changed in the indicated directory.
Usage:   ./ros.sh . \"ls -la\";\n\n";

declare PKG="inotify-tools";

if ! dpkg-query -l ${PKG} &>/dev/null; then
  echo "Attempting to install '${PKG}'"
  if sudo apt -y install ${PKG} &>/dev/null; then
    echo -e "Hmmm.";
  else
    echo -e "Required repositories are not available.  Running 'apt-get update'";
    sudo apt-get update;
    echo "\n\nAgain attempting to install '${PKG}'\n"
    sudo apt -y install ${PKG};
    echo "\nInstalled '${PKG}'\n"
  fi;
fi;
declare PKG="tree";
dpkg-query -l ${PKG} &>/dev/null || sudo apt -y install ${PKG};

echo "Will execute : '${EVENT_TASK}'";
listVariables;

doIt;
while true #run indefinitely
do
  inotifywait -qqr -e close_write,move,create,delete ${IGNORE_PATHS} ${WATCH_DIRECTORY} && doIt;
done
