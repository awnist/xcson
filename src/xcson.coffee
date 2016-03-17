async = require 'async'
coffee = require 'coffee-script'
debug = require './debug'
fs = require 'fs'
packageRoot = require 'package.root'
pathUtil = require 'path'
{Promise} = require 'es6-promise' unless Promise
glob = require 'glob'
stringify = require 'json-stable-stringify'
whenTraverse = require 'when-traverse'

isPromise = (object) -> isObject(object) && typeof object.then is "function"
isObject = (obj) -> '[object Object]' == Object::toString.call(obj)
checkPath = (path) ->
  new Promise (resolve, reject) ->
    glob path, { nonegate: true }, (err, matches) =>
      if matches?.length
        return resolve(matches)
      else
        # We use null instead of reject so Promise.all continues
        return resolve(null)

isCwdPath = (path) -> typeof path is 'string' and path.substr(0,2) is './'
isAbsPath = pathUtil.isAbsolute
isRelativePath = (path) -> not isAbsPath(path) and not isCwdPath(path)

module.exports = Xcson = class Xcson

  extensions = {}

  constructor: (config) ->

    # @ORIGINALCONFIG = config

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
      @config.cwd = pathUtil.dirname(@config.file) or packageRoot.path
      @config.file = pathUtil.basename @config.file

    # if @config.cwd and isRelativePath(@config.cwd)
    #   try
    #     fs.accessSync(@config.cwd, fs.F_OK)
    #   catch e
    #     if @config.root and @config.cwd isnt @config.root
    #       testPath = pathUtil.join(@config.root, @config.cwd)
    #     try
    #       fs.accessSync(testPath, fs.F_OK)
    #       @config.cwd = testPath
    #     catch e

    # In a chain of inherits, this will be the original file's location
    @config.root ?= @config.cwd

    @config.paths ?= []
    @config.paths = [@config.paths] unless Array.isArray @config.paths
    for path, i in @config.paths
      if isRelativePath(path)
        @config.paths[i] = pathUtil.join(@config.root, path)

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
      @debug "Looking for self", @config.cwd, @config.file

      # pathUtil.join(@config.cwd, 
      promise = @_findFiles(@config.file)
        .then (files) =>
          unless files
            @debug "Unable to locate self", @config.file
            throw new Error "Can't find file \"#{@config.file}\""
          # If multiple files were found, parse all of them with new Xcson instances...
          else if files.length > 1
            return Promise.all(new Xcson(file: file, root: @config.root, breadcrumb: @config.breadcrumb, paths: @config.paths) for file in files)
          else
            # Otherwise, stay in the current context and parse this file.
            # Note @file is not in @config
            @file = files[0]

            # Reset cwd to wherever this file was found.
            @config.cwd = pathUtil.dirname(@file)

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
      @debug "\tdone with errors", @config.file, err?.stack or err

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
        fullpath = pathUtil.join(@config.cwd, @config.file)
        e.message = "Eval error in #{fullpath}: #{e.message}"
        e.fileName = fullpath
      return Promise.reject e

    @traverse result, false

  traverse: (obj, newDebugName) ->
    traversedebug = if not newDebugName then @debug else (new debug(newDebugName)).log
    traversedebug "Traversing object."

    whenTraverse obj,
      enter: (node, key, parentNode, path) =>
        
        file = if @config.cwd then pathUtil.join(@config.cwd, @config.file) else null

        debugstep = (node) ->
          traversedebug "Running walker #{@task} on #{@path.join('.')}"
          node

        seq = Promise.resolve(node)

        for task, taskfn of @walkers
          context = { key, path, parentNode, task, originalNode: node, file: file }

          seq = seq
                  .then debugstep.bind context
                  .then taskfn.bind context

        # Transform undefined, which is ignored in whenTraverse, to REMOVE.
        # This means if any Promise returns undefined, the node will be deleted as (hopefully) expected.
        seq.then (node) ->
          if node is undefined then whenTraverse.REMOVE else node

  toObject: -> @result
  toString: -> stringify @result, space: @config.stringifySpaces

  import: (name) ->
    # if @cache name
    #   return Promise.resolve @cache name
    @debug("import(#{name})")
    @_findFiles(name)
    .then (files) =>

      unless files
        @debug("Can't find #{name}")
        throw "Can't find #{name}"

      Promise.all((new Xcson(
        file: file,
        root: @config.root,
        paths: @config.paths,
        breadcrumb: @config.breadcrumb) for file in files))

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

  _findFiles: (lookingFor) ->

    # Add file.extensions
    unless pathUtil.extname lookingFor
      lookingFor += ".{xcson,cson,json}"

    # ./file = $cwd/file
    if isCwdPath(lookingFor)
      searchPaths = [@config.cwd]
    # /file = /project-root/file
    else if isAbsPath(lookingFor) 
      searchPaths = ['']
    # file = [project-root/file, $paths/file]
    else
      searchPaths = [@config.cwd]
      if @config.cwd isnt @config.root
        searchPaths.push @config.root
      searchPaths.push @config.paths...

    @debug "Looking for #{lookingFor} in", searchPaths

    searchPaths.reduce(((promiseChain, path) ->
      return promiseChain.then (results) ->
        if results
          return results
        else
          return checkPath pathUtil.join(path, lookingFor)
    ), Promise.resolve())
    # .then (results) =>
    #   unless results
    #     console.error "_findFiles", @config.file, "can't locate #{lookingFor}"
    #     console.error {
    #       cwd: @config.cwd
    #       root: @config.root
    #       searchPaths: searchPaths
    #       ORIGINALCONFIG: @ORIGINALCONFIG
    #     }
    #   results


Xcson.walker 'multikey', require './extensions/walker.multikey'
Xcson.scope 'repeat', require './extensions/scope.repeat'
Xcson.scope 'enumerate', require './extensions/scope.enumerate'
Xcson.scope 'inherits', require './extensions/scope.inherits'
