# sk8s-pipelines

## Running

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
