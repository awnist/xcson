## What is "csonmason"?

csonmason is a node module that extends the [CSON](https://github.com/bevry/cson) data format to include mixins and plugins. You write in an extensible CSON format, you get JSON back. It's the DRYest way to build large JSON datasets with lots of repeating content.

## Example

Let's say you need to create a huge ugly JSON schema:

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
        ...
    }

In the csonmason world, you would create a mixin file:

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

    var csonmason = require('csonmason');
    output = new csonmason('schema.cson');
    console.log(output.toObject());
    console.log(output.toString());

Output will be equivalent to the first example.

## Available plugins and mixins

These are the available plugins and mixins out of the box:

**inherits**
Merges the contents of each mixin specified, and can have a custom object as the last parameter:

    key: inherits "foo", "bar", { object }

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

## Notes

CSON is just Coffeescript. Csonmason files are valid Coffeescript.

output.toString() will, by default, sort all keynames.

Nested plugins/mixins are valid:

    baz:
        "boo, woo": inherits "bar", thing: repeat 2, { maybe: true }

which would produce this:

    baz:
        boo: { bar: true, thing: [{ maybe: true }, { maybe: true }] }
        woo: { bar: true, thing: [{ maybe: true }, { maybe: true }] }

## Installation

via npm:

    $ npm install csonmason

csonmason is [UNLICENSED](http://unlicense.org/).
