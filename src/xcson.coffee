async = require 'async'
coffee = require 'coffee-script'
debug = require './debug'
fs = require 'fs'
packageRoot = require 'package.root'
path = require 'path'
{Promise} = require 'es6-promise' unless Promise
stringify = require 'json-stable-stringify'
whenTraverse = require 'when-traverse'

isPromise = (object) -> isObject(object) && typeof object.then is "function"
isObject = (obj) -> '[object Object]' == Object::toString.call(obj)
findFiles = require './find-files'

module.exports = Xcson = class Xcson

  extensions = {}

  constructor: (config) ->
    if typeof config is 'string'
      # If this is an unparsed object in string form...
      if config.indexOf("\n") + config.indexOf(':') > -2
        parse_me = config
        @config = {}
      # Otherwise assume file.
      else
        @config = file: config
    else
      @config = config

    if @config.file and not @config.cwd
      @config.cwd = path.dirname(@config.file) or packageRoot.path
      @config.file = path.basename @config.file

    # By default, just use all available extensions.
    @config.extensions ?= Object.keys(extensions)

    # When returning formatted json, use two spaces as default. (see json-stable-stringify)
    @config.stringifySpaces ?= '  '

    # Breadcrumb for debugging
    @config.breadcrumb = if @config.breadcrumb then @config.breadcrumb+">" else "xcson:"

    # Functions available on our parsing scope. These get passed to coffee.eval as the context
    @scope = {}
    @scope[key] = extensions[key].fn for key in @extsOfType('scope')

    @walkers = {}
    @walkers[key] = extensions[key].fn for key in @extsOfType('walker')

    # @caches = {}

    if @config.file
      {name: @config.breadcrumb, log: @debug} = new debug @config.breadcrumb + @config.file
      @debug "Finding", @config.cwd, @config.file

      promise = findFiles(@config.cwd, @config.file)
        .then (files) =>
          # If multiple files were found, parse all of them with new Xcson instances...
          if files.length > 1
            return Promise.all(new Xcson(file: file, breadcrumb: @config.breadcrumb) for file in files)
          else
            # Otherwise, stay in the current context and parse this file.
            # Note @file is not in @config
            @file = files[0]
            return @parse(fs.readFileSync(files[0]).toString(), null, files[0])

    else if parse_me
      {name: @config.breadcrumb, log: @debug} = new debug @config.breadcrumb + "#{parse_me.substr(0,25)}..."
      promise = @parse(parse_me)
    else
      {name: @config.breadcrumb, log: @debug} = new debug "#{breadcrumb}{ empty }"
      promise = Promise.reject "Nothing to parse"

    promise.then (result) =>
      @debug "\tdone", @config.file
    , (err) =>
      @debug "\tdone with errors", @config.file, err

    return promise

  parse: (parse_me) ->

    return Promise.reject "No cson object supplied" unless parse_me

    context = {}
    for key, fn of @scope
      context[key] = if typeof fn is 'function' then fn.bind(@) else fn

    # https://github.com/bevry/cson/blob/master/README.md#use-case
    try
      result = coffee.eval parse_me, sandbox: context
    catch e
      if @config.file and e.message
        fullpath = path.join(@config.cwd, @config.file)
        e.message = "Eval error in #{fullpath}: #{e.message}"
        e.fileName = fullpath
      return Promise.reject e

    @traverse result, false

  traverse: (obj, newDebugName) ->
    traversedebug = if not newDebugName then @debug else (new debug(newDebugName)).log
    traversedebug "Traversing object."

    whenTraverse obj,
      enter: (node, key, parentNode, path) =>

        debugstep = (node) ->
          traversedebug "Running walker #{@task} on #{@key}"
          node

        seq = Promise.resolve(node)

        for taskName, task of @walkers
          context = 
            task: taskName
            key: key
            path: path
            parentNode: parentNode
            originalNode: node

          seq
          .then debugstep.bind context
          .then task.bind context

        # Transform undefined, which is ignored in whenTraverse, to REMOVE.
        # This means if any Promise returns undefined, the node will be deleted as (hopefully) expected.
        seq.then (node) -> if node is undefined then whenTraverse.REMOVE else node

        seq

  toObject: -> @result
  toString: -> stringify @result, space: @config.stringifySpaces

  import: (name) ->
    # if @cache name
    #   return Promise.resolve @cache name
    findFiles(path.join(@config.cwd, path.dirname(@config.file)), name)
    .then (files) =>
      Promise.all((new Xcson(file: file, breadcrumb: @config.breadcrumb) for file in files))

  # cache: (name, json) ->
  #   @caches[name] = json if json
  #   @caches?[name]

  extsOfType: (type) -> (key for key in @config.extensions when extensions[key].type is type)

  registerExtension = (name, type, fn) ->
    extensions[name] =
      type: type
      fn: fn

  @walker: (name, fn) -> registerExtension name, 'walker', fn
  @scope: (name, fn) -> registerExtension name, 'scope', fn

Xcson.walker 'multikey', require './extensions/walker.multikey'
Xcson.scope 'repeat', require './extensions/scope.repeat'
Xcson.scope 'enumerate', require './extensions/scope.enumerate'
Xcson.scope 'inherits', require './extensions/scope.inherits'
