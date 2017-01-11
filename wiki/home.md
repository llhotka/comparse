Comparse – Monadic Parsing Library
==================================

We've been all taught that creating a parser boils down to writing a
context free grammar and then using some library like
[Bison](http://www.gnu.org/software/bison/ "Bison"). By the way, such
a library exists for JavaScript, too, it is called
[Jison](http://zaach.github.io/jison/ "Jison"), and CoffeeScript uses
it for parsing the source code.

On the other hand, I like the approach of functional parsers such as
[Parsec](http://legacy.cs.uu.nl/daan/parsec.html) or
[attoparsec](https://github.com/bos/attoparsec "attoparsec"), both
written in Haskell. They allow for building complex parsing functions
by combining simpler ones in various ways. A parsing function, once
written, can be easily reused in other contexts.

Even though JavaScript and CoffeeScript are not pure functional
languages, they do implement the most important functional paradigm:
functions are first-class data that can, for instance, be passed as
arguments to higher-order functions. Douglas Crockford also
[demonstrated](https://www.youtube.com/watch?v=b0EF0VTs9Dc "Monads and
Gonads") how the powerful concept of
[monads](http://en.wikipedia.org/wiki/Monad_(functional_programming)
"Monad") can be implemented in JavaScript.

So I was wondering whether a decent monadic parser could be written in
CoffeeScript. The result is _Comparse_, a monadic parsing
library. Frankly, I didn't expect to get something nearly as elegant
as the Haskell parsers mentioned above, primarily because Haskell has
special syntactic sugar for monadic programming (the “do”
notation). Much to my surprise, monadic functions and their
combinations can be written quite nicely in the CoffeeScript syntax
(but maybe I am just weird and biased).

The implementation takes into account the lack of tail recursion
optimization in JavaScript, so recursive functions are mostly
rewritten using loops. Also, since JavaScript is _not_ a pure
functional language, side effects and non-local variables are used in
a few places for improving efficiency.

Getting Started
---------------

It is not necessary to understand
[monads](http://en.wikipedia.org/wiki/Monad_%28functional_programming%29)
in order to be able to use the _Comparse_ library. It is just
sufficient to remember that a _parser_ constructed with this library
is a function in a context, where the context is simply an offset in
the input string where the function is supposed to start parsing.

The essential pattern in parser construction is connected with the
`bind` method and looks like this:

    p.bind f

The `bind` method returns a new parser that applies two parsers
sequentially. The first parser is the receiver `p` of the `bind`
method. However, the argument of `bind`, denoted `f`, is _not_ the
second parser: instead, `f` is a _function_ that returns a parser. Why
is that? It allows us to use the result of `p` in further processing,
and indeed, the argument of `f` is exactly the result of the parser `p`.

The `bind` method works like this:

1. The receiver (parser `p`) is applied first. If it fails (its result
   is `null`), then the combined parser returned by `bind` fails as
   well.

1. Otherwise, the result of parser `p` is fed as the argument to
   function `f` that returns a parser, say `q`. The result of the
   combined parser is then the result of `q`.

The argument of `bind`, function `f`, may of course be defined in a
separate assignment. Quite often, however, the argument `f` is
specified inline. The bind expression then looks in the CoffeeScript
syntax like this:

    p.bind (res) -> fbody

Of course, the argument function of `bind` may completely ignore the
result of parser `p`. In this case, the `bind` expression can be
written as an argumentless function:

    p.bind -> fbody

Other parser combinators and predefined parsers provided by the
_Comparse_ library are described in the Literate CoffeeScript
[source](comparse).

* [README – licence, installation etc.](README)

* [Annotated source code](comparse) 

* [Example parsers](examples)

* [Parser](https://gitlab.labs.nic.cz/labs/yang-tools/wikis/coffee_parser)
  for [YANG](http://tools.ietf.org/html/rfc6020) data modelling language.
