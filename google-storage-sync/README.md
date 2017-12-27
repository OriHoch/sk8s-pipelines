# Sync pipelines data to/from Google Storage

## Quickstart

This image extends the [sk8s-ops]() image and supports sync of pipelines data to/from google storage

It requires some specific configuration and files, assuming you have a sk8s repository in a sibling directory, something like this will work:

```
docker build -t sk8s-pipelines-google-storage-sync google-storage-sync &&\
docker run -it -v "`readlink -f ../project-k8s-repo/secret-k8s-ops.json`:/k8s-ops/secret.json" \
               -e K8S_ENVIRONMENT=staging \
               -e OPS_REPO_SLUG=project/k8s-repo-slug \
               -e OPS_REPO_BRANCH=master \
               -e GS_BUCKET_NAME=bucket-name \
               -e OUTPUT_PATH_PREFIX=testing-123 \
               sk8s-pipelines-google-storage-sync
```
