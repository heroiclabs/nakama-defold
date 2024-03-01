#!/usr/bin/env python

import re
import pystache
import codecs

import zipfile
import os
import sys
import shutil
import fnmatch
import json


def render(data, templatefile, outfile):
    with open(templatefile, 'r') as f:
        template = f.read()
        result = pystache.render(template, data)
        with codecs.open(outfile, "wb", encoding="utf-8") as f:
            f.write(result)
            # f.write(html.unescape(result))

# https://stackoverflow.com/a/1176023/1266551
def camel_to_snake(name):
    name = re.sub('(.)([A-Z][a-z]+)', r'\1_\2', name)
    name = re.sub('([a-z0-9])([A-Z])', r'\1_\2', name).lower()
    return name.replace("__", "_")


def read_as_json(filename):
    with open(filename) as f:
        return json.load(f)


api = read_as_json("satori.swagger.json")
# print(api)

def expand_ref(api, data):
    if "$ref" in data:
        ref = data["$ref"].replace("#/definitions/", "")
        data["ref"] = camel_to_snake(ref)
        definition = api["definitions"].get(ref)
        for k in definition.keys():
            data[k] = definition[k]

def expand_object(api, o):
    if "type" in o and o["type"] == "array":
        items = o["items"]
        expand_ref(api, items)
    elif "schema" in o:
        schema = o["schema"]
        expand_ref(api, schema)
    else:
        expand_ref(api, o)

def fix_responses(api, o):
    fixed = []
    responses = o["responses"]
    for code in responses.keys():
        response = responses[code]
        if code != "default":
            response["code"] = code

        expand_object(api, response)
        
        fixed.append(response)
    o["responses"] = fixed

def fix_parameters(api, o):
    has_parameters = "parameters" in o
    o["has_parameters"] = has_parameters
    if not has_parameters:
        return

    names = []
    parameters = o["parameters"]
    for parameter in parameters:
        names.append(parameter["name"])
        # body, query or path
        parameter[parameter["in"]] = True
        print("param", parameter["in"])
        if parameter["in"] == "body":
            o["has_body_parameters"] = True
        elif parameter["in"] == "query":
            o["has_query_parameters"] = True
        elif parameter["in"] == "path":
            print("has path parameter")
            o["has_path_parameters"] = True
        # expand parameter and merge the schema reference into the parameter
        expand_object(api, parameter)
        if "schema" in parameter:
            schema = parameter["schema"]
            for k in schema.keys():
                if k != "name":
                    parameter[k] = schema[k]
            if "ref" in schema:
                parameter["type"] = schema["ref"]
    o["parameter_names"] = ", ".join(names)

def fix_paths(api):
    fixed = []
    paths = api["paths"]
    for path in paths.keys():
        endpoint = paths[path]
        for method in endpoint.keys():
            print(method.upper(), path)
            endpoint[method]["path"] = path
            endpoint[method]["operationId"] = camel_to_snake(endpoint[method]["operationId"]).replace("satori_", "")
            endpoint[method]["postdata"] = (method == "post") or (method == "put") or (method == "delete")
            endpoint[method]["method"] = method.upper()
            fix_responses(api, endpoint[method])
            fix_parameters(api, endpoint[method])
            fixed.append(endpoint[method])
    api["paths"] = fixed

def fix_definitions(api):
    definitionslist = []
    definitions = api["definitions"]
    for name in definitions.keys():
        print("definition", name)
        definition = definitions[name]
        definition["name"] = camel_to_snake(name)
        properties = definition["properties"]
        propertieslist = []
        for prop_name in properties.keys():
            prop = properties[prop_name]
            prop["name"] = prop_name
            expand_object(api, prop)
            if "ref" in prop:
                prop["type"] = prop["ref"]
            propertieslist.append(prop)
        definition["properties"] = propertieslist
        definitionslist.append(definition)
    api["definitionslist"] = definitionslist


fix_definitions(api)
fix_paths(api)

render(api, "satori.lua.mtl", "../satori/satori.lua")
