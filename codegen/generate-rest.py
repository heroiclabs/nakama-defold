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


def read_file(path):
    with open(path, 'r') as f:
        return f.read()

def read_as_json(filename):
    with open(filename) as f:
        return json.load(f)

def write_file(data, outfile):
    with codecs.open(outfile, "wb", encoding="utf-8") as f:
        f.write(data)

def render_to_string(data, templatefile):
    with open(templatefile, 'r') as f:
        template = f.read()
        result = pystache.render(template, data)
        return result

def render_to_file(data, templatefile, outfile):
    write_file(render_to_string(data, templatefile), outfile)

# https://stackoverflow.com/a/1176023/1266551
def camel_to_snake(name):
    name = re.sub('(.)([A-Z][a-z]+)', r'\1_\2', name)
    name = re.sub('([a-z0-9])([A-Z])', r'\1_\2', name).lower()
    return name.replace("__", "_")


def get_ref(api, data):
    if "$ref" in data:
        ref = data["$ref"].replace("#/definitions/", "")
        ref_snake = camel_to_snake(ref)
        definition = api["definitions"].get(ref)
        return definition
    return None

def fix_responses(api, o):
    fixed = []
    responses = o["responses"]
    for code in responses.keys():
        response = responses[code]
        if code != "default":
            response["code"] = code
        
        fixed.append(response)
    o["responses"] = fixed

def parameter_type_to_lua(parameter):
    if "type" in parameter:
        t = parameter["type"]
        if t == "string":
            return "string"
        elif t == "boolean":
            return "boolean"
        elif t == "object":
            return "table"
    return "table"

def fix_description(o):
    if "description" in o:
        o["description"] = o["description"].replace("\n", "\n-- ")

def fix_properties(api, o):
    if "properties" in o:
        propertieslist = []
        properties = o["properties"]
        for prop_name in properties.keys():
            prop = properties[prop_name]
            prop["name"] = prop_name
            fix_description(prop)
            if "ref" in prop:
                prop["type"] = prop["ref"]
            propertieslist.append(prop)
        o["properties"] = propertieslist


def fix_parameters(api, o):
    has_parameters = "parameters" in o
    o["has_parameters"] = has_parameters
    if not has_parameters:
        return

    updated_parameters = []
    parameters = o["parameters"]
    for parameter in parameters:
        fix_description(parameter)
        if parameter["in"] == "body":
            o["has_body_parameters"] = True
            parameter["is_body_parameter"] = True
        elif parameter["in"] == "query":
            o["has_query_parameters"] = True
            parameter["is_query_parameter"] = True
        elif parameter["in"] == "path":
            o["has_path_parameters"] = True
            parameter["is_path_parameter"] = True

        if "schema" in parameter:
            schema = parameter["schema"]
            if "type" in schema and schema["type"] != "object":
                parameter["type"] = schema["type"]
                del parameter["schema"]
                updated_parameters.append(parameter)
                continue

            if "$ref" in schema:
                schema = get_ref(api, schema)
            else:
                fix_properties(api, schema)

            for prop in schema["properties"]:
                print(" ", prop["name"], parameter["in"])
                prop_param = parameter.copy()
                for k in prop.keys():
                    prop_param[k] = prop[k]
                updated_parameters.append(prop_param)
        else:
            updated_parameters.append(parameter)
    o["parameters"] = updated_parameters

    names = []
    parameters = o["parameters"]
    for parameter in parameters:
        type_lua = parameter_type_to_lua(parameter)
        parameter["type_lua"] = type_lua
        parameter["name_lua"] = parameter["name"] + "_" + type_lua
        names.append(parameter["name_lua"])

    o["parameter_names"] = ", ".join(names)

# convert paths from a dictionary of paths keyed on endpoint
# to a list of paths
def fix_paths(api):
    fixed = []
    paths = api["paths"]
    for path in paths.keys():
        endpoint = paths[path]
        for method in endpoint.keys():
            print(method.upper(), path)
            operation_id = endpoint[method]["operationId"]
            endpoint[method]["is_authentication_method"] = "Authenticate" in operation_id
            endpoint[method]["path"] = path
            endpoint[method]["operationId"] = camel_to_snake(operation_id).replace("satori_", "").replace("nakama_", "")
            endpoint[method]["postdata"] = (method == "post") or (method == "put") or (method == "delete")
            endpoint[method]["method"] = method.upper()
            fix_responses(api, endpoint[method])
            fix_parameters(api, endpoint[method])
            fixed.append(endpoint[method])
    api["paths"] = fixed


# convert definitions from a dictionary of definitions keyed on name
# to a list of definitions
def fix_definitions(api):
    definitionslist = []
    definitions = api["definitions"]
    for name in definitions.keys():
        print("definition:", name)
        definition = definitions[name]
        definition["name"] = camel_to_snake(name)
        definition["name_upper"] = name.upper()
        fix_description(definition)
        if "enum" in definition:
            definition["has_enum"] = True
        if "properties" in definition:
            definition["has_properties"] = True
            fix_properties(api, definition)
        definitionslist.append(definition)
    api["definitionslist"] = definitionslist


# satori
satori_api = read_as_json("satori.swagger.json")
fix_definitions(satori_api)
fix_paths(satori_api)

satori_paths = render_to_string(satori_api, "paths.lua.mtl")
satori_defs = render_to_string(satori_api, "definitions.lua.mtl")
satori_lua = read_file("satori.lua").replace("%%paths%%", satori_paths).replace("%%definitions%%", satori_defs)
write_file(satori_lua, "../satori/satori.lua")


# nakama
nakama_api = read_as_json("apigrpc.swagger.json")
fix_definitions(nakama_api)
fix_paths(nakama_api)

nakama_paths = render_to_string(nakama_api, "paths.lua.mtl")
nakama_defs = render_to_string(nakama_api, "definitions.lua.mtl")
nakama_lua = read_file("nakama.lua").replace("%%paths%%", nakama_paths).replace("%%definitions%%", nakama_defs)
write_file(nakama_lua, "../nakama/nakama.lua")
