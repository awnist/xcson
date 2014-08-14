_ = require 'lodash'
async = require 'async'
coffee = require 'coffee-script'
fs = require 'fs'
glob = require 'glob'
path = require 'path'
{Promise} = require 'es6-promise'
stringify = require 'json-stable-stringify'
traverseasync = require 'traverse-async'

isPromise = (object) -> isObject(object) && typeof object.then is "function"
isObject = (obj) -> '[object Object]' == Object::toString.call(obj)
promisifyArray = (results) -> (Promise.resolve(r) for r in results)

class BlockNodeExit
	constructor: -> @waitTimer = null
	start: -> @waitTimer = setTimeout (=> @start()), 1000
	stop: -> clearTimeout @waitTimer

# TODO: async glob
findFile = (paths, lookingfor) ->

	new Promise (resolve, reject) ->

		lookingfor = "#{lookingfor}.{xcson,cson,json}" unless path.extname lookingfor

		# if lookingfor is in a subfolder, extract folder path
		paths = path.dirname(lookingfor) unless paths

		# arrayify
		paths = paths.split(path.sep) if typeof paths is 'string'

		while paths.length

			check = path.join.apply @, paths.concat([lookingfor])

			files = glob.sync check, { nonegate: true }

			return resolve(files) if files.length

			paths.pop()

		reject "Can't find #{lookingfor}"


module.exports = Xcson = class Xcson

	extensions = {}
	@scope = {}

	constructor: (config, finalcallback) ->

		if typeof config is 'string'
			# If this is an unparsed object in string form...
			if config.indexOf("\n") + config.indexOf(':') > -2
				parse_me = config
				@config = {}
			# Otherwise assume file.
			else
				@config =
					file: config
					dir: path.dirname config
		else
			@config = config

		@caches = {}

		@config.extensions = Object.keys(extensions)

		@scope = Xcson.scope

		@config.stringifySpaces ?= '  '
		# @config.plugins ?= Object.keys extensions

		if @config.file

			files = glob.sync @config.file, { nonegate: true }

			throw "No files found for \"#{@config.file}\"" unless files.length

			if files.length > 1
				promise = Promise.all(new Xcson(file) for file in files)
			else
				@file = files[0]
				promise = @parse fs.readFileSync(files[0]).toString()

		else
			promise = @parse(parse_me)

		@exitblocker = new BlockNodeExit
		@exitblocker.start()

		promise.then (result) =>
			finalcallback(null, result) if finalcallback
			@exitblocker.stop()
		, (err) ->
			finalcallback(err, null) if finalcallback
			@exitblocker.stop()

		return promise


	parse: (parse_me, finalcallback) ->

		throw "No cson object supplied" unless parse_me

		context = {}
		for key, fn of @scope
			context[key] = if typeof fn is 'function' then fn.bind(@) else fn

		# https://github.com/bevry/cson/blob/master/README.md#use-case
		result = coffee.eval parse_me, sandbox: context

		@traverse.call @, result

	traverse: (obj) ->

		promises = {}

		doneWalking = false

		walkers = @extsOfType('walker')

		self = @

		new Promise (resolve, reject) ->

			promiseUnlessNext = (fn) ->
				(context, next) ->
					result = fn.apply context, arguments
					if isPromise result
						# console.log "walkerfn promise", context.path?.join(".")
						result.then (-> next()), reject
						watchPromise.call(context, result)

			walkerfns = (promiseUnlessNext(extensions[key].fn) for key in walkers)

			watchPromise = (promise) ->
				# Attach another event to this promise so we can watch as
				# they develop.

				name = @path?.join(".") or "root"

				# console.log "\twatchPromise started on", name

				promises[name] = promise.then (value) =>

					# Replace promise with the resolve
					# console.log "\tdone, assigning #{name}" if name.match /,/
					@node = value
					@parent[@key] = value unless @isRoot

					# Remove this entry from queue
					delete promises[name]

					# If we have no more promises, the object is ready!
					if doneWalking and Object.keys(promises).length is 0
						return resolve obj

				, reject

			traverseasync.traverse obj, (value, next) ->

				@xcson = self

				if isPromise @node

					# console.log "while traversing, found a promise", @path?.join(".")

					watchPromise.call @, @node

					@node.then (value) =>

						async.applyEach walkerfns, this, (err, results) ->
							return reject(err) if err
							next()

					# next()
				else
					async.applyEach walkerfns, this, (err, results) ->
						return reject(err) if err
						next()
			, =>

				doneWalking = true

				if Object.keys(promises).length is 0
					resolve obj

	toObject: -> @result
	toString: -> stringify @result, space: @config.stringifySpaces

	import: (name, merge=false) ->

		# if @cache name
		# 	return Promise.resolve @cache name

		new Promise (resolve, reject) =>
			findFile(path.dirname(@config.file), name)
			.then (files) ->
				Promise.all((new Xcson(file) for file in files))
				.then (res) -> resolve if merge then _.merge.apply(@, res) else res
			, reject

	# cache: (name, json) ->
	# 	@caches[name] = json if json
	# 	@caches?[name]

	extsOfType: (type) -> (key for key in @config.extensions when extensions[key].type is type)

	registerExtension = (name, type, fn) ->
		extensions[name] =
			type: type
			fn: fn

	@walker: (name, fn) -> registerExtension name, 'walker', fn
	# @function: (name, fn) -> registerExtension name, 'plugin', fn


# "foo, bar": { value } --> foo: { value }, bar: { value }
Xcson.walker 'multikey', (obj, next) ->

	if @key?.match(/,/)

		# console.log """Multikey "#{@key}" found, splitting and deleting"""

		for key in @key.split(/,\s*/)
			@parent[key] = _.cloneDeep @node

		delete @parent[@key]

	next()

Xcson.scope.repeat = (times, content) -> _.cloneDeep(content) for n in [1..times]

Xcson.scope.enumerate = (enumerators...) ->
	importOrObjects = (for e in enumerators
		if typeof e is "string" then @import.call(@, e) else e)

	new Promise (resolve, reject) ->
		Promise.all promisifyArray importOrObjects
		.then (res) ->
			resolve [].concat res...
		, reject

Xcson.scope.inherits = (extenders...) ->
	importOrObjects = (for e in extenders
		if typeof e is "string" then @import.call(@, e) else e)

	Promise.all(promisifyArray importOrObjects)
	.then (res) => @traverse(_.merge.apply @, res)
