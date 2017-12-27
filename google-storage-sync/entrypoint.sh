#!/usr/bin/env bash

source ~/.bashrc

[ -z "${K8S_ENVIRONMENT}" ] && echo "missing K8S_ENVIRONMENT" && exit 1
[ -z "${GS_BUCKET_NAME}" ] && echo "missing GS_BUCKET_NAME" && exit 1

source switch_environment.sh "${K8S_ENVIRONMENT}"

echo "Checking the Google Storage Bucket GS_BUCKET_NAME=${GS_BUCKET_NAME}"
if ! gsutil ls -b gs://${GS_BUCKET_NAME}/; then
    echo "Bucket does not exist, will try to create"
    ! gsutil mb gs://${GS_BUCKET_NAME}/ && echo "Failed to create bucket" && exit 1
fi

if [ "${INITIAL_SYNC_SCRIPT}" != "" ]; then
    echo "Performing initial sync..."
    ! eval "${INITIAL_SYNC_SCRIPT}" && echo "Failed initial sync" && exit 1
fi

! [ -e /pipelines/data ] && echo "missing /pipelines/data directory, creating" && mkdir -p /pipelines/data

! touch /pipelines/data/synced && echo "failed to created /pipelines/data/synced" && exit 1

echo 'waiting for pipelines to complete, checking in intervals of 1 minute'
trap "echo 'caught SIGTERM, exiting ungracefully'; exit 1" SIGTERM;
trap "echo 'caught SIGINT, exiting ungracefully'; exit 1" SIGINT;
while ! [ -e /pipelines/data/done ]; do
    sleep 60
    echo .
done
rm -f /pipelines/data/done

echo "pipelines complete, syncing.."

! gsutil -m rsync $SYNC_ARGS -r /pipelines/data "gs://${GS_BUCKET_NAME}/${OUTPUT_PATH_PREFIX}`date +%Y-%m-%d-%H-%M`/" \
    && echo "gsutil rsync failed" && exit 1

echo "Great Success"
exit 0
