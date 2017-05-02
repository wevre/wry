grammars
===========

This folder contains some ANTLR grammars, some I'm working on and others that I grabbed from around the web to study as examples.

Dent
-----------

This is a proof-of-concept grammar that I put together to experiment with generating Python-style `INDENT` and `DEDENT` tokens in ANTLR. I started by looking at two solutions on the web, but eventually wrote my own as the two solutions I found were somewhat lacking for my needs.

All solutions share a few necessary pieces. At a minimum, you need: (1) a queue to hold the generated `INDENT`/`DEDENT` tokens and, depending on the design, possibly other tokens, which will be returned on calls to the Lexer's `nextToken()` method; and, (2) a stack to keep track of nested levels of indentation. In the grammar, statements need to end with a `NEWLINE`, and the whitespace following a `NEWLINE` is counted to determine the indentation for that line.

The first solution I explored was the [Python3.g4](https://github.com/bkiers/python3-parser) grammar written by Bart Kiers in 2014. It relies on low-level aspects of the ANTLR4 runtime. For example, to detect blank lines and comments, rather than examining tokens, it instead queries the underlying character stream. Accessing the runtime at that lower level, where the authors of ANTLR are more likely to make changes with future updates, seems very fragile to me.

The Python3 grammar also uses an override of `emit()` as the place to insert tokens into the queue, which seems backwards. That is the location where tokens should be pulled *off* the queue. Because the runtime calls `emit()` from  `nextToken()`, and the custom code also calls `emit()` to inject `INDENT`/`DEDENT` tokens, the result is that every token ends up on the queue, which is never emptied until the very end. This design feels less purposeful than accidental.

As one would expect, and as designed, Kier's solution works for Python scripts only. To adapt it for other indentation-aware scripts would require either (a) monkeying around with the logic that queries the underlying character stream, which makes my hair stand on end; or (b) retooling to rely on tokens, at which point you've basically re-written it.

The second solution I found was [antlr-denter](https://github.com/yshavit/antlr-denter) written by Yuval Shavit in 2014. Shavit's approach uses an external class that hooks into the lexer's `nextToken()` method. This solution is decoupled and doesn't interfere much with your own grammar, but it does introduce an external dependency. Beyond that, I have two concerns: (1) the code seems longer, more complicated than it needs to be; and fatally, (2) it has no accommodation for comments. Again I'm faced with the prospect of modifications that will inevitably evolve into a re-write.

The solution I wrote myself, Dent.g4, is different from both of these. It integrates with the runtime solely via an override of the Lexer's `nextToken()` method. It does its work by examining tokens: (1) a `NEWLINE` token triggers the start of the "keep track of indentation" phase; (2) whitespace and comments, both set to channel `HIDDEN`, are respectively counted and ignored during that phase; and, (3) a non-`HIDDEN` token ends the phase. Thus controlling the logic is a simple matter of setting a token's channel. Both of the solutions above require a `NEWLINE` token to also grab all the subsequent whitespace, but in doing so can't handle comments interrupting that whitespace. Dent, instead, keeps `NEWLINE` and whitespace tokens separate and can handle multi-line and mid-line comments.
