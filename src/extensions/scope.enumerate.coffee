{Promise} = require 'es6-promise' unless Promise
promisifyArray = (results) -> (Promise.resolve(r) for r in results)

module.exports = (enumerators...) ->
  importOrObjects = (for e in enumerators
    if typeof e is "string" then @import.call(@, e) else e)

  Promise.all(promisifyArray importOrObjects)
  .then (res) -> [].concat res...
