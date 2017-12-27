# sk8s-pipelines

simplify usage of [datapackage pipelines](https://github.com/frictionlessdata/datapackage-pipelines) based scripts from [sk8s](https://github.com/orihoch/sk8s) environments

Provides a template project for pipelines based jobs which can run as kubernetes jobs or scheduled jobs

Pipelines code is based on saving to / loading from local filesystem. Kubernetes sync container handles syncing to google storage.

Docker images:

* `orihoch/sk8sops:pipelines-google-storage-sync` - sk8s environment ops container which syncs to/from google storage, see [google-storage-sync/README.md](google-storage-sync/README.md)


## Running the local pipelines code

Install some dependencies (the following should work on recent versions of Ubuntu / Debian)

```
sudo apt-get install -y python3.6 python3-pip python3.6-dev libleveldb-dev libleveldb1v5
sudo pip3 install pipenv
```

Install the app depepdencies

```
pipenv install
```

Activate the virtualenv

```
pipenv shell
```

Get the list of available pipelines

```
dpp
```

Run a pipeline

```
dpp run <PIPELINE_ID>
```
