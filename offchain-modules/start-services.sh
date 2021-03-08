#!/usr/bin/env bash
# start ckb and eth relayers
# `bash start-services.sh` run relayers on docker-dev-chain
# `bash start-services.sh -n <customed-network>` run relayers on customed network

set -o errexit
set -o xtrace

export RUST_BACKTRACE=1
export RUST_LOG=info,force=debug

PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && cd .. && pwd )"
FORCE_CLI=${PROJECT_DIR}/offchain-modules/target/debug/force-eth-cli
FORCE_LOG_PATH=~/.force-bridge/logs
DB_NAME=forcedb
DB_PATH=mysql://root:root@127.0.0.1:3306/${DB_NAME}
mkdir -p "${FORCE_LOG_PATH}"

while [[ $# -gt 0 ]]
do
key="$1"
case $key in
  -n|--network)
    FORCE_NETWORK="$2"
    shift # past argument
    shift # past value
    ;;
  *)
    echo "unknown argument"
    shift # past argument
    ;;
esac
done

cd ${PROJECT_DIR}/offchain-modules

if [ "${FORCE_NETWORK}" = "" ]
then
#  ${FORCE_CLI} init-ckb-light-contract -k 0 -f 500 -c 40000 --wait
  ${FORCE_CLI} ckb-relay -k 1 --per-amount 5  --max-tx-count 10 --mutlisig-privkeys  0 > ${FORCE_LOG_PATH}/ckb-relayer.log 2>&1 &
#  ${FORCE_CLI} init-multi-sign-address -k 1 --multi-address  ckt1qyqyph8v9mclls35p6snlaxajeca97tc062sa5gahk ckt1qyqvsv5240xeh85wvnau2eky8pwrhh4jr8ts8vyj37
  ${FORCE_CLI} eth-relay -k 1 --multisig-privkeys 0 1 > ${FORCE_LOG_PATH}/eth-relayer.log 2>&1 &
else
#  ${FORCE_CLI} init-ckb-light-contract --network "${FORCE_NETWORK}" -k 0 -f 500 -c 40000 --wait
  ${FORCE_CLI} ckb-relay --network "${FORCE_NETWORK}" -k 1 --per-amount 5  --max-tx-count 10 -mutlisig-privkeys  0 > ${FORCE_LOG_PATH}/ckb-relayer.log 2>&1 &
#  ${FORCE_CLI} init-multi-sign-address --network "${FORCE_NETWORK}" -k 1 --multi-address  ckt1qyqyph8v9mclls35p6snlaxajeca97tc062sa5gahk ckt1qyqvsv5240xeh85wvnau2eky8pwrhh4jr8ts8vyj37
  ${FORCE_CLI} eth-relay --network "${FORCE_NETWORK}" -k 1 > ${FORCE_LOG_PATH}/eth-relayer.log 2>&1 &
fi

${FORCE_CLI} dapp ckb-indexer --db-path ${DB_PATH} > ${FORCE_LOG_PATH}/ckb-indexer.log 2>&1 &
${FORCE_CLI} dapp eth-indexer --db-path ${DB_PATH} > ${FORCE_LOG_PATH}/eth-indexer.log 2>&1 &
