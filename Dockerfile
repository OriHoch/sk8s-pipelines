FROM frictionlessdata/datapackage-pipelines

RUN pip install --no-cache-dir pipenv pew
RUN apk --update --no-cache add build-base python3-dev bash jq libxml2 libxml2-dev git libxslt libxslt-dev

COPY Pipfile /pipelines/
COPY Pipfile.lock /pipelines/
RUN pipenv install --system --deploy --ignore-pipfile && pipenv check

#COPY setup.py /pipelines/
#RUN pip install -e .

# temporary fix for dpp not returning correct exit code
# TODO: remove once this PR is merged: https://github.com/frictionlessdata/datapackage-pipelines/pull/107
RUN pip install --upgrade https://github.com/OriHoch/datapackage-pipelines/archive/fix-exit-code.zip

COPY pipeline-spec.yaml /pipelines
COPY noise.py /pipelines
