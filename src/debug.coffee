_debug = require 'debug'
debugregistry = {}

module.exports = debug = (name) ->
	if typeof name isnt 'string'
		return name: name, log: new _debug(name)

	if not debugregistry[name]
		debugregistry[name] = true
		return name: name, log: new _debug(name)

	alt = 2
	alt++ while debugregistry[name+'-'+alt]
	debugregistry[name+'-'+alt] = true
	return name: name+'-'+alt, log: new _debug(name)

