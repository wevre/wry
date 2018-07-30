project : readme-grammars
	author : Mike Weaver
	created : 2016-05-23

section : Introduction

	This directory contains Antlr grammars that I'm working on as part of the
	wry project. A sister directory, named `references`, contains sample
	Antlr grammars for various languages, which I grabbed to study.

section : Dent

	Dent started as a proof-of-concept grammar to experiment with generating
	Python-style `INDENT` and `DEDENT` tokens in Antlr. I started by looking at
	two solutions on the web, but eventually wrote my own as the two solutions I
	found were somewhat lacking for my needs.

	All solutions share a few necessary pieces. At a minimum, you need: (1) a
	queue to hold the generated `INDENT`/`DEDENT` tokens and, depending on the
	design, possibly other tokens, which will be returned on calls to the Lexer's
	`nextToken()` method; and, (2) a stack to keep track of nested levels of
	indentation. In the grammar, statements need to end with a `NEWLINE`, and the
	whitespace following a `NEWLINE` is counted to determine the indentation for
	that line.

	The first solution I explored was the {Python3.g4 grammar}[*python3.g4]
	written by Bart Kiers in 2014. It relies on low-level aspects of the Antlr4
	runtime. For example, to detect blank lines and comments, rather than
	examining tokens, it instead queries the underlying character stream.
	Accessing the runtime at that lower level, where the authors of Antlr are
	more likely to make changes with future updates, seems very fragile to me.

	python3.g4 : https://github.com/bkiers/python3-parser

	The Python3 grammar also uses an override of `emit()` as the place to insert
	tokens into the queue, which seems backwards. That is the location where
	tokens should be pulled *off* the queue. Because the runtime calls `emit()`
	from `nextToken()`, and the custom code also calls `emit()` to inject
	`INDENT`/`DEDENT` tokens, the result is that every token ends up on the
	queue, which is never emptied until the very end. This design feels less
	purposeful than accidental.

	As one would expect, and as designed, Kier's solution works for Python
	scripts only. To adapt it for other indentation-aware scripts would require
	either (a) monkeying around with the logic that queries the underlying
	character stream, which makes my hair stand on end; or (b) retooling to rely
	on tokens, at which point you've basically re-written it.

	The second solution I found was [*antlr-denter] written by Yuval Shavit in
	2014. Shavit's approach uses an external class that hooks into the lexer's
	`nextToken()` method. This solution is decoupled and doesn't interfere much
	with your own grammar, but it does introduce an external dependency. Beyond
	that, I have two concerns: (1) the code seems longer, more complicated than
	it needs to be; and fatally, (2) it has no accommodation for comments. Again
	I'm faced with the prospect of modifications that will inevitably evolve into
	a re-write.

	antlr-denter : https://github.com/yshavit/antlr-denter

	The solution I wrote myself, Dent.g4, is different from both of these. It
	integrates with the runtime solely via an override of the Lexer's
	`nextToken()` method. It does its work by examining tokens: (1) a `NEWLINE`
	token triggers the start of the "keep track of indentation" phase; (2)
	whitespace and comments, both set to channel `HIDDEN`, are respectively
	counted and ignored during that phase; and, (3) a non-`HIDDEN` token ends the
	phase. Thus controlling the logic is a simple matter of setting a token's
	channel. Both of the solutions above require a `NEWLINE` token to also grab
	all the subsequent whitespace, but in doing so can't handle comments
	interrupting that whitespace. Dent, instead, keeps `NEWLINE` and whitespace
	tokens separate and can handle multi-line and mid-line comments.

section : Updates to Dent

	The first version of Dent (which, as of 2018-07-30 is now `OrigDent`) did all
	its work in one file, with lexer member actions (basically, custom code that
	Antlr inserts into the generated lexer java class), the tokens required to
	work with the custom actions, and a toy grammar built on top of those. It
	worked and it could be adapted to other grammars by making a copy and doing
	some quick refactoring. I wanted a solution, however, that could be shared.
	Ideally, something that could be imported directly into other grammars with
	no changes at all.

	The second version was an attempt to create that "drop-in" solution. It sort
	of worked, but when I did a clean test (with no leftover Antlr or *.class
	file from prior tests) I realized it had a few flaws. These flaws are related
	to how Antlr deals with tokens. I defined `INDENT` and `DEDENT` in a `tokens`
	section at the top of Dent. Those aren't referenced in any lexer rules, but
	instead are generated in the override of the lexer's `nextToken` method.

	Because these virtual tokens aren't referenced in any lexer rules, they don't
	get included in the lexer's list of tokens and show up only in the parser's
	token list. For the original Dent that wasn't a problem: Antlr generates the
	DentParser class where the tokens are defined, and Dent's override of
	`nextToken()` references `DentParser.INDENT` and `DentParser.DEDENT`. But
	when you want to import Dent into a larger grammar, how do you specify the
	correct Parser class? You either have to inject it into Dent, or you have to
	create and update a copy of Dent for each grammar where you want to use it.
	Now we are at a point where Dent is not longer a simple "drop-in" solution.

	First I did the injection approach, and this is what I'm calling my second
	version. Grammar `TestDent` imports Dent and at the top has a member action
	to provide the correct token constants.

	```(antlr4) : Injecting parser tokens in the lexer
		@lexer::members {
			private int INDENT_TOKEN = TestDentParser.INDENT;
			private int DEDENT_TOKEN = TestDentParser.DEDENT;
		}

	Then in Dent's override of `nextToken()`, where it queues up the `INDENT` and
	`DEDENT` tokens, it refers to these constants. That definitely worked, and I
	could be satisfied. But it requires this "hook" at the top of the grammar and
	still doesn't feel completely "drop-in".

	Which brings me to the third version. The "problem", as I saw it, was that
	Dent's override of `nextToken` lived down at the lexer level, but the
	`INDENT` and `DEDENT` tokens lived up at the parser level. Version 2's
	solution was to tell the lexer class about the parser class. But another way
	to solve this is to just make sure the tokens are defined on the lexer, which
	requires an explicit rule. So that's what I did.

	```(antlr4) : Explicit rules for dent's tokens
		INDENT : 'INDENT' { setChannel(HIDDEN); };
		DEDENT : 'DEDENT' { setChannel(HIDDEN); };

	There are some aspects of this I don't like. I'm creating "dummy" tokens and
	rules that will never (should never!) be reached, just to include them in the
	lexer's token list. In practice, any non-toy grammar would never fall through
	and hit these, so I set their channel to hidden. The redeeming feature of
	this approach is that it is truly "drop-in". A larger grammar can import
	`DentLexer` and start using INDENT and DEDENT tokens in the parser rules
	without any additional configuration.
