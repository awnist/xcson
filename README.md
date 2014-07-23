## What is "xcson"?

xcson is eXtensible CSON, a node module that extends the [CSON](https://github.com/bevry/cson) data format to include mixins and plugins.

You write in an extensible CSON format, you get JSON back. It's the DRYest way to build large JSON datasets with lots of repeating content.

## Example

Let's say you need to create a huge ugly JSON schema:

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
        ...
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
