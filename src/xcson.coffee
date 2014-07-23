coffee = require 'coffee-script'
fs = require 'fs'
path = require 'path'
glob = require 'glob'
traverse = require 'traverse'
stringify = require 'json-stable-stringify'
_ = require 'lodash'

findFile = (paths, lookingfor) ->

	# if lookingfor is in a subfolder, extract folder path
	paths = path.dirname(lookingfor) unless paths

	# arrayify
	paths = paths.split(path.sep) if typeof paths is 'string'

	while paths.length

		check = path.join.apply @, paths.concat(["#{lookingfor}.{xcson,cson,json}"])

		files = glob.sync check, { nonegate: true }

		# console.log "glob", check, " = ", files

		return files if files.length

		paths.pop()

	return false


module.exports = Xcson = class Xcson

	pluginregistry = {}

	constructor: (config) ->

		if typeof config is 'string'
			@config =
				file: config
				dir: path.dirname config
		else
			@config = config

		@caches = {}

		@config.stringifySpaces = '  '

		@config.plugins ?= Object.keys pluginregistry

		# console.log @config.file

		files = glob.sync @config.file, { nonegate: true }

		throw "No files found for \"#{@config.file}\"" unless files.length

		contents = (fs.readFileSync(file).toString() for file in files).join "\n"

		context = {}

		for key in @pluginsOfType 'template'
			context[key] = pluginregistry[key].fn.bind @

		# https://github.com/bevry/cson/blob/master/README.md#use-case
		@result = coffee.eval contents, sandbox: context

		postprocessors = @pluginsOfType 'postprocess'

		@result = traverse(@result).map ->
			for key in postprocessors
				pluginregistry[key].fn.apply @, arguments
			return

	toObject: -> @result
	toString: -> stringify @result, space: @config.stringifySpaces

	import: (name) ->
		return @cache(name) if @cache(name)

		# console.log path.dirname(@config.file), name

		if found = findFile path.dirname(@config.file), name
			# console.log "found:", found

			parsed = (new Xcson(file).toObject() for file in found)

			return @cache name, parsed
		else
			throw new Error "Xcson: can't find inheritable \"#{name}\""

	cache: (name, json) ->
		@caches[name] = json if json
		@caches?[name]

	pluginsOfType: (type) -> (key for key in @config.plugins when pluginregistry[key].type is type)

	@plugin = (name, type, fn) ->
		pluginregistry[name] =
			type: type
			fn: fn

# "foo, bar": { value } --> foo: { value }, bar: { value }
Xcson.plugin 'multikey', 'postprocess', (x) ->
	if @key?.match(/,/)

		for key in @key.split(/,\s*/)
			@parent.node[key] = _.cloneDeep @node

		@delete()

Xcson.plugin 'repeat', 'template', (times, content) -> _.cloneDeep(content) for n in [1..times]

Xcson.plugin 'enumerate', 'template', (enumerators...) ->
	arr = []

	for e in enumerators

		if typeof e is "string"
			e = @import.call(@, e)

		arr.push e...

	arr


Xcson.plugin 'inherits', 'template', (extenders...) ->
	obj = {}

	for e in extenders

		if typeof e is "string"
			e = _.merge.apply @, @import.call(@, e)

		for key, val of e
			obj[key] = val

	obj
