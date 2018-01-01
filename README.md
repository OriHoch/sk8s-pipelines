# sk8s-pipelines

Scalable pipelines processing and infrastructure management.


## Features

* Scalable pipeline processing using [datapackage pipelines](https://github.com/frictionlessdata/datapackage-pipelines).
* Infrastructure management using [Kubernetes](https://kubernetes.io/).


## Using the pipelines

Please refer to the [datapackage pipelines documentation](https://github.com/frictionlessdata/datapackage-pipelines) for full documentation of the pipelines.

This project contains a sample pipeline called `noise` - which generates some noise.

The pipelines are defined in the `pipeline-spec.yaml` file. Each step's `run` attribute can point to a local python file implementing the datapackage pipelines processor interface, see `noise.py` for an example.


## Running the pipelines using docker

Install recent version of [Docker](https://docs.docker.com/engine/installation/) and [Docker Compose](https://docs.docker.com/compose/install/).

List available pipelines

`docker-compose run pipelines`

Run a pipeline

`docker-compose run pipelines run <PIPELINE_ID>`

Data is available locally under `data` directory


## Running the pipelines locally

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


## Running the pipelines on a Kubernetes cluster

Run the pipelines using [Kubernetes jobs](https://kubernetes.io/docs/concepts/workloads/controllers/jobs-run-to-completion/).

### Prerequisites

* Terminal with `kubectl` command authenticated to a Kubernetes cluster. You should have some running nodes (verify using `kubectl get nodes`).
*

### Write the job specification

The following example job configurations are available, you can use them and modify according to your requirements

* `k8s-job.yaml` - simple job, running once to completion
* `k8s-scheduled-job.yaml` - scheduled job, running daily, before each run - syncs latest data generated from the job defined in `k8s-job.yaml`

Run the job:

```
kubecyl apply -f k8s-job.yaml
```

To modify the job and re-run, delete the old job first

```
kubectl delete job <JOB_NAME>
kubectl delete cronjob <CRON_JOB_NAME>
```
