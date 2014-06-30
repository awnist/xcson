coffee = require 'coffee-script'
fs = require 'fs'
path = require 'path'
traverse = require 'traverse'
stringify = require 'json-stable-stringify'
_ = require 'lodash'

findFile = (paths, lookingfor) ->

	# if lookingfor is in a subfolder, extract folder path
	paths = path.dirname(lookingfor) unless paths

	# arrayify
	paths = paths.split(path.sep) if typeof paths is 'string'

	while paths.length

		check = path.join.apply @, paths.concat(["#{lookingfor}.cson"])

		if fs.existsSync check
			return check

		paths.pop()

	return false


module.exports = CsonMason = class CsonMason

	pluginregistry = {}

	constructor: (config) ->

		if typeof config is 'string'
			@config =
				file: config
				dir: path.dirname config
		else
			@config = config

		@jsons = {}

		@config.stringify = '  '

		@config.plugins ?= Object.keys pluginregistry

		contents = fs.readFileSync(@config.file).toString()

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
	toString: -> stringify @result, space: @config.stringify

	import: (name) ->
		return @json(name) if @json(name)

		console.log path.dirname(@config.file), name
		if found = findFile path.dirname(@config.file), name
			console.log found
			return @json name, new CsonMason(found).toObject()
		else
			throw new Error "CsonMason: can't find inheritable \"#{name}\""

	json: (name, json) ->
		@jsons[name] = json if json
		@jsons?[name]

	pluginsOfType: (type) -> (key for key in @config.plugins when pluginregistry[key].type is type)

	@plugin = (name, type, fn) ->
		pluginregistry[name] =
			type: type
			fn: fn

# "foo, bar": { value } --> foo: { value }, bar: { value }
CsonMason.plugin 'multikey', 'postprocess', (x) ->
	if @key?.match(/,/)

		for key in @key.split(/,\s*/)
			@parent.node[key] = _.cloneDeep @node

		@delete()

CsonMason.plugin 'repeat', 'template', (times, content) -> _.cloneDeep(content) for n in [1..times]

CsonMason.plugin 'inherits', 'template', (extenders...) ->
	obj = {}

	for e in extenders

		if typeof e is "string"
			e = @import.call @, e

		for key, val of e
			obj[key] = val

	obj
