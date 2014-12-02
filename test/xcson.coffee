path = require 'path'
fileTestDir = path.join(__dirname, 'file-tests')

describe 'Xcson', ->

  it 'should return a promise', ->
    xcson = require '../src/xcson'
    promise = new xcson('{ worked: true }')
    expect(promise).to.have.property 'then'

  it 'should parse stringified json', ->
    xcson = require '../src/xcson'
    promise = new xcson('{worked: true}')
    expect(promise).to.eventually.have.property 'worked'

  it 'should parse a json file', ->
    xcson = require '../src/xcson'
    promise = new xcson cwd: fileTestDir, file: 'basic'
    expect(promise).to.eventually.have.property 'worked'

  it 'should gracefully fail with invalid files', ->
    xcson = require '../src/xcson'
    promise = new xcson cwd: fileTestDir, file: 'invalid'
    expect(promise).to.be.rejected

  describe 'default extensions', ->
    xcson = require '../src/xcson'
    promise = new xcson cwd: fileTestDir, file: 'extensions'
    it 'should support multikey', ->
      expect(promise).to.eventually.have.deep.property 'multikey.worked'
      expect(promise).to.eventually.not.have.deep.property 'multikey, multikey2'
    it 'should support repeat', ->
      expect(promise).to.eventually.have.deep.property 'repeat[0].worked'
      expect(promise).to.eventually.have.deep.property 'repeat[1].worked'
    it 'should support enumerate', ->
      expect(promise).to.eventually.have.deep.property 'enumerate[0].worked'
      expect(promise).to.eventually.have.deep.property 'enumerate[1].worked'

    describe 'inherit', ->
      it 'should support basic behavior', ->
        expect(promise).to.eventually.have.deep.property 'inherits.worked'
        expect(promise).to.eventually.have.deep.property 'inherits.subdirectoryWorked'
        expect(promise).to.eventually.have.deep.property 'inherits.objectWorked'

      inherits = new xcson cwd: fileTestDir, file: 'subdirectory/anothersubdirectory/inheritRoot'
      it 'should traverse upwards', ->
        expect(inherits).to.eventually.have.deep.property 'worked.root'

  describe 'custom extensions', ->
    it 'should support a custom scope extension', ->
      xcson = require '../src/xcson'
      xcson.scope 'custom', -> true
      promise = new xcson '{ worked: custom() }'
      expect(promise).to.eventually.have.property 'worked', true

    it 'should support a custom walker extension', ->
      xcson = require '../src/xcson'
      xcson.walker 'unworked', (node) ->
        @parentNode[@key] = "unworked" if node is true
        node

      promise = new xcson cwd: fileTestDir, file: 'basic'
      expect(promise).to.eventually.have.property 'worked', 'unworked'
