## What is "xcson"?

xcson is eXtensible CSON, a node module that extends the [CSON](https://github.com/bevry/cson) data format to include mixins and plugins.

You write in an extensible CSON format, you get JSON back. It's the DRYest way to build large JSON datasets with lots of repeating content.

## Example

Let's say you need to create a huge, ugly JSON schema:

**schema.json**

    {
        "title": "Example Schema",
        "type": "object",
        "properties": {
            "firstName": {
                "type": "string"
            },
            "lastName": {
                "type": "string"
            },
            "middleName": {
                "type": "string"
            }
    }

In the xcson world, you would create a mixin file:

**type/string.cson**

    {
        type: "string"
    }

And rewrite the previous as follows:

**schema.cson**

    {
        title: "Example Schema"
        type: "object"
        properties:
            "firstName, lastName, middleName": inherits "type/string"
    }

Now we build everything:

    var xcson = require('xcson');
    output = new xcson('schema.cson');
    console.log(output.toString());

Output will be equivalent to the first example.

## Available plugins

These are the available plugins out of the box:

**inherits**

Merges the contents of each mixin specified, and can have a custom object as the last parameter:

    key: inherits "foo", "bar", { object }

**enumerate**

Creates an array from a glob or list of mixins.

    key: enumerate "files/*", "anotherfile"

**repeat**

Creates an array of content repeated n times.

    key: repeat 4, { object }

**multikey**

Finds all comma delimited key names and expands them.

    "foo, bar, baz": { object }

becomes:

    foo: { object }
    bar: { object }
    baz: { object }

Make sure to enclose in quotes.

## Creating plugins

There are two types of plugins: walkers and scope.

Both are registered in a similar manner:

    var xcson = require('xcson');
    xcson.walker('Name of your plugin', function);
    xcson.scope('Name of your plugin', function);

** Walkers **

Walkers run once on every node as xcson traverses object trees. They receive the current node as an argument, and need to return the node when completed:

    xcson.walker('MyWalkerPlugin', function(node){
      node.foo = "bar";
      return node;
    });

Return values can also be Promises.

     xcson.walker('MyWalkerPlugin', function(node){
      new Promise(function(resolve, reject) {
         somethingAsync(){
            node.foo = "bar";
            resolve(node);
         }
      });
     });

Walker functions are also bound with a context object that contains some handy properties:

    xcson.walker('MyWalkerPlugin', function(node){
      console.log(this);
      // this.parentNode = Parent node
      // this.key = Current key name
      // this.path = Array of path keys to current location inside object.
      // this.originalNode = The node as it began before being altered by any other walkers
    });    

Walkers are run in a series, with each walker receiving the results of the previous. The final result will replace the node content.

See the multikey source for an example.

** Scope **

Scope plugins provide functions that are made available to each xcson file. These are like mixins.

    xcson.scope('MyScopePlugin', function(text) { return text + " there" });

Now in your xcson file, you can reference your plugin:

    foo: MyScopePlugin "hello"

With the final JSON output being:

    { foo: "hello there" }

See the source of inherits, repeat and enumerate for examples.

## Debugging

    Resolving huge Promise trees with secondary, inherited files can be messy business. For that reason, there is a console [debugger](https://github.com/visionmedia/debug) that runs internally and takes wildcards:
    
    $ DEBUG=xcson:* node yourscript.js
    
    $ DEBUG=xcson:*filename.xcson* node yourscript.js


## Notes

xcson is valid CSON. CSON is just Coffeescript. xcson files are valid Coffeescript.

output.toString() will, by default, sort all keynames.

You can omit the leading and trailing document brackets for extra cleanliness:

    { # Omit me
        foo:
            bar:
                baz: true
    } # Omit me


Infinitely nested plugins/mixins are valid:

    baz: "boo, woo": inherits "bar", thing: repeat 2, maybe: true

but will become difficult to read as a side effect of Coffee's expressive nature.
To help readability, you should use parenthesis, brackets and whitespace:

    baz:
        "boo, woo": inherits "bar",
            thing: repeat(2, { maybe: true })

and don't forget to separate repeatable content blocks into mixins.

For reference, the JSON produced from either examples above would look like this:

    {
      "baz": {
        "boo": {
          "bar": true,
          "thing": [
            {
              "maybe": true
            },
            {
              "maybe": true
            }
          ]
        },
        "woo": {
          "bar": true,
          "thing": [
            {
              "maybe": true
            },
            {
              "maybe": true
            }
          ]
        }
      }
    }

## Installation

via npm:

    $ npm install xcson

xcson is [UNLICENSED](http://unlicense.org/).
