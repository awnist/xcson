{Promise} = require 'es6-promise' unless Promise
promisifyArray = (results) -> (Promise.resolve(r) for r in results)
merge = require 'lodash.merge'

module.exports = (extenders...) ->

  importOrObjects = (for e in extenders
    if typeof e is "string" then @import.call(@, e, true).then((res)-> merge.apply(@, res)) else e)

  # promisifyArray should ensure each array element is a promise.
  Promise.all(promisifyArray importOrObjects)
  .then (res) =>
  	@traverse merge.apply(@, res), @config.breadcrumb+">"+"inherits()"
