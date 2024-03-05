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
        definition = api["definitions"].get(ref)
        return definition
    return None

def fix_description(o):
    if "description" in o:
        o["description"] = o["description"].replace("\n", "\n-- ")

def fix_responses(api, o):
    fixed = []
    responses = o["responses"]
    for code in responses.keys():
        response = responses[code]
        if code != "default":
            response["code"] = code

        if "schema" in response:
            schema = response["schema"]
            ref = get_ref(api, schema)
            if ref and ref["name"] == "api_session":
                o["is_authentication_method"] = True
        
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
        elif t == "integer":
            return "number"
        elif t == "array":
            return "table"
    return "table"

# convert properties from a dictionary to a list
def fix_properties(api, o):
    if "properties" in o:
        propertieslist = []
        properties = o["properties"]
        property_names = []
        for prop_name in properties.keys():
            prop = properties[prop_name]
            type_lua = parameter_type_to_lua(prop)
            prop["name"] = prop_name
            prop["type_lua"] = type_lua
            prop["name_lua"] = prop["name"].replace("@", "") + "_" + type_lua
            prop["description"] = prop["description"] if "description" in prop else ""
            property_names.append(prop["name_lua"])
            fix_description(prop)
            propertieslist.append(prop)
        o["property_names"] = ",".join(property_names)
        o["properties"] = propertieslist

def get_schema(api, o):
    schema = None
    if "schema" in o:
        schema = o["schema"]
        if "$ref" in schema:
            schema = get_ref(api, schema)
        if isinstance(schema["properties"], dict):
            fix_properties(api, schema)
    return schema


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

        # fix when the schema is not an object
        # when this is encountered the schema is treated as a normal parameter
        if "schema" in parameter:
            schema = parameter["schema"]
            if "type" in schema and schema["type"] != "object":
                parameter["type"] = schema["type"]
                del parameter["schema"]

        schema = get_schema(api, parameter)
        if schema:
            # create new parameters from the schema properties
            for prop in schema["properties"]:
                print(" ", prop["name"], parameter["in"])
                prop_param = parameter.copy()
                for k in prop.keys():
                    prop_param[k] = prop[k]
                updated_parameters.append(prop_param)
        else:
            updated_parameters.append(parameter)
    o["parameters"] = updated_parameters

    # build a list of parameter names and assign parameter types
    # we must do this as a separate step since we may have added new parameters
    # in the first iteration over the paramters above
    parameter_names = []
    parameters = o["parameters"]
    for parameter in parameters:
        type_lua = parameter_type_to_lua(parameter)
        parameter["description"] = parameter["description"] if "description" in parameter else ""
        parameter["type_lua"] = type_lua
        parameter["name_lua"] = parameter["name"].replace("@", "") + "_" + type_lua
        parameter_names.append(parameter["name_lua"])
    o["parameter_names"] = ", ".join(parameter_names)

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
        definition["has_enum"] = ("enum" in definition)
        definition["has_properties"] = ("properties" in definition)
        fix_description(definition)
        fix_properties(api, definition)
        definitionslist.append(definition)
    api["definitionslist"] = definitionslist


# common
common_lua = read_file("common.lua")

# satori
satori_api = read_as_json("satori.swagger.json")
fix_definitions(satori_api)
fix_paths(satori_api)

satori_paths = render_to_string(satori_api, "paths.lua.mtl")
satori_defs = render_to_string(satori_api, "definitions.lua.mtl")
satori_lua = read_file("satori.lua")
satori_lua = satori_lua.replace("%%common%%", common_lua)
satori_lua = satori_lua.replace("%%paths%%", satori_paths)
satori_lua = satori_lua.replace("%%definitions%%", satori_defs)
write_file(satori_lua, "../satori/satori.lua")

# nakama
nakama_api = read_as_json("apigrpc.swagger.json")
fix_definitions(nakama_api)
fix_paths(nakama_api)

nakama_paths = render_to_string(nakama_api, "paths.lua.mtl")
nakama_defs = render_to_string(nakama_api, "definitions.lua.mtl")
nakama_lua = read_file("nakama.lua")
nakama_lua = nakama_lua.replace("%%common%%", common_lua)
nakama_lua = nakama_lua.replace("%%paths%%", nakama_paths)
nakama_lua = nakama_lua.replace("%%definitions%%", nakama_defs)
write_file(nakama_lua, "../nakama/nakama.lua")
