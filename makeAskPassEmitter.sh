#!/usr/bin/env bash
#

export SCRIPT_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )";
export SCRIPT_NAME=$( basename ${0#-} );
export THIS_SCRIPT=$( basename ${BASH_SOURCE} )

function makeAskPassEmitter () {
  echo -e "    - Making password emitter script :: ${DIR}/${ASK_PASS_EMITTER}"

  cat << EOFMRS > ${DIR}/${ASK_PASS_EMITTER}
#!/usr/bin/env bash
echo '${APD}';
EOFMRS
sudo -A chmod +x ${DIR}/${ASK_PASS_EMITTER};

# cat ${DIR}/${ASK_PASS_EMITTER};

}

if [[ ${SCRIPT_NAME} = ${THIS_SCRIPT} ]] ; then
  makeAskPassEmitter;

  ls -la ${TMP_DIR}
else
  echo " - Sourced '${THIS_SCRIPT}' from '${SCRIPT_NAME}'"
fi;
