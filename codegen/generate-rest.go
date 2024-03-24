// Copyright 2018 The Nakama Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"os"
	"strings"
	"text/template"
)


var schema struct {
	Paths map[string]map[string]struct {
		Summary     string
		OperationId string
		Responses   struct {
			Ok struct {
				Schema struct {
					Ref string `json:"$ref"`
				}
			} `json:"200"`
		}
		Parameters []struct {
			Name     	string
			Description	string
			In       	string
			Required 	bool
			Type     	string   // used with primitives
			Items    	struct { // used with type "array"
				Type string
			}
			Schema struct { // used with http body
				Type string
				Ref  string `json:"$ref"`
			}
			Format   string // used with type "boolean"
		}
		Security []map[string][]struct {
		}
	}
	Definitions map[string]struct {
		Properties map[string]struct {
			Type  string
			Ref   string   `json:"$ref"` // used with object
			Items struct { // used with type "array"
				Type string
				Ref  string `json:"$ref"`
			}
			AdditionalProperties struct {
				Type string // used with type "map"
			}
			Format      string // used with type "boolean"
			Description string
		}
		Enum        []string
		Description string
		// used only by enums
		Title string
	}
}

func convertRefToClassName(input string) (className string) {
	cleanRef := strings.TrimPrefix(input, "#/definitions/")
	className = strings.Title(cleanRef)
	return
}

func stripNewlines(input string) (output string) {
	output = strings.Replace(input, "\n", "\n--", -1)
	return
}

func pascalToSnake(input string) (output string) {
	output = ""
	prev_low := false
	for _, v := range input {
		is_cap := v >= 'A' && v <= 'Z'
		is_low := v >= 'a' && v <= 'z'
		if is_cap && prev_low {
			output = output + "_"
		}
		output += strings.ToLower(string(v))
		prev_low = is_low
	}
	return
}

// camelToPascal converts a string from camel case to Pascal case.
func camelToPascal(camelCase string) (pascalCase string) {
	if len(camelCase) <= 0 {
		return ""
	}
	pascalCase = strings.ToUpper(string(camelCase[0])) + camelCase[1:]
	return
}
// pascalToCamel converts a Pascal case string to a camel case string.
func pascalToCamel(input string) (camelCase string) {
	if input == "" {
		return ""
	}
	camelCase = strings.ToLower(string(input[0]))
	camelCase += string(input[1:])
	return camelCase
}

func removePrefix(input string) (output string) {
	output = strings.Replace(input, "nakama_", "", -1)
	output = strings.Replace(output, "satori_", "", -1)
	return
}

func isEnum(ref string) bool {
	// swagger schema definition keys have inconsistent casing
	var camelOk bool
	var pascalOk bool
	var enums []string

	cleanedRef := convertRefToClassName(ref)
	asCamel := pascalToCamel(cleanedRef)
	if _, camelOk = schema.Definitions[asCamel]; camelOk {
		enums = schema.Definitions[asCamel].Enum
	}

	asPascal := camelToPascal(cleanedRef)
	if _, pascalOk = schema.Definitions[asPascal]; pascalOk {
		enums = schema.Definitions[asPascal].Enum
	}

	if !pascalOk && !camelOk {
		return false
	}

	return len(enums) > 0
}

// Parameter type to Lua type
func luaType(p_type string, p_ref string) (out string) {
	if isEnum(p_ref) {
		out = "string"
		return
	}
	switch p_type {
		case "integer": out = "number"
		case "string": out = "string"
		case "boolean": out = "boolean"
		case "array": out = "table"
		case "object": out = "table"
		default: out = "table"
	}
	return
}

// Default value for Lua types
func luaDef(p_type string, p_ref string) (out string) {
	switch(p_type) {
		case "integer": out = "0"
		case "string": out = "\"\""
		case "boolean": out = "false"
		case "array": out = "{}"
		case "object": out = "{ _ = '' }"
		default: out = "M.create_" + pascalToSnake(convertRefToClassName(p_ref)) + "()"
	}
	return
}

// Lua variable name from name, type and ref
func varName(p_name string, p_type string, p_ref string) (out string) {
	p_name = strings.Replace(p_name, "@", "", -1)
	switch(p_type) {
		case "integer": out = p_name + "_int"
		case "string": out = p_name + "_str"
		case "boolean": out = p_name + "_bool"
		case "array": out = p_name + "_arr"
		case "object": out = p_name + "_obj"
		default: out = p_name + "_" + pascalToSnake(convertRefToClassName(p_ref))
	}
	return
}

func varComment(p_name string, p_type string, p_ref string, p_item_type string) (out string) {
	switch(p_type) {
		case "integer": out = "number"
		case "string": out = "string"
		case "boolean": out = "boolean"
		case "array": out = "table (" + luaType(p_item_type, p_ref) + ")"
		case "object": out = "table (object)"
		default: out = "table (" + pascalToSnake(convertRefToClassName(p_ref)) + ")"
	}
	return
}

func isAuthenticateMethod(input string) (output bool) {
	output = strings.HasPrefix(input, "Nakama_Authenticate")
	return
}

func main() {
	// Argument flags
	var output = flag.String("output", "", "The output for generated code.")
	flag.Parse()

	inputs := flag.Args()
	if len(inputs) < 1 {
		fmt.Printf("No input file found: %s\n\n", inputs)
		fmt.Println("openapi-gen [flags] inputs...")
		flag.PrintDefaults()
		return
	}

	input := inputs[0]
	content, err := ioutil.ReadFile(input)
	if err != nil {
		fmt.Printf("Unable to read file: %s\n", err)
		return
	}


	if err := json.Unmarshal(content, &schema); err != nil {
		fmt.Printf("Unable to decode input %s : %s\n", input, err)
		return
	}


	// expand the body argument to individual function arguments
	bodyFunctionArgs := func(ref string) (output string) {
		ref = strings.Replace(ref, "#/definitions/", "", -1)
		props := schema.Definitions[ref].Properties
		keys := make([]string, 0, len(props))
		for prop := range props {
			keys = append(keys, prop)
		}
		for _,key := range keys {
			output = output + ", " + key
		}
		return
	}

	// expand the body argument to individual function argument docs
	bodyFunctionArgsDocs := func(ref string) (output string) {
		ref = strings.Replace(ref, "#/definitions/", "", -1)
		output = "\n"
		props := schema.Definitions[ref].Properties
		keys := make([]string, 0, len(props))
		for prop := range props {
			keys = append(keys, prop)
		}
		for _,key := range keys {
			info := props[key]
			output = output + "-- @param " + key + " (" + info.Type + ") " + stripNewlines(info.Description) + "\n"
		}
		return
	}

	// expand the body argument to individual asserts for the call args
	bodyFunctionArgsAssert := func(ref string) (output string) {
		ref = strings.Replace(ref, "#/definitions/", "", -1)
		output = "\n"
		props := schema.Definitions[ref].Properties
		keys := make([]string, 0, len(props))
		for prop := range props {
			keys = append(keys, prop)
		}
		for _,key := range keys {
			info := props[key]
			luaType := luaType(info.Type, info.Ref)
			output = output + "\tassert(not " + key + " or type(" + key + ") == \"" + luaType + "\", \"Argument '" + key + "' must be 'nil' or of type '" + luaType + "'\")\n"
		}
		return
	}

	// expand the body argument to individual asserts for the message body table
	bodyFunctionArgsTable := func(ref string) (output string) {
		ref = strings.Replace(ref, "#/definitions/", "", -1)
		output = "\n"
		props := schema.Definitions[ref].Properties
		keys := make([]string, 0, len(props))
		for prop := range props {
			keys = append(keys, prop)
		}
		for _,key := range keys {
			output = output + "\t" + key + " = " + key + ",\n"
		}
		return
	}


	fmap := template.FuncMap {
		"cleanRef": convertRefToClassName,
		"stripNewlines": stripNewlines,
		"title": strings.Title,
		"uppercase": strings.ToUpper,
		"pascalToSnake": pascalToSnake,
		"luaType": luaType,
		"luaDef": luaDef,
		"varName": varName,
		"varComment": varComment,
		"bodyFunctionArgsDocs": bodyFunctionArgsDocs,
		"bodyFunctionArgs": bodyFunctionArgs,
		"bodyFunctionArgsAssert": bodyFunctionArgsAssert,
		"bodyFunctionArgsTable": bodyFunctionArgsTable,
		"isEnum": isEnum,
		"isAuthenticateMethod": isAuthenticateMethod,
		"removePrefix": removePrefix,
	}

	MAIN_TEMPLATE := strings.Replace(MAIN_TEMPLATE, "%%COMMON_TEMPLATE%%", COMMON_TEMPLATE, 1)
	tmpl, err := template.New(input).Funcs(fmap).Parse(MAIN_TEMPLATE)
	if err != nil {
		fmt.Printf("Template parse error: %s\n", err)
		return
	}

	if len(*output) < 1 {
		tmpl.Execute(os.Stdout, schema)
		return
	}

	f, err := os.Create(*output)
	if err != nil {
		fmt.Printf("Unable to create file: %s\n", err)
		return
	}
	defer f.Close()

	writer := bufio.NewWriter(f)
	tmpl.Execute(writer, schema)
	writer.Flush()
}