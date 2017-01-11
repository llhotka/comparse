Comparse – Monadic Parsing Library
==================================

This text is the source code for the _Comparse_ monadic parsing
library written in
[Literate CoffeeScript](http://coffeescript.org/#literate "Literate
Coffeescript").

Parser Class
------------

A parser is essentially a function that takes an offset in the input
text as its argument where parsing is supposed to start, and returns
an array of two elements:

* The first element is the actual result of the parser. It can be
  virtually any value – a string, number, boolean value, array or
  object. If parsing fails, then `null` is returned.

* The second element is a new offset pointing to the remainder of the
  input text that hasn't been parsed yet.

The function is wrapped in an object of the **Parser** class so that
we can define methods for combining parsers. The input text is then
stored as a private property of the **Parser** prototype.

So, let's define the **Parser** class. Its constructor of the
**Parser** accepts a single parameter which has to be a parsing
function of the type specified above.

    class Parser
      constructor: (@pf) ->

The main parsing method is `parse`. Its argument is the input text to
be parsed. The method initializes the private property `_text` of the
**Parser** class with the input text, and then runs the receiver's
parsing function starting at offset 0. It either returns the result,
if it is non-null, or throws an exception if parsing fails. The
`parse` method needn't consume the entire input text. In order to make
sure that no trailing garbage is present, use the `eof` parser defined
below.

      parse: (text) ->
        Parser::_text = text
        res = @pf 0
        if res[0] is null
          throw Parser.error "Parsing failed", res[1]
        res[0]

Monadic Functions
-----------------

Let's face it: **Parser** is a monadic class. However, it is not
necessary to understand what
[monad](http://en.wikipedia.org/wiki/Monad_%28functional_programming%29)
is in order to be able to use the _Comparse_ library. On the other
hand, parsing is a nice fit for the monadic paradigm of a
computational context, so understanding how _Comparse_ combines simple
parsers into more complex ones can actually help in understanding
monads.

Anyway, let's see how the two basic monadic functions, _unit_ and
_bind_, are defined in _Comparse_. The former is implemented as a
class method: given an argument, `v`, which can be any value, it
returns a parser that doesn't read anything from the input text (so
offset isn't changed) and provides the value `v` as the result.

      @unit = (v) ->
        new Parser (offset) ->
          [v, offset]

In Haskell, the _unit_ function is called _return_ but it is generally
considered rather unfortunate because of the meaning _return_ has in
other programming languages. In JavaScript/CoffeeScript, _return_ is a
reserved word, so we can't use it even if we wanted.

The second monadic function, _bind_, is implemented as an instance
method. It returns a new parser that applies the receiver first and a
second parser in sequence. However, in order to be able to use the
parsed result of the receiver, e.g. for deciding what the second
parser should do, the argument of `bind` is actually a _function_ that
takes an argument and returns a parser.

If the receiver's result is `null` (the receiver failed), then the
result of the parser returned by `bind` is always `null`, too. If the
receiver's result is non-null (the receiver succeeded), then this the
function in the argument of `bind` is applied to that result and
returns the second parser, which starts parsing where the receiver
left off.

      bind: (f) ->
        new Parser (offset) =>
          res = @pf offset
          if res[0] is null
            [null, res[1]]
          else
            (f res[0]).pf res[1]

The function `f` in the argument may off course completely ignore the
receiver's result. In this case it can be defined as an argument-less
function.

Parser Combinators
------------------

Next, we implement several methods for combining two or more parsers
in various ways. A useful combination is the _alternative_ represented
by the `orElse` method. Its result is the same as the result of the
receiver if the receiver succeeds (returns a non-null value),
otherwise it is the result of the other parser that is given as the
argument to `orElse`.

      orElse: (other) ->
        new Parser (offset) =>
          res = @pf offset
          if res[0] is null then other.pf offset else res

The following method implements alternative with more than two
variants:

      @choice = (p,q...) ->
        if q.length == 0 then p else p.orElse(
          Parser.choice.apply null, q)

Note that unlike `orElse`, the `@` prefix indicates `choice` is a
_class method_ – all alternative parsers are passed to it as
arguments.

Another very powerful parser combinator is `many`: it represents
multiple applications of the receiver, with results collected in an
array. The `min` argument specifies the required minimum number of
successful applications of the receiver. The default value of zero
means that the receiver needn't succeed even once, in which case the
result is an empty array.

      many: (min=0) ->
        new Parser (offset) =>
          res = []
          pt = offset
          loop
            [val, npt] = @pf pt
            break if val is null
            res.push val
            pt = npt
          if res.length < min then [null, npt] else [res, pt]

The next combinator, `concat`, is like `many` but concatenates the
results of multiple applications of the receiver into a string.

      concat: (min) ->
        @many(min).bind (arr) -> Parser.unit arr.join ''

Sometimes we just want to skip tokens of a certain type without
keeping them, and this is where `skipMany` comes handy. It is very
similar to `many` but instead of collecting the results into an array,
its result is just the number of successful applications of the
receiver (which has to be at least the value of the `min` argument,
otherwise the result is `null`).

      skipMany: (min=0) ->
        new Parser (offset) =>
          cnt = 0
          pt = offset
          loop
            [val, npt] = @pf pt
            break if val is null
            cnt++
            pt = npt
          if cnt < min then [null, npt] else [cnt, pt]

Yet another variation of `many` is `manyTill`. It's argument `end` is
another parser that signals when the repeated application of the
receiver should stop. More precisely: the receiver is applied zero or
more times but the `end` parser is tried before each application. If
it succeeds, then parsing stops and the result is an array containing
results of the receiver collected so far.

      manyTill: (end) ->
        new Parser (offset) =>
          res = []
          pt = offset
          loop
            [val, npt] = end.pf pt
            if val != null then return [res, npt]
            [val, pt] = @pf pt
            if val is null then return [null, pt]
            res.push val

Sometimes we just want to apply a given parser a fixed number of
times.  This is the purpose of the `repeat` combinator. Its argument
`count` specifies the number of repetitions, and its result is an
array containing the results of each application of the receiver.

      repeat: (count=2) ->
        if count <= 0
          Parser.unit []
        else
          @bind (head) => @repeat(count-1).bind (tail) ->
            tail.unshift head
            Parser.unit tail

The next combinator allows for parsing a value that is delimited by
specific tokens from both sides. The implementation is also a nice use
case of the `bind` method: the three parsers, `lft`, `this` (the
receiver represented with `@` in CoffeeScript syntax), and `rt` are
applied in that order, and the result of the middle one becomes the
result.

      between: (lft, rt) ->
        lft.bind =>
          @bind (res) ->
            rt.bind -> Parser.unit res

The `option` combinator applies the receiver first and, if it
succeeds, returns its result. Otherwise, the value specified in the
argument becomes the result.

      option: (dflt='') ->
        @orElse Parser.unit dflt

A common task is to parse a series of values separated by specific
token(s) such as whitespace or comma. This is what the following three
combinators are good for. They all use the receiver for parsing the
values and a second parser in the argument `sep` for parsing the
separators, but differ with respect to the presence of the trailing
separator after the last value:

* `sepBy` is used if the separator is expected only between the values, not after the last one;

* `endBy` requires that each value, including the last one, is followed by the separator;

* `sepEndBy` represents a compromise between the previous two combinators: the last value may or may not be followed by the separator.

The second argument, `min`, prescribes the minimum number od values
that have to be found before the combinator succeeds.

      sepBy: (sep, min=0) ->
        if min == 0
          @sepBy(sep, 1).orElse Parser.unit []
        else
          @bind (head) =>
            (sep.bind => @).many(min-1).bind (tail) ->
              tail.unshift head
              Parser.unit tail

      endBy: (sep, min=0) ->
        (@bind (x) -> sep.bind -> Parser.unit x).many(min)

      sepEndBy: (sep, min=0) ->
        @sepBy(sep, min).bind (res) -> sep.option().bind -> Parser.unit res

Finally, the `notFollowedBy` combinator performs a “lookahead”: it
applies the receiver and then the parser in the argument `p`, and
succeeds only if the receiver succeeds but `p` does not. Also, in the
case of success the offset is rewound to the position where `p`
started so that the text following the chunk consumed by the receiver
can be parsed again.

      notFollowedBy: (p) ->
        @bind (res) ->
          new Parser (offset) ->
            val = if (p.pf offset)[0] is null then res else null
            [val, offset]

Predefined Parsers
------------------

The _Comparse_ library provides a number of predefined parsers as
properties of the **Parser** class (hence the `@` prefix).

The `eof` parser checks whether we are past the end of the input text:
its result is `true` if it is the case, and `null` otherwise.

      @eof =
        new Parser (offset) ->
          res = if offset >= @_text.length then true else null
          [res, offset]

At last, we get a parser that does real work: `anyChar` reads one
character from the input text and provides it as the result.

      @anyChar = new Parser (offset) ->
        next = @_text[offset++]
        if next? then [next, offset] else [null, offset]

The `sat` parser also reads one character but passes it first to the
predicate function that is given in the argument. If the predicate
function returns `true` (or any value that is considered true in the
boolean context), then the result is that character, otherwise the
result is `null` (failure).

      @sat = (pred) ->
        Parser.anyChar.bind (x) ->
          if pred x
            Parser.unit x
          else
            new Parser (offset) -> [null, offset-1]

Now we can define a number of useful parsers just by giving an
appropriate function as the argument to the `sat` parser.

      # A specific character
      @char = (ch) ->
        Parser.sat (x) -> ch == x

      # One of the characters in the argument string
      @oneOf = (alts) ->
        Parser.sat (x) -> alts.indexOf(x) >= 0

      # None of the characters in the argument string
      @noneOf = (alts) ->
        Parser.sat (x) -> alts.indexOf(x) == -1

      # Lowercase letter of the English alphabet
      @lower = Parser.sat (x) -> /^[a-z]$/.test x

      # Uppercase letter of the English alphabet
      @upper = Parser.sat (x) -> /^[A-Z]$/.test x

      # Alphanumeric character
      @alphanum = Parser.sat (x) -> /^\w$/.test x

      # Whitespace character
      @space = Parser.sat (x) -> /^\s$/.test x

… and a few more, using the parsers that we just defined.

      # Decimal digit
      @digit = Parser.oneOf '0123456789'

      # Octal digit
      @octDigit = Parser.oneOf '01234567'

      # Hexadecimal digit
      @hexDigit = Parser.oneOf '01234567abcdefABCDEF'

      # Natural number or zero (without sign)
      @nat0 = Parser.digit.concat(1).bind (ds) ->
        Parser.unit Number(ds)

      # Letter of the English alphabet
      @letter = Parser.lower.orElse Parser.upper

      # Skip whitespace
      @skipSpace = Parser.space.skipMany()

The following parser, `string`, could be defined in terms of multiple
`char` parsers but for efficiency reasons it is implemented using the
built-in string method `substr`.

      @string = (str) ->
        new Parser (offset) ->
          if str == @_text.substr(offset, str.length)
            [str, offset + str.length]
          else
            [null, offset]

The following parser is special in that its result is the current
offset in the input string:

      @offset = new Parser (offset) -> [offset, offset]

Often it is useful to know the current line and/or column. The
auxiliary class method `offset2coords` computes these two coordinates
from the offset. The `tab` argument determines the width of a tab
character that is taken into account for the column number
computation. The default value is 8. Note that the returned
coordinates follow the Emacs convention, namely that the first line
has number one whereas the leftmost column has number zero.

      @offset2coords = (offset, tab=8) ->
        expTab = (from, to) ->
          cnt = 0
          for c in Parser::_text[from...to]
            cnt += if c == '\t' then tab else 1
          cnt
        ln = 1
        beg = 0
        loop
          lf = Parser::_text.indexOf('\n', beg)
          if lf == -1 or lf >= offset then break
          ln += 1
          beg = lf + 1
        [ln, expTab(beg, offset)]

Then, the result of the `coordinates` parser is an array containing
the line and column coordinates.

      @coordinates = new Parser (offset) ->
        [Parser.offset2coords(offset), offset]

Final Touches
-------------

Let's also define a class method for generating an error object that
keeps track of the offset where parsing failed.

      @error = (msg, offset) ->
        res = new Error(msg)
        res.name = 'ParsingError'
        res.offset = offset
        res.coords = @offset2coords(offset)
        res

Finally, we export the **Parser** class so that it can be used in
other modules, both in [Node.js](http://nodejs.org "Node.js") and in a
browser window.

    if module.exports?
      module.exports = Parser
    else
      this.Parser = Parser
