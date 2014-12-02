# "foo, bar": { value } --> foo: { value }, bar: { value }

isObject = (obj) -> '[object Object]' == Object::toString.call(obj)

module.exports = (node) ->

  return node unless typeof node is 'object'

  for key, val of node when key?.match(/,/)
    console.log "\t\tMultikey found", key
    node[splitkey] = node[key] for splitkey in key.split(/,\s*/)
    delete node[key]

  node
