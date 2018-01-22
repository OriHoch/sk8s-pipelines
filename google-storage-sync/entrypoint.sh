#!/usr/bin/env bash

(
source ~/.bashrc

echo "GS_BUCKET_NAME=${GS_BUCKET_NAME}"
echo "CLOUDSDK_CORE_PROJECT=${CLOUDSDK_CORE_PROJECT}"

[ -z "${GS_BUCKET_NAME}" ] && echo "missing GS_BUCKET_NAME" && exit 1
[ -z "${CLOUDSDK_CORE_PROJECT}" ] && echo "missing CLOUDSDK_CORE_PROJECT" && exit 1

! gcloud config set project "${CLOUDSDK_CORE_PROJECT}" \
    && echo "failed to set gcloud project to ${CLOUDSDK_CORE_PROJECT}" && exit 1

if [ "${DISABLE_TIMESTAMP}" == "" ]; then
    TIMESTAMP_SUFFIX=`date +%Y-%m-%d-%H-%M`
else
    TIMESTAMP_SUFFIX=""
fi

SYNC_URL="gs://${GS_BUCKET_NAME}/${OUTPUT_PATH_PREFIX}${TIMESTAMP_SUFFIX}/"
METADATA_URL="gs://${GS_BUCKET_NAME}/${OUTPUT_PATH_PREFIX}metadata.env"

echo "SYNC_URL=${SYNC_URL}"
echo "METADATA_URL=${METADATA_URL}"

LAST_SYNC_URL=""
if gsutil ls "${METADATA_URL}"; then
    eval $(gsutil cat "${METADATA_URL}")
fi
echo "LAST_SYNC_URL=${LAST_SYNC_URL}"

METADATA_FILE=`mktemp`
echo "LAST_SYNC_URL=${SYNC_URL}" > "${METADATA_FILE}"
! gsutil cp "${METADATA_FILE}" "${METADATA_URL}.temp" && echo "failed to copy temp metadata to bucket ${GS_BUCKET_NAME}" && exit 1

if [ "${INITIAL_SYNC_SCRIPT}" != "" ]; then
    echo "Running initial sync..."
    ! eval "${INITIAL_SYNC_SCRIPT}" && echo "Failed initial sync" && exit 1
fi

DATA_PATH="${DATA_PATH:-/pipelines/data}"
STATE_PATH="${STATE_PATH:-${DATA_PATH}}"

! [ -e "${DATA_PATH}" ] && echo "missing "${DATA_PATH}" directory, creating" && mkdir -p "${DATA_PATH}"

! touch "${STATE_PATH}/synced" && echo "failed to created ${STATE_PATH}/synced" && exit 1

echo 'waiting for pipelines to complete'
trap "echo 'caught SIGTERM, exiting ungracefully'; exit 1" SIGTERM;
trap "echo 'caught SIGINT, exiting ungracefully'; exit 1" SIGINT;
while ! [ -e "${STATE_PATH}/done" ]; do
    sleep 5
    echo .
done
rm -f "${STATE_PATH}/done"

echo "pipelines complete, syncing to ${SYNC_URL}"

! gsutil -m rsync -x '^done|synced$' $SYNC_ARGS -r "${DATA_PATH}" "${SYNC_URL}" \
    && echo "gsutil rsync failed" && exit 1

! gsutil cp "${METADATA_FILE}" "${METADATA_URL}" && echo "failed to copy metadata to bucket ${GS_BUCKET_NAME}" && exit 1

echo
echo "Great Success"
echo
echo "https://console.cloud.google.com/storage/browser/${SYNC_URL}?project=${CLOUDSDK_CORE_PROJECT}"
echo
exit 0
)
RES=$?

if [ "${DELAY_EXIT_SECONDS}" == "" ]; then
    exit $RES
else
    echo "RES=${RES}"
    echo "sleeping ${DELAY_EXIT_SECONDS} seconds"
    sleep "${DELAY_EXIT_SECONDS}"
    rm -rf "${STATE_PATH}/*"
    rm -rf "${DATA_PATH}/*"
    touch "${STATE_PATH}/exit"
    exit $RES
fi
