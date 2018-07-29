/*
project : Dent.g4
	web : https://github.com/wevrem/wry
	author : Mike Weaver
	created : 2016-05-23
	copyright : Copyright (c) 2017 Mike Weaver

!!!
	This is the original Dent grammar, a proof-of-concept lexer/parser combo
	grammar that incorporated the INDENT/DEDENT handling at the lexer level along
	with simple parser rules to demonstrate its use. Basically a toy grammar.
	This was replaced with a more suitable design where the core Dent logic lives
	in its own lexer grammar and can be include'd in a larger full grammar.

	I keep this grammar around, at the moment, for testing only.

section : The MIT License

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in
	all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

section : Introduction

	Dent is a simple grammar that illustrates implementing Python-style INDENT
	and DEDENT tokens in ANTLR4. As is typical with such indentation-aware
	grammars, indeed what could be considered their defining characteristics: (a)
	NEWLINE tokens can't be ignored as whitespace, they are necessary to
	terminate statements; and, (b) blocks are defined as statements sandwiched
	between INDENT and DEDENT tokens.

	Since Dent is only interested in correctly handling indentation, all the
	lexer and parser rules that would normally define the statements and
	expressions of a grammar are collapsed into a single LEGIT token, which grabs
	everything that is not whitespace, comment, or NEWLINE.

	Dent will parse Python scripts and generate INDENT and DEDENT tokens to match
	the indentation present in the file. It will catch the error of an unmatched
	INDENT/DEDENT pair (which is a lexical error), but of course it can't
	determine correct Python syntax (which is the role of the parser). Dent also
	allows multi-line comments, something Python does not.

section : How Dent works

	1.
		Upon encountering a NEWLINE token, set a flag and enter `pendingDent`
		state where leading whitespace is counted to determine indentation of
		current line.
	2.
		During `pendingDent` state all whitespace, comments and NEWLINE tokens are
		set to channel HIDDEN. In general practice, this is not an issue for
		whitespace and comments, which are normally HIDDEN regardless. But if
		needed, they could adopt the logic for NEWLINEs and switch to channel
		HIDDEN only in `pendingDent` state. Importantly, a NEWLINE token in
		`pendingDent` state resets the indentation count to 0. The upshot of all
		this is:

		a
			the grammar ignores blank lines, even if they contain leading
			whitespace that is inconsistent with the indentation of surrounding
			non-blank lines; and,
		b
			for determining the indentation, whitespace is counted even if it is
			interrupted by a comment (even a multi-line comment).
	3.
		The `pendingDent` state is terminated by a non-HIDDEN token, at which
		point the indentation count is used to issue the proper combination of
		INDENT and DEDENT tokens. These are placed in a queue along with the
		non-HIDDEN token and the queue is emptied during subsequent calls to the
		lexer's `nextToken()` method.
	4.
		An EOF token will terminate `pendingDent` state just like any other
		non-HIDDEN token. It will also reset the indentation count to 0 and, if
		not currently in `pendingDent` state, prior to any DEDENTs it will trigger
		an extra NEWLINE, which is needed to close off a statement.

section : Using Dent with non-toy grammars
	1.
		Replace the LEGIT token with the lexer and parser rules specific to your
		grammar.
	2.
		Change the references to DentParser.INDENT and DentParser.DEDENT to the
		name of your own parser class.
	3.
		If you have tokens that should be ignored during `pendingDent` state,
		similar to or perhaps variants of whitespace, comments and NEWLINE, then
		be sure to set them to channel HIDDEN, either permanently or, at a
		minimum, during `pendingDent` state.
*/

grammar OrigDent;

tokens { INDENT, DEDENT }

@lexer::members {

	// Initializing `pendingDent` to true means any whitespace at the beginning
	// of the file will trigger an INDENT, which will probably be a syntax error,
	// as it is in Python.
	private boolean pendingDent = true;

	private int indentCount = 0;

	private java.util.LinkedList<Token> tokenQueue = new java.util.LinkedList<>();

	private java.util.Stack<Integer> indentStack = new java.util.Stack<>();

	private Token initialIndentToken = null;

	private int getSavedIndent() { return indentStack.isEmpty() ? 0 : indentStack.peek(); }

	private CommonToken createToken(int type, String text, Token next) {
		CommonToken token = new CommonToken(type, text);
		if (null != initialIndentToken) {
			token.setStartIndex(initialIndentToken.getStartIndex());
			token.setLine(initialIndentToken.getLine());
			token.setCharPositionInLine(initialIndentToken.getCharPositionInLine());
			token.setStopIndex(next.getStartIndex()-1);
		}
		return token;
	}

	@Override
	public Token nextToken() {

		// Return tokens from the queue if it is not empty.
		if (!tokenQueue.isEmpty()) { return tokenQueue.poll(); }

		// Grab the next token and if nothing special is needed, simply return it.
		Token next = super.nextToken();
		//NOTE: This could be an appropriate spot to count whitespace or deal with
		//NEWLINES, but it is already handled with custom actions down in the
		//lexer rules.
		if (pendingDent && null == initialIndentToken && NEWLINE != next.getType()) { initialIndentToken = next; }
		if (null == next || HIDDEN == next.getChannel() || NEWLINE == next.getType()) { return next; }

		// Handle EOF. In particular, handle an abrupt EOF that comes without an
		// immediately preceding NEWLINE.
		if (next.getType() == EOF) {
			indentCount = 0;
			// EOF outside of `pendingDent` state means input did not have a final
			// NEWLINE before end of file.
			if (!pendingDent) {
				initialIndentToken = next;
				tokenQueue.offer(createToken(NEWLINE, "NEWLINE", next));
			}
		}

		// Before exiting `pendingDent` state queue up proper INDENTS and DEDENTS.
		while (indentCount != getSavedIndent()) {
			if (indentCount > getSavedIndent()) {
				indentStack.push(indentCount);
				tokenQueue.offer(createToken(OrigDentParser.INDENT, "INDENT" + indentCount, next));
			} else {
				indentStack.pop();
				tokenQueue.offer(createToken(OrigDentParser.DEDENT, "DEDENT"+getSavedIndent(), next));
			}
		}
		pendingDent = false;
		tokenQueue.offer(next);
		return tokenQueue.poll();
	}

}

script : ( NEWLINE | statement )* EOF ;

statement
	:	simpleStatement
	|	blockStatements
	;

simpleStatement : LEGIT+ NEWLINE ;

blockStatements : LEGIT+ NEWLINE INDENT statement+ DEDENT ;

NEWLINE : ( '\r'? '\n' | '\r' ) { if (pendingDent) { setChannel(HIDDEN); } pendingDent = true; indentCount = 0; initialIndentToken = null; } ;

WS : [ \t]+ { setChannel(HIDDEN); if (pendingDent) { indentCount += getText().length(); } } ;

BlockComment : '/*' ( BlockComment | . )*? '*/' -> channel(HIDDEN) ;   // allow nesting comments
LineComment : '//' ~[\r\n]* -> channel(HIDDEN) ;

LEGIT : ~[ \t\r\n]+ ~[\r\n]* ;   // Replace with language-specific rules...
