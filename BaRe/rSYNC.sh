source ../envars.sh;

export TARGET_DIR="/home/${ERP_USER_NAME}/${TARGET_BENCH_NAME}/BaRe";

if [[ -z ${1} ]]; then
  echo -e "Usage: ./rSync y"
  echo -e "Will synchronize this directory with :: ${SERVER}:${TARGET_DIR}";
  exit;
else
  echo -e "Synching this directory with :: ${SERVER}:${TARGET_DIR}";
fi;

declare PKG="inotify-tools";
dpkg-query -l ${PKG} &>/dev/null || sudo -A apt -y install ${PKG};
declare PKG="tree";
dpkg-query -l ${PKG} &>/dev/null || sudo -A apt -y install ${PKG};

ssh -t ${SERVER} "mkdir -p ${TARGET_DIR}";
echo -e "Target prepared. Synching has begun.";
while inotifywait -qqr -e close_write,move,create,delete ./*; do
  rsync -avx . ${SERVER}:${TARGET_DIR};
done;


# ./projects/ce_sri/ros.sh ./projects/ce_sri "./doIt.sh prepareServer_2.sh";
