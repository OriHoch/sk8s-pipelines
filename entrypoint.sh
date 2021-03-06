#!/usr/bin/env bash

[ -z "${PIPELINES_SCRIPT}" ] && echo "missing PIPELINES_SCRIPT" && exit 1

if ! [ -z "${METRICS_HOST}" ] && ! [ -z ${METRICS_DB} ]; then
    echo "initializing metrics METRICS_HOST=${METRICS_HOST} METRICS_DB=${METRICS_DB}"
    curl -si -XPOST "${METRICS_HOST}/query" --data-urlencode "q=CREATE DATABASE ${METRICS_DB}" >/dev/null
else
    echo "metrics disabled, missing required env vars: METRICS_HOST METRICS_DB"
fi

STATE_PATH="${STATE_PATH:-/state}"
mkdir -p "${STATE_PATH}" >/dev/null 2>&1

send_metric(){
    echo "$@"
    if ! [ -z "${METRICS_HOST}" ] && ! [ -z ${METRICS_DB} ]; then
        curl -si -XPOST "${METRICS_HOST}/write?db=${METRICS_DB}" --data-binary \
                        "${1}${METRICS_TAGS_PREFIX:-,pipeline=}${2:-_} ${3:-value=1}" >/dev/null
    fi
}

run_pipeline() {
    PIPELINE_ID="${1}"
    PIPELINE_METRIC_ID="${PIPELINE_ID:-$2}"
    send_metric pipeline_running "${PIPELINE_METRIC_ID}" &
    if dpp run "${PIPELINE_ID}"; then
        send_metric pipeline_complete "${PIPELINE_METRIC_ID}" &
        return 0
    else
        send_metric pipeline_error "${PIPELINE_METRIC_ID}" &
        return 1
    fi
}

if [ "${INITIAL_SYNC_STATE_FILENAME}" != "" ]; then
    send_metric wait_for_initial_sync &
    while ! [ -e "${STATE_PATH}/${INITIAL_SYNC_STATE_FILENAME}" ]; do
        sleep ${INITIAL_SYNC_STATE_RETRY_INTERVAL_SECONDS:-5}
        echo .
    done
    send_metric initial_sync_complete &
fi

cd /pipelines

if [ "${ENABLE_SERVE}" != "0" ]; then
    send_metric start_serve &
    dpp init
    dpp serve &
fi

send_metric running &
eval "${PIPELINES_SCRIPT}"
RES=$?
if [ "${RES}" == "0" ]; then
    send_metric success &
else
    send_metric failure &
fi
if [ "${DONE_STATE_FILENAME}" != "" ]; then
    echo "Creating done state filename with exit code ${RES}"
    echo "${RES}" > "${STATE_PATH}/${DONE_STATE_FILENAME}"
fi
if [ "${EXIT_STATE_FILENAME}" != "" ]; then
    send_metric wait_for_exit &
    while ! [ -e "${STATE_PATH}/${EXIT_STATE_FILENAME}" ]; do
        sleep ${EXIT_STATE_RETRY_INTERVAL_SECONDS:-60}
    done
    rm -f "${STATE_PATH}/${EXIT_STATE_FILENAME}" >/dev/null 2>&1
fi
# wait 1 second to let metrics get sent (they are sent asynchroneously)
sleep 1
exit $RES
