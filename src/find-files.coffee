# TODO: async glob

path = require 'path'
glob = require 'glob'
{Promise} = require 'es6-promise' unless Promise

module.exports = (paths, lookingfor) ->

  if typeof paths is "string" and not lookingfor
    paths = path.dirname paths
    lookingfor = path.basename paths

  lookingfor = "#{lookingfor}.{xcson,cson,json}" unless path.extname lookingfor

  # arrayify
  paths = paths.split(path.sep) if typeof paths is 'string'

  # Because /foo/bar becomes ['', 'foo', 'bar'] from the split above
  paths[0] = path.sep unless paths[0]

  new Promise (resolve, reject) ->

    while paths.length

      check = path.join.apply @, paths.concat([lookingfor])

      files = glob.sync check, { nonegate: true }

      return resolve(files) if files.length

      paths.pop()

    reject "Can't find #{lookingfor}"
