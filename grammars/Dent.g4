grammar Dent;

tokens { INDENT, DEDENT }

@lexer::members {

	private boolean pendingDent = false;

	private int indentCount = 0;

	private java.util.LinkedList<Token> tokenQueue = new java.util.LinkedList<>();

	private java.util.Stack<Integer> indentStack = new java.util.Stack<>();

	// Returns true if the token is one that should end `pendingDent` mode.
	// For this simple grammar, `pendingDent` ends with LEGIT or EOF. For more complicated grammars it will be different.
	private boolean shouldEndPendingDent(Token t) { return t.getType() == LEGIT || t.getType() == EOF; }

	private int getCurrentIndent() { return indentStack.isEmpty() ? 0 : indentStack.peek(); }

	@Override
	public Token nextToken() {

		// Return tokens from the queue if it is not empty.
		if (!tokenQueue.isEmpty()) { return tokenQueue.poll(); }

		// Grab the next token and if nothing special is needed, simply return it.
		Token next = super.nextToken();
		//NOTE: Here we could count whitespace or deal with NEWLINES, but it is already handled in actions down in the lexer rules.
		if (null == next || !shouldEndPendingDent(next)) { return next; }

		// Handle EOF; in particular, handle an abrupt EOF that comes without an immediately preceding NL.
		if (next.getType() == EOF) {
			indentCount = 0;
			// EOF outside of `pendingDent` mode means we did not have a final NEWLINE before the end of file.
			if (!pendingDent) { tokenQueue.offer(new CommonToken(NEWLINE, "NEWLINE")); }
		}

		// Before exiting `pendingDent` mode we need to queue up proper INDENTS and DEDENTS.
		while (indentCount != getCurrentIndent()) {
			if (indentCount > getCurrentIndent()) {
				indentStack.push(indentCount);
				CommonToken token = new CommonToken(DentParser.INDENT, "INDENT" + indentCount); //TODO: set start/end character index
				tokenQueue.offer(token);
			} else {
				indentStack.pop();
				CommonToken token = new CommonToken(DentParser.DEDENT, "DEDENT"+getCurrentIndent()); //TODO: set start/end character index
				tokenQueue.offer(token);
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

LEGIT : ~[ \t\r\n]+ ;

NEWLINE : ( '\r'? '\n' | '\r' ) { if (pendingDent) { setChannel(HIDDEN); } pendingDent = true; indentCount = 0; } ;

WS : [ \t]+ { setChannel(HIDDEN); if (pendingDent) { indentCount += getText().length(); } } ;

BlockComment : '/*' ( BlockComment | . )*? '*/' -> channel(HIDDEN) ;   // allow nesting comments
LineComment : '//' ~[\r\n]* -> channel(HIDDEN) ;
