import logging, sys, os, json, uuid
from datapackage_pipelines.wrapper import ingest, spew
from datapackage_pipelines.utilities.resources import PROP_STREAMING


CLI_MODE = len(sys.argv) > 1 and sys.argv[1] == '--cli'
if CLI_MODE:
    logging.basicConfig(format='%(levelname)s:%(message)s', level=logging.DEBUG)
    logging.debug("CLI MODE!")
    parameters, datapackage, resources = {}, {}, []
else:
    parameters, datapackage, resources = ingest()


default_parameters = {"num-rows": int(os.environ.get("NUM_ROWS", "10"))}
parameters = dict(default_parameters, **parameters)
logging.info(parameters)
stats = {}
aggregations = {"stats": stats}


def get_resource():
    for i in range(0, parameters["num-rows"]):
        yield {"uuid": str(uuid.uuid1()), "row_num": i}


if CLI_MODE:
    for row in get_resource():
        print(row)
else:
    resource_descriptor = {PROP_STREAMING: True,
                           "name": "noise",
                           "path": "noise.csv",
                           "schema": {"fields": [{"name": "uuid", "type": "string"},
                                                 {"name": "row_num", "type": "integer"}],
                                      "primaryKey": ["uuid"]}}
    spew(dict(datapackage, resources=[resource_descriptor]),
         [get_resource()], aggregations["stats"])
