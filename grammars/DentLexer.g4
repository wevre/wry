/*
project : DentLexer.g4
web : https://github.com/wevrem/wry
author : Mike Weaver
created : 2016-05-23
copyright : Copyright (c) 2017 Mike Weaver

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

	DentLexer is a lexer grammar that implements Python-style INDENT and DEDENT
	tokens in ANTLR4. As is typical with such indentation-aware grammars, indeed
	what could be considered their defining characteristics: (a) NEWLINE tokens
	can't be ignored as whitespace, they are necessary to terminate statements;
	and, (b) blocks are defined as statements sandwiched between INDENT and
	DEDENT tokens.

	DentLexer is designed to be included inside a larger, full grammar and needs
	to see whitespace and newlines to operate, emitting INDENT and DEDENT tokens
	that the outer grammar can include in its rules. See the `TestDent`
	grammar for an example.

section : How DentLexer works

	1.
		Upon encountering a NEWLINE token, set a flag and enter `pendingDent`
		state where leading whitespace is counted to determine indentation of
		current line.
	2.
		During `pendingDent` state all whitespace and NEWLINE tokens are set to
		channel HIDDEN; and it is expected, but not required, that comments will
		also be set to channel HIDDEN. In general practice, this is not an issue
		for whitespace or comments, which are normally HIDDEN regardless. But if
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
			interrupted by HIDDEN content, such as a comment (even a multi-line
			comment).
	3.
		The `pendingDent` state is terminated by any non-HIDDEN token, at which
		point the indentation count is used to issue the proper combination of
		INDENT and DEDENT tokens. These are inserted into a queue along with, and
		ahead of, the non-HIDDEN token and that queue is emptied during subsequent
		calls to the lexer's `nextToken()` method.
	4.
		An EOF token will terminate `pendingDent` state just like any other
		non-HIDDEN token. But it also behaves like a NEWLINE and resets the
		indentation count to 0. In fact, if not currently in `pendingDent` state,
		DentLexer will issue an extra NEWLINE, which is needed to close off a
		statement.
		!!!
			Are there situations where that extra NEWLINE would be undesirable?
			Could the grammar be written such that statements are terminated by
			either NEWLINE *or* EOF, and then DentLexer doesn't have to issue an
			extra NEWLINE?

	section : How to use DentLexer

		1.
			Include DentLexer in your grammar, see `TestDent` grammar for an
			example.
		2.
			For tokens that should be ignored during `pendingDent` state (typically
			comments) set their channel to HIDDEN.
*/

lexer grammar DentLexer;

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
		// Initialize `initialIndentToken` if needed.
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
				tokenQueue.offer(createToken(INDENT, "INDENT" + indentCount, next));
			} else {
				indentStack.pop();
				tokenQueue.offer(createToken(DEDENT, "DEDENT"+getSavedIndent(), next));
			}
		}
		pendingDent = false;
		tokenQueue.offer(next);
		return tokenQueue.poll();
	}

}

NEWLINE : ( '\r'? '\n' | '\r' ) {
	if (pendingDent) { setChannel(HIDDEN); }
	pendingDent = true;
	indentCount = 0;
	initialIndentToken = null;
} ;

WS : [ \t]+ {
	setChannel(HIDDEN);
	if (pendingDent) { indentCount += getText().length(); }
} ;

INDENT : 'INDENT' { setChannel(HIDDEN); };
DEDENT : 'DEDENT' { setChannel(HIDDEN); };
