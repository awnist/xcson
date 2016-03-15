# TODO: async glob

pathUtil = require 'path'
glob = require 'glob'
{Promise} = require 'es6-promise' unless Promise

module.exports = (paths, lookingFor) ->

  # If we did ("/path/to/file") instead of ("path", "file")
  if typeof paths is "string" and not lookingFor
    paths = pathUtil.dirname paths
    lookingFor = pathUtil.basename paths

  lookingFor = "#{lookingFor}.{xcson,cson,json}" unless pathUtil.extname lookingFor

  # arrayify
  if Array.isArray paths
    searchPaths = paths
  else if typeof paths is 'string'
    searchPaths = [paths]
  else
    throw "Don't know what to do with #{paths}, path should be string or array of strings"

  Promise
  .all(searchPaths.map (item) -> globUpwards(item, lookingFor))
  .then (results) ->

    # Remove null results
    validResults = results.filter (n) -> n?

    unless validResults.length
      throw "Can't find #{lookingFor} in #{searchPaths.join(',')}"

    # Flatten [[path], [path]] into [path, path]
    [].concat.apply([], validResults)


globUpwards = (paths, lookingFor) ->

  # If paths is null, we're out of search paths. Abort
  # We use null instead of reject so Promise.all doesn't quit early.
  return Promise.resolve(null) unless paths?.length

  paths = paths.split(pathUtil.sep) if typeof paths is 'string'

  # Because /foo/bar becomes ['', 'foo', 'bar'] from the split above
  unless paths[0]
    paths[0] = pathUtil.sep

  new Promise (resolve, reject) ->

    # [path,path] becomes /path/path/file
    check = pathUtil.join.apply @, paths.concat([lookingFor])

    glob check, { nonegate: true }, (err, matches) =>
      if matches?.length
        return resolve(matches)
      else
        return resolve(null)

  .then (results) ->
    if results is null
      # Keep searching upwards with this glob
      return globUpwards(paths.slice(0,-1), lookingFor)
    else
      # Just return results if we found something.
      return results



# new Promise (resolve, reject) ->

#   while paths.length

#     check = pathUtil.join.apply @, paths.concat([lookingFor])

#     files = glob.sync check, { nonegate: true }

#     return resolve(files) if files.length

#     paths.pop()

#   reject "Can't find #{lookingFor}"
