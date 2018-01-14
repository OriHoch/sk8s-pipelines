# Sync pipelines data to/from Google Storage

This image supports sync of data to/from google storage using a google service account.


Docker Images:
* `docker pull gcr.io/uumpa-public/sk8s-google-storage-sync-latest`
* `docker pull gcr.io/uumpa-public/sk8s-google-storage-sync:<COMMIT_SHA_OR_TAG_NAME>`


## Prerequisites

* Google Service Account secret json key, see [Creating a new service account with full permissions and related key file](https://github.com/OriHoch/sk8s-ops#creating-a-new-service-account-with-full-permissions-and-related-key-file)
* Google Project ID which the service account has the required permissoins for.
* Existing Google Storage bucket which the service account has permissions for.

Make sure the service account has the right permissions to the storage bucket.

It's easiest to create the bucket and give all required permissions to the service account using the Web UI.


## run the docker containers

Following should run from a pipelines repository root directory.

Sync from google storage to `data`, then wait for pipelines to run:

```
docker run -it -v "`readlink -f data`:/pipelines/data" \
               -v "`readlink -f secret-k8s-ops.json`:/k8s-ops/secret.json" \
               -e CLOUDSDK_CORE_PROJECT=uumpa123 \
               -e GS_BUCKET_NAME=sk8s-pipelines \
               -e OUTPUT_PATH_PREFIX="tests/" \
               orihoch/sk8sops:pipelines-gcs
```

You can do an initial sync from an existing google storage bucket before running the pipelines, add the following argument:

```
               -e INITIAL_SYNC_SCRIPT="gsutil -m rsync -x '^done|synced$' -r gs://sk8s-pipelines/tests/2017-12-31-19-51/ /pipelines/data/"
```

The google storage sync container will start and wait for pipelines to run

Open another terminal and run the pipelines

```
docker run -it -v "`readlink -f data`:/pipelines/data" --entrypoint "bash" orihoch/sk8s-pipelines -c "
            while ! [ -e /pipelines/data/synced ]; do sleep 5 && echo .; done &&
            rm -f /pipelines/data/synced &&
            dpp run ./noise && touch /pipelines/data/done"
```

The pipelines container waits for the initial sync and the notifies the sync container the pipelines finished running

when the pipelines finish running the sync container is notified via /pipelines/data/done file

the sync container syncs the data directory to google storage.

Both containers exit successfully.

The metadata.env file is a .env format file with metadata about the pipeline run

```
gsutil cat gs://sk8s-pipelines/tests/metadata.env
```

It contains the url to the latest pipeline data output url

```
gsutil du gs://sk8s-pipelines/tests/2018-01-01-10-45/
```


## Building the google storage sync container

The sync container doesn't change much, so you shouldn't need to build it yourself, but if you want to:

```
docker build -t orihoch/sk8sops:pipelines-gcs google-storage-sync
docker push orihoch/sk8sops:pipelines-gcs
```
