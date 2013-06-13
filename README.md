osc-scripter
===========


Command-line app to send a series of OSC ([Open Sound Control](http://osc.justthebestparts.com/)) messages to a target OSC server.  The program reads a script file that contains some basic configuration info and then a series of commands. 

The commands can be raw OSC messages, or they can be instructions to invoke a method that in turn constructs a sequence of OSC messages.

Such complex commands can also be set to run in an endless loop, so you can kick of some repeating behavior while continuing to send other messages.

[Learn more about OSC here](http://osc.justthebestparts.com/)

The code is still kind of raw, with some experimentation going on. But it works, and it's quite slick.

The program reads in a script file, parses out some configuration details, and then executes the remaining lines as script commands.

The program, while running, also listens for OSC messages.  It assumes that any message it receives is a raw string formatted as a script command.  These messages are executed as soon as they are received.

Script commands include the ability to execute methods defined in `osc-scripter`.  One of those methods, `load_file` loads an external file that (presumably) contains Ruby code defining more command handlers.

You can also load custom code when you start `osc-scripter` by passing in the path to a source file.


Features
--------

* Send "raw" OSC messages
* Set timed delays between messages
* Send meta commands that in turn create sequences of OSC messages
* Run a sequence of messages in a named loop
* Send commands to stop a named message loops
* Accept OSC commands containing script commands to invoke
* Dynamically load files (e.g, additional command handlers) from script commands 

Examples
--------

There is an example in the  `examples/` folder. It requires you to also have the [AnimataP5-ng](https://github.com/Neurogami/animatap5-ng) Processing library and works against one of the examples included there.


Script syntax
-------------

Scripts are plain text.  You can use any file extension you like, since the code reads the file name given.

This is a sample script:

    127.0.0.1:8000
    8001
    0.5
    /animata/sprite_left/layer/main_head/alpha 1.0
    /animata/sprite/orientation/left
    :@interpolate1[alpha_loop]||/animata/sprite_left/layer/main_head/alpha||1.0||0.0||5
    /animata/sprite_left/layer/main_head/move   500.0 30.0
    10
    /animata/sprite_left/layer/main_head/alpha 1.0
    5
    :stoploop[alpha_loop]
    30
    /animata/sprite_left/layer/main_head/alpha 1.0
    3

The first line must have the IP address and port of the OSC server, separated by a ':'.

The second line must have the port for the internal OSC server

All remaining lines are script commands. Assorted character delimiters and pattern matching is used to indicate special command processing.

If a command start with a digit it is assumed to represent seconds; the program will go into a sleep loop for that length of time.

If a command starts with a ':' it is assumed that this is a "complex" command.  That's perhaps not the best terminology but it's what I've been using to have some way to think about it.  Complex commands have this syntax:

    :<method_name>||<osc/address/pattern>||<arg1>||<arg2>|| ...

So, theoretically, you can just add whatever methods you like and have them called.  

The code at the moment as two methods specifically meant for this, `interpolate1` and `interpolate2`.

`interpolate1` takes an address pattern that would be sent with a single argument (presumably a float, for this code). It also takes two values, a start and end value for this address pattern. There's one last argument, a float indication a duration.

There's a constant, `TIME_FRACTION`, used for timing short delays in loops. The method figures out how many such intervals make up the given duration, and constructs that many values interpolated for the start value to the end value.  Basically, a series of evenly-spaced steps to be carried out over the length of the given duration.  Handy, for example, to fade out an animation sprite in a specific length of time.

There's a bug here, though: The timing is not terribly precise.  It's close, but don't set your watch to it.

`interpolate2` is similar, but interpolates using two distinct variables.

Both of these run the created sequence in a thread, so once initiated the script processing continues.  This allows you to have multiple things running at the same time.

If a command starts with ':@' it indicates a complex command that should be run in an endless (threaded) loop.  

    :@<method_name>||<osc/address/pattern>||<arg1>||<arg2>|| ...

Such commands can also include a loop "label", using brackets, like this

    :@<method_name>[<label_name>]||<osc/address/pattern>||<arg1>||<arg2>|| ...

If a label is provided then the loop thread is stashed in a hash with the label as the key.

This allows for another special command:

    :stoploop[<label_name>]

This tells the program to go look up the thread reference keyed with that label and kill it.

(BTW, it may now occur to you now that there are at least _two_ ways to stop a loop.)



Internal OSC server 
-----------------

There's is also an OSC server that runs inside the program.  It matches on all address patterns (for better or worse).  It assumes that whatever argument is sent with the message is a script command of some kind, and is immediately executed as such.

This is helpful for live performances where the somewhat loose timing of a script can be compensated with immediate commands sent from some other source ([TouchOSC](http://hexler.net/software/touchosc), for example, or [Control](http://charlie-roberts.com/Control/)).

It also means that you can run scripts against applications that can, in turn, send back OSC messages, such as [Renoise](http://www.renoise.com/).

For some existential fun you can have two instances of `osc-scripter` interact with each other.

If for some reason you do not want an internal OSC server then set that port to 0.


Loading custom command handlers
-------------------------------


When running `osc-scripter` you can pass, in addition to the name of the script file, the path to some source code file.  This file will be loaded (i.e. `load` is called on the file path) at the start of the program.

Since that is done using a built-in method named (surprise) `load_file` you can also load files from our script or by OSC (by sending a script command to load a file).

If you want to be _really_ clever you could load a file that defines a method that calls `eval` and dynamically add code using OSC.

Proof is left as an exercise for the reader.


Requirements
------------

Ruby, the osc-ruby gem, and a sense of adventure.

Install
-------

Grab the source from github.com. A gem will at some point be up at [gems.neurogami.com](http://www.neurogami.com/gems/)

Usage
------

    $ osc-scripter <path-to-script-file> [optional-path-to-additional-code-file]



Author
------

James Britt / Neurogami (james@neurogami.com)




License
-------

The MIT License 

Copyright (c) 2013 James Britt / Neurogami

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Feed your head.

Hack your world.

Live curious.
