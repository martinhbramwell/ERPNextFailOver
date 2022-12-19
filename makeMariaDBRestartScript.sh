#!/usr/bin/env bash
#

export SCRIPT_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )";
export SCRIPT_NAME=$( basename ${0#-} );
export THIS_SCRIPT=$( basename ${BASH_SOURCE} )

function makeMariaDBRestartScript () {
  echo -e "    - Making MariaDB restart script :: ${DIR}/${MARIA_RST_SCRIPT}"

  cat << EOFMRS > ${DIR}/${MARIA_RST_SCRIPT}
#!/usr/bin/env bash
#
echo -e "${pYELLOW} - Restarting MariaDB for user '${USR}' on ${ROL} host '${HST}' ${pDFLT}";
export SUDO_ASKPASS=${DIR}/.supwd.sh;

sudo -A systemctl restart mariadb;
sudo -A systemctl status mariadb | grep "Active: ";
EOFMRS
sudo -A chmod +x ${DIR}/${MARIA_RST_SCRIPT};

# cat ${DIR}/${MARIA_RST_SCRIPT};

}

if [[ ${SCRIPT_NAME} = ${THIS_SCRIPT} ]] ; then
  makeMariaDBRestartScript;

  ls -la ${TMP_DIR}
else
  echo " - Sourced '${THIS_SCRIPT}' from '${SCRIPT_NAME}'"
fi;
